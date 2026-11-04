#!/usr/bin/env bash
# Lab 13 — static hostPath PV + PVC, with a write/read-back proof.
# Assumes Labs 9-12 state (kind-ivolve, namespace ivolve, 3-pod quota).
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Kubernetes/Lab13"
CTX="--context kind-ivolve"

# 1. The node path (hostPath lives inside the node container).
docker exec ivolve-worker sh -c 'mkdir -p /mnt/app-logs && ls -ld /mnt/app-logs'

# 2. PV + PVC, both classless.
kubectl $CTX apply -f "$LAB/pv.yaml" -f "$LAB/pvc.yaml"
kubectl $CTX describe pv ivolvepv | grep -E 'Capacity|Access Modes|Reclaim Policy|StorageClass|Status'
kubectl $CTX get pvc ivolvepvc -n ivolve

# 3. Write through the claim (free a quota slot first).
kubectl $CTX delete pod quota-demo-3 -n ivolve --wait=true
kubectl $CTX apply -f "$LAB/writer-pod.yaml"
kubectl $CTX wait --for=jsonpath='{.status.phase}'=Succeeded pod/log-writer -n ivolve --timeout=180s
kubectl $CTX logs log-writer -n ivolve

# 4. Read the same bytes from the node.
docker exec ivolve-worker sh -c 'ls -l /mnt/app-logs && cat /mnt/app-logs/lab13.txt'

# 5. Clean up the writer, restore 3/3.
kubectl $CTX delete pod log-writer -n ivolve --wait=true
kubectl $CTX apply -f "$HOME/iVolve-Tasks/Kubernetes/Lab11/demo-pods.yaml"
kubectl $CTX wait --for=condition=Ready pod/quota-demo-3 -n ivolve --timeout=120s
kubectl $CTX get resourcequota -n ivolve
