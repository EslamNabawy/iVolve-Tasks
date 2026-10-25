#!/usr/bin/env bash
# Lab 7 — Deploying the Lab 3 image to Kubernetes with kind
# Every command, in order. Run from anywhere.
# This lab only ever names its own cluster (`ivolve`) and pins the kubectl
# context: the unrelated `aiops` cluster and its containers are never
# touched.
set -euo pipefail

CLUSTER=ivolve
CTX=kind-ivolve
APP="$HOME/labs-workspace/CalculatorMavenApp"
LAB="$HOME/iVolve-Tasks/Kubernetes/Lab7"
LAB3="$HOME/iVolve-Tasks/Docker/Lab3"

# 0. Tooling (already installed here: kind v0.33.0, kubectl v1.37.1)
kind version
kubectl version --client | head -1

# 1. Rebuild Lab 3's multi-stage image. The upstream clone lives OUTSIDE
#    this repo (rule: only authored files are committed), so the build
#    context is the clone and the Dockerfile comes from this lab's sibling:
#    building from the repo folder fails with "pom.xml: not found".
mkdir -p "$HOME/labs-workspace"
[ -d "$APP" ] || git clone https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git "$APP"
docker build -f "$LAB3/Dockerfile.multistage" -t app3 "$APP"
docker images app3 --format '{{.Repository}}:{{.Tag}} {{.Size}}'

# 2. One control-plane node (~16 s with the node image already local)
kind create cluster --name "$CLUSTER" --wait 120s
kubectl --context "$CTX" get nodes -o wide

# 3. Load the image: kind nodes run containerd, not the host's dockerd
kind load docker-image app3 --name "$CLUSTER"

# 4. First contact — one interactive pod, the `docker run -i` equivalent
printf '10\n5\n' | kubectl --context "$CTX" run calc-quick --rm -i --restart=Never \
  --image=app3 --image-pull-policy=Never

# 5. The honest negative test: the image's default ENTRYPOINT, no stdin
kubectl --context "$CTX" run calc-asis --image=app3 --image-pull-policy=Never
sleep 10
kubectl --context "$CTX" get pod calc-asis
kubectl --context "$CTX" logs calc-asis --all-containers | head -10
kubectl --context "$CTX" describe pod calc-asis | tail -12

# 6. The pattern that works: pod kept alive, calculator on demand
kubectl --context "$CTX" apply -f "$LAB/deployment.yaml"
kubectl --context "$CTX" rollout status deploy/calculator --timeout=60s

# 7. The calculator, inside the cluster
printf '7\n3\n' | kubectl --context "$CTX" exec -i deploy/calculator -- java -jar /app/calculator.jar

# 8. Non-root and the declared resources
kubectl --context "$CTX" exec deploy/calculator -- id
kubectl --context "$CTX" describe pod -l app=calculator | grep -E 'Image:|runAs|cpu|memory|Limits|Requests'
kubectl --context "$CTX" get pod -l app=calculator -o yaml | grep -E 'runAsUser|runAsGroup|runAsNonRoot'

# 9. Service: endpoints exist, nothing answers on 8080
kubectl --context "$CTX" apply -f "$LAB/service.yaml"
kubectl --context "$CTX" get svc,endpoints calculator
kubectl --context "$CTX" exec deploy/calculator -- wget -T3 -O- http://calculator:8080/ || true

# 10. Full picture — the crashed pod next to the working one, then tidy up
kubectl --context "$CTX" get deploy,po,svc
kubectl --context "$CTX" top pod || true                       # kind ships no metrics-server
kubectl --context "$CTX" logs deploy/calculator | wc -c        # PID 1 is `sleep`, so: 0
kubectl --context "$CTX" delete pod calc-asis --wait=false

# 11. Cleanup — only this cluster, then this lab's image
kind delete cluster --name "$CLUSTER"
docker rmi app3
kind get clusters                                    # `aiops` must still be listed
docker ps -a --format '{{.Names}} {{.Status}}' | grep -E 'control-plane|ivolve' || true
