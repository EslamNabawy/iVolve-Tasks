#!/usr/bin/env bash
# Lab 22 — Jenkins shared libraries + a dedicated build agent.
#
# Prerequisites, re-created here if missing:
#   * kind cluster `ivolve`    (Lab 9)
#   * local registry on :5000  (Lab 8)
# The controller image is Lab 21's, unchanged. What is new is the agent: the
# controller runs with numExecutors: 0, so nothing can run unless the agent
# connects.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Jenkins/Lab22"
JHOME="$HOME/jenkins-home-lab22"
URL="http://127.0.0.1:8082"
USER=ivolve-admin
PASS=ivolve-admin
REGISTRY=172.18.0.1:5000
DG=$(stat -c %g /var/run/docker.sock)

# 0. Registry + containerd trust (idempotent, same as Lab 21).
docker ps --format '{{.Names}}' | grep -qx lab8-registry \
  || docker run -d --name lab8-registry -p 5000:5000 registry:2
for n in ivolve-control-plane ivolve-worker ivolve-worker2; do
  docker exec "$n" bash -c "
    grep -q '$REGISTRY' /etc/containerd/config.toml ||
      printf '\n[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"$REGISTRY\"]\n  endpoint = [\"http://$REGISTRY\"]\n' >> /etc/containerd/config.toml
    systemctl restart containerd"
done

# 1. Namespace for this lab.
kubectl --context kind-ivolve apply -f "$LAB/namespace.yaml"

# 2. Images: the controller is Lab 21's; the agent is new.
docker build --network=host -t ivolve-jenkins:lab22 "$HOME/iVolve-Tasks/Jenkins/Lab21"
docker build --network=host -t ivolve-agent:lab22 -f "$LAB/Dockerfile.agent" "$LAB"

# 3. Controller — zero executors.
rm -rf "$JHOME" && mkdir -p "$JHOME"
if [ -d "$HOME/.cache/trivy" ]; then
  mkdir -p "$JHOME/.cache"
  cp -a "$HOME/.cache/trivy" "$JHOME/.cache/trivy"
fi
docker rm -f jenkins-lab22 jenkins-agent22 >/dev/null 2>&1 || true
docker run -d --name jenkins-lab22 \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$DG" \
  -v "$HOME/.kube/config:/kube/config:ro" \
  -v "$HOME/iVolve-Tasks:$HOME/iVolve-Tasks:ro" \
  -v "$LAB/jenkins.yaml:/var/jenkins_home/casc/jenkins.yaml:ro" \
  -v "$JHOME:$JHOME" \
  -e JENKINS_HOME="$JHOME" \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc \
  -e JENKINS_ADMIN_ID="$USER" \
  -e JENKINS_ADMIN_PASSWORD="$PASS" \
  -e JENKINS_OPTS="--httpPort=8082" \
  -e JAVA_OPTS="-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" \
  ivolve-jenkins:lab22

for i in $(seq 1 120); do
  curl -sf -u "$USER:$PASS" "$URL/api/json" >/dev/null 2>&1 && break
  sleep 2
done
curl -s -u "$USER:$PASS" "$URL/api/json?tree=mode,numExecutors"

# 4. The agent's secret, read from the running Jenkins (JCasC creates the node,
#    Jenkins owns the secret). scriptText needs the same CSRF crumb as a POST.
JAR=/tmp/jenkins22-crumb.jar; rm -f "$JAR"
CRUMB=$(curl -s -c "$JAR" -u "$USER:$PASS" "$URL/crumbIssuer/api/json" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])')
SECRET=$(curl -s -b "$JAR" -u "$USER:$PASS" -H "$CRUMB" -X POST \
  --data-urlencode 'script=println(Jenkins.instance.getComputer("docker-agent").jnlpMac)' \
  "$URL/scriptText" | tr -d '\r\n')
echo "agent secret: ${SECRET:0:8}… (${#SECRET} chars)"

# 5. The agent. Same host, same docker socket, same cluster — only the process
#    is different, which is what a "slave" is.
docker run -d --name jenkins-agent22 \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$DG" \
  -v "$HOME/.kube/config:/kube/config:ro" \
  -v "$HOME/labs-workspace/DemoApp:$HOME/labs-workspace/DemoApp:ro" \
  -v "$HOME/iVolve-Tasks:$HOME/iVolve-Tasks:ro" \
  -v "$HOME/.cache/trivy:/trivy-cache" \
  -e TRIVY_CACHE_DIR=/trivy-cache \
  ivolve-agent:lab22 \
  -url "$URL" -name docker-agent -secret "$SECRET" -webSocket -workDir /home/jenkins/agent

for i in $(seq 1 60); do
  OFF=$(curl -s -u "$USER:$PASS" "$URL/computer/docker-agent/api/json?tree=offline" \
        | python3 -c 'import sys,json;print(json.load(sys.stdin)["offline"])' 2>/dev/null || echo True)
  [ "$OFF" = "False" ] && break
  sleep 2
done
curl -s -u "$USER:$PASS" "$URL/computer/api/json?tree=computer[displayName,offline,numExecutors]"
echo
docker logs --tail 5 jenkins-agent22 2>&1

# 6. Trigger
JAR=/tmp/jenkins22-job.jar; rm -f "$JAR"
CRUMB=$(curl -s -c "$JAR" -u "$USER:$PASS" "$URL/crumbIssuer/api/json" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])')
CODE=$(curl -s -o /dev/null -w "%{http_code}" -b "$JAR" -c "$JAR" -u "$USER:$PASS" \
  -H "$CRUMB" -X POST "$URL/job/lab22-pipeline/build")
echo "trigger HTTP $CODE (want 201)"

# 7. Wait for the verdict
R=RUNNING
for i in $(seq 1 300); do
  R=$(curl -s -u "$USER:$PASS" "$URL/job/lab22-pipeline/lastBuild/api/json?tree=result" \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('result') or 'RUNNING')" 2>/dev/null || echo RUNNING)
  [ "$R" != "RUNNING" ] && break
  sleep 6
done
echo "pipeline result: $R"
curl -s -u "$USER:$PASS" "$URL/job/lab22-pipeline/lastBuild/api/json?tree=result,number,builtOn" | python3 -m json.tool
curl -s -u "$USER:$PASS" "$URL/job/lab22-pipeline/lastBuild/consoleText" > /tmp/lab22-console.txt
tail -45 /tmp/lab22-console.txt

[ "$R" = "SUCCESS" ] || { echo "PIPELINE FAILED"; exit 1; }

# 8. Which node ran it, and what ended up in the cluster
grep -E 'agent=|Running on docker-agent|\[buildApp\]|\[buildImage\]|\[deployOnK8s\]' /tmp/lab22-console.txt | head -12
kubectl -n lab22 get deploy,pods,svc -o wide
kubectl -n lab22 port-forward svc/demoapp 8089:80 >/tmp/lab22-pf.log 2>&1 &
PF=$!; sleep 4
curl -s -o /dev/null -w 'GET http://127.0.0.1:8089/ -> HTTP %{http_code}\n' http://127.0.0.1:8089/
kill $PF || true

# 9. Cleanup — controller and agent only; the deployment stays as evidence
docker rm -f jenkins-agent22 jenkins-lab22 >/dev/null
docker rmi ivolve-agent:lab22 ivolve-jenkins:lab22 >/dev/null
rm -rf "$JHOME"
