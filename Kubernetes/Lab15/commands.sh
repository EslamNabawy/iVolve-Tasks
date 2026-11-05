#!/usr/bin/env bash
# Lab 15 — Node app + init container + ClusterIP Service, verified end to end.
# Assumes Labs 9-14 (namespace, quota, CM/Secret, MySQL, PV/PVC).
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Kubernetes/Lab15"
CTX="--context kind-ivolve"

# 1. Image: built locally (no Docker Hub creds in this session) and loaded into kind.
docker build -t ivolveapp:lab15 "$HOME/labs-workspace/iVolveApp"
kind load docker-image ivolveapp:lab15 --name ivolve

# 2. Service + Deployment.
kubectl $CTX apply -f "$LAB/service.yaml" -f "$LAB/deployment.yaml"
kubectl $CTX rollout status deployment/ivolveapp -n ivolve --timeout=420s
kubectl $CTX get deployment,svc,pods -n ivolve -o wide
kubectl $CTX get resourcequota -n ivolve

# 3. Init container did its job.
POD=$(kubectl $CTX -n ivolve get pod -l app=ivolveapp -o jsonpath='{.items[0].metadata.name}')
kubectl $CTX -n ivolve logs "$POD" -c init-db
kubectl $CTX -n ivolve logs "$POD" --tail=5

# 4. Service responds (port-forward for a local curl).
kubectl $CTX -n ivolve port-forward svc/ivolvaappsvc 3000:3000 >/tmp/pf.log 2>&1 &
PF=$!
for i in $(seq 1 20); do curl -sf http://127.0.0.1:3000/health >/dev/null 2>&1 && break; sleep 1; done
curl -s http://127.0.0.1:3000/health; echo
curl -s http://127.0.0.1:3000/ready; echo
kill $PF 2>/dev/null || true

# 5. Grants and the access log on the Lab 13 volume.
kubectl $CTX exec ivolvedb-0 -n ivolve -- sh -c 'mysql -h ivolvedbsvc -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW GRANTS FOR \"ivolveapp\"@\"%\";"'
docker exec ivolve-worker sh -c 'tail -3 /mnt/app-logs/access.log'
