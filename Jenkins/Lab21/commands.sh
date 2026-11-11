#!/usr/bin/env bash
# Lab 21 — Jenkins Pipeline for Application Deployment
#
# Prerequisites (created by earlier labs, re-created here if missing):
#   * kind cluster `ivolve`    (Lab 9)
#   * local registry on :5000  (Lab 8, image `registry:2`)
# The registry lives on the HOST; kind nodes reach it at the docker bridge
# gateway 172.18.0.1, which containerd must be told is plain HTTP.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Jenkins/Lab21"
JHOME="$HOME/jenkins-home-lab21"
URL="http://127.0.0.1:8082"
USER=ivolve-admin
PASS=ivolve-admin
REGISTRY=172.18.0.1:5000
DG=$(stat -c %g /var/run/docker.sock)

# 0. Registry, plus containerd trust for it on every kind node.
docker ps --format '{{.Names}}' | grep -qx lab8-registry \
  || docker run -d --name lab8-registry -p 5000:5000 registry:2
for n in ivolve-control-plane ivolve-worker ivolve-worker2; do
  docker exec "$n" bash -c "
    grep -q '$REGISTRY' /etc/containerd/config.toml ||
      printf '\n[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"$REGISTRY\"]\n  endpoint = [\"http://$REGISTRY\"]\n' >> /etc/containerd/config.toml
    systemctl restart containerd"
done

# 1. Namespace for this lab (the ivolve namespace is capped at 3 pods by Lab 11)
kubectl --context kind-ivolve apply -f "$LAB/namespace.yaml"

# 2. CI image: Jenkins + maven + JDK 17 + docker CLI + trivy + kubectl
docker build --network=host -t ivolve-jenkins:lab21 "$LAB"

# 3. Controller. --network host so 127.0.0.1:<kind API> and the registry work;
#    the docker CLI still drives the HOST daemon through the socket.
rm -rf "$JHOME" && mkdir -p "$JHOME"
# Warm the scanner's cache from the host so the first pipeline run does not
# spend ten minutes re-downloading the 1.7 GB Trivy DB through WSL networking.
if [ -d "$HOME/.cache/trivy" ]; then
  mkdir -p "$JHOME/.cache"
  cp -a "$HOME/.cache/trivy" "$JHOME/.cache/trivy"
fi
docker rm -f jenkins-lab21 >/dev/null 2>&1 || true
docker run -d --name jenkins-lab21 \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$DG" \
  -v "$HOME/.kube/config:/kube/config:ro" \
  -v "$HOME/labs-workspace/DemoApp:$HOME/labs-workspace/DemoApp:ro" \
  -v "$HOME/iVolve-Tasks:$HOME/iVolve-Tasks:ro" \
  -v "$LAB/jenkins.yaml:/var/jenkins_home/casc/jenkins.yaml:ro" \
  -v "$JHOME:$JHOME" \
  -e JENKINS_HOME="$JHOME" \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc \
  -e JENKINS_ADMIN_ID="$USER" \
  -e JENKINS_ADMIN_PASSWORD="$PASS" \
  -e JENKINS_OPTS="--httpPort=8082" \
  -e TRIVY_CACHE_DIR="$JHOME/.cache/trivy" \
  -e JAVA_OPTS="-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" \
  ivolve-jenkins:lab21

# 4. Wait for Jenkins (first boot installs plugins: up to ~3 minutes)
for i in $(seq 1 120); do
  curl -sf -u "$USER:$PASS" "$URL/api/json" >/dev/null 2>&1 && break
  sleep 2
done
curl -s -u "$USER:$PASS" "$URL/api/json?tree=mode,numExecutors"

# 5. Trigger the job
JAR=/tmp/jenkins21-crumb.jar; rm -f "$JAR"
CRUMB=$(curl -s -c "$JAR" -u "$USER:$PASS" "$URL/crumbIssuer/api/json" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])')
CODE=$(curl -s -o /dev/null -w "%{http_code}" -b "$JAR" -c "$JAR" -u "$USER:$PASS" \
  -H "$CRUMB" -X POST "$URL/job/lab21-pipeline/build")
echo "trigger HTTP $CODE (want 201)"

# 6. Wait for the verdict
R=RUNNING
for i in $(seq 1 300); do
  R=$(curl -s -u "$USER:$PASS" "$URL/job/lab21-pipeline/lastBuild/api/json?tree=result" \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('result') or 'RUNNING')" 2>/dev/null || echo RUNNING)
  [ "$R" != "RUNNING" ] && break
  sleep 6
done
echo "pipeline result: $R"
curl -s -u "$USER:$PASS" "$URL/job/lab21-pipeline/lastBuild/api/json?tree=result,duration,number" | python3 -m json.tool
curl -s -u "$USER:$PASS" "$URL/job/lab21-pipeline/lastBuild/consoleText" | tail -45

[ "$R" = "SUCCESS" ] || { echo "PIPELINE FAILED"; exit 1; }

# 7. The manifest the pipeline edited now names the build's image
grep 'image:' "$JHOME/workspace/lab21-pipeline/repo/Jenkins/Lab21/deployment.yaml"

# 8. Cluster state and a real request to the app
kubectl -n lab21 get deploy,pods,svc -o wide
kubectl -n lab21 port-forward svc/demoapp 8088:80 >/tmp/lab21-pf.log 2>&1 &
PF=$!; sleep 4
curl -s -o /dev/null -w 'GET http://127.0.0.1:8088/ -> HTTP %{http_code}\n' http://127.0.0.1:8088/
kill $PF || true

# 9. Cleanup — the Jenkins controller only; the deployment stays as evidence
docker rm -f jenkins-lab21 >/dev/null
docker rmi ivolve-jenkins:lab21
rm -rf "$JHOME"
