#!/usr/bin/env bash
# Lab 11 — namespace + ResourceQuota (3 pods), with the refusal proven.
# Runs against the Lab 9 cluster; the aiops cluster is untouched.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Kubernetes/Lab11"
CTX="--context kind-ivolve"

# 1. Namespace (reused by Labs 12-17).
kubectl $CTX apply -f "$LAB/namespace.yaml"
kubectl $CTX get namespace ivolve

# 2. The deck's spelling is invalid; keep it as the lesson, not the manifest.
kubectl $CTX create quota ivolveQuota --hard=pods=3 -n ivolve 2>&1 || true

# 3. The legal quota.
kubectl $CTX apply -f "$LAB/quota.yaml"
kubectl $CTX describe quota ivolvequota -n ivolve

# 4. Fill it to 3/3.
kubectl $CTX apply -f "$LAB/demo-pods.yaml"
kubectl $CTX wait --for=condition=Ready pod/quota-demo-1 pod/quota-demo-2 pod/quota-demo-3 -n ivolve --timeout=180s
kubectl $CTX get pods -n ivolve -o wide
kubectl $CTX describe quota ivolvequota -n ivolve

# 5. The fourth pod must be refused at admission (expected non-zero exit).
kubectl $CTX apply -f "$LAB/extra-pod.yaml" 2>&1 || true
kubectl $CTX get pod quota-demo-4 -n ivolve 2>&1 || true

# 6. Prove the counter is live, then restore 3/3.
kubectl $CTX delete pod quota-demo-3 -n ivolve --wait=true
kubectl $CTX describe quota ivolvequota -n ivolve
kubectl $CTX apply -f "$LAB/extra-pod.yaml"
kubectl $CTX wait --for=condition=Ready pod/quota-demo-4 -n ivolve --timeout=120s
kubectl $CTX delete pod quota-demo-4 -n ivolve --wait=true
kubectl $CTX apply -f "$LAB/demo-pods.yaml"
kubectl $CTX wait --for=condition=Ready pod/quota-demo-3 -n ivolve --timeout=120s
kubectl $CTX describe quota ivolvequota -n ivolve
