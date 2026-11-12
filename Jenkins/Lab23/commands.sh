#!/usr/bin/env bash
# Lab 23 — GitOps: Argo CD watches the repository, Jenkins only writes to it.
#
# Order matters: Argo CD is installed and given an Application FIRST, so the
# first sync is observable; then the pipeline pushes a new tag and Argo CD
# reacts on its own.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Jenkins/Lab23"
JHOME="$HOME/jenkins-home-lab23"
URL="http://127.0.0.1:8082"
USER=ivolve-admin
PASS=ivolve-admin
REGISTRY=172.18.0.1:5000
DG=$(stat -c %g /var/run/docker.sock)
GH_TOKEN=$(gh auth token)

# 0. Registry + containerd trust (idempotent, same as Labs 21-22).
docker ps --format '{{.Names}}' | grep -qx lab8-registry \
  || docker run -d --name lab8-registry -p 5000:5000 registry:2
for n in ivolve-control-plane ivolve-worker ivolve-worker2; do
  docker exec "$n" bash -c "
    grep -q '$REGISTRY' /etc/containerd/config.toml ||
      printf '\n[plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"$REGISTRY\"]\n  endpoint = [\"http://$REGISTRY\"]\n' >> /etc/containerd/config.toml
    systemctl restart containerd"
done

# 1. The gitops branch Argo CD will watch
cd "$HOME/iVolve-Tasks"
git fetch origin --quiet
if ! git rev-parse --verify --quiet gitops >/dev/null; then
  git branch gitops origin/main 2>/dev/null || git branch gitops
  git push -u origin gitops
fi
git log --oneline -1 gitops

# 2. Argo CD in the cluster
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# The applicationsets CRD is bigger than a client-side apply annotation allows
# (262144 bytes), so the manifests go in server-side.
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=600s
kubectl -n argocd get pods
kubectl -n argocd get deploy -o custom-columns='NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image' | grep argocd-server

# 3. UI access + login
ARGOPASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
kubectl -n argocd port-forward svc/argocd-server 8443:443 >/tmp/lab23-argocd-pf.log 2>&1 &
PF=$!; sleep 6
curl -sk -o /dev/null -w 'GET https://127.0.0.1:8443/ -> HTTP %{http_code}\n' https://127.0.0.1:8443/
TOKEN=$(curl -sk https://127.0.0.1:8443/api/v1/session \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"$ARGOPASS\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
echo "login token: ${TOKEN:0:12}... (${#TOKEN} chars)"
curl -sk -H "Authorization: Bearer $TOKEN" https://127.0.0.1:8443/api/v1/applications | head -c 200; echo

# 4. The Application (Argo CD is given the repo + path + branch)
kubectl apply -f "$LAB/application.yaml"
sleep 10
kubectl -n argocd get applications
kubectl -n argocd get application ivolve -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}' || true

# 5. Jenkins: the Lab 21 controller image (git + credentials-binding included)
docker build --network=host -t ivolve-jenkins:lab23 "$HOME/iVolve-Tasks/Jenkins/Lab21"
rm -rf "$JHOME" && mkdir -p "$JHOME"
if [ -d "$HOME/.cache/trivy" ]; then mkdir -p "$JHOME/.cache"; cp -a "$HOME/.cache/trivy" "$JHOME/.cache/trivy"; fi
docker rm -f jenkins-lab23 >/dev/null 2>&1 || true
docker run -d --name jenkins-lab23 \
  --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add "$DG" \
  -v "$HOME/iVolve-Tasks:$HOME/iVolve-Tasks:ro" \
  -v "$LAB/jenkins.yaml:/var/jenkins_home/casc/jenkins.yaml:ro" \
  -v "$JHOME:$JHOME" \
  -e JENKINS_HOME="$JHOME" \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc \
  -e JENKINS_ADMIN_ID="$USER" \
  -e JENKINS_ADMIN_PASSWORD="$PASS" \
  -e GITHUB_TOKEN="$GH_TOKEN" \
  -e JENKINS_OPTS="--httpPort=8082" \
  -e JAVA_OPTS="-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" \
  ivolve-jenkins:lab23

for i in $(seq 1 120); do curl -sf -u "$USER:$PASS" "$URL/api/json" >/dev/null 2>&1 && break; sleep 2; done
curl -s -u "$USER:$PASS" "$URL/api/json?tree=mode,numExecutors"

# 6. Trigger
JAR=/tmp/jenkins23-crumb.jar; rm -f "$JAR"
CRUMB=$(curl -s -c "$JAR" -u "$USER:$PASS" "$URL/crumbIssuer/api/json" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])')
CODE=$(curl -s -o /dev/null -w "%{http_code}" -b "$JAR" -c "$JAR" -u "$USER:$PASS" \
  -H "$CRUMB" -X POST "$URL/job/lab23-pipeline/build")
echo "trigger HTTP $CODE (want 201)"

R=RUNNING
for i in $(seq 1 300); do
  R=$(curl -s -u "$USER:$PASS" "$URL/job/lab23-pipeline/lastBuild/api/json?tree=result" \
      | python3 -c "import sys,json;print(json.load(sys.stdin).get('result') or 'RUNNING')" 2>/dev/null || echo RUNNING)
  [ "$R" != "RUNNING" ] && break
  sleep 6
done
echo "pipeline result: $R"
curl -s -u "$USER:$PASS" "$URL/job/lab23-pipeline/lastBuild/consoleText" > /tmp/lab23-console.txt
tail -40 /tmp/lab23-console.txt
[ "$R" = "SUCCESS" ] || { echo "PIPELINE FAILED"; exit 1; }

# 7. The push is visible in GitHub, not in the cluster
cd "$HOME/iVolve-Tasks"
git fetch origin --quiet
git log --oneline -3 origin/gitops
git diff --stat origin/main origin/gitops | tail -3

# 8. Argo CD noticed on its own
for i in $(seq 1 60); do
  read -r S H < <(kubectl -n argocd get application ivolve -o jsonpath='{.status.sync.status} {.status.health.status}')
  echo "sync=$S health=$H"
  [ "$S" = "Synced" ] && [ "$H" = "Healthy" ] && break
  kubectl -n argocd annotate application ivolve argocd.argoproj.io/refresh=normal --overwrite >/dev/null
  sleep 6
done
kubectl -n argocd get application ivolve
kubectl -n argocd get application ivolve -o jsonpath='{.status.operationState.phase} {.status.operationState.message}{"\n"}'

# 9. What Argo CD applied
kubectl -n lab23 get deploy,pods,svc -o wide
kubectl -n lab23 get deploy demoapp -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n lab23 port-forward svc/demoapp 8090:80 >/tmp/lab23-pf.log 2>&1 &
PF2=$!; sleep 4
curl -s -o /dev/null -w 'GET http://127.0.0.1:8090/ -> HTTP %{http_code}\n' http://127.0.0.1:8090/
kill $PF2 || true
kill $PF || true

# 10. Cleanup — Jenkins only. Argo CD and the Application stay: they are the result.
docker rm -f jenkins-lab23 >/dev/null
docker rmi ivolve-jenkins:lab23 >/dev/null
rm -rf "$JHOME"
