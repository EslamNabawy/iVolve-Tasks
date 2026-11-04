#!/usr/bin/env bash
# Lab 10 — taint + label a worker, prove scheduling is blocked then allowed.
# Runs against the Lab 9 cluster (kind-ivolve). The aiops cluster is untouched.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Kubernetes/Lab10"
CTX="--context kind-ivolve"
NODE=ivolve-worker

# 1. Taint and label the same worker.
kubectl $CTX taint nodes "$NODE" workload=ivolveApp:NoSchedule --overwrite
kubectl $CTX label nodes "$NODE" project=ivolve --overwrite

# 2. Verify with both commands the lab names.
kubectl $CTX describe node "$NODE" | grep -E '^Taints:|workload='
kubectl $CTX get nodes -L project
kubectl $CTX get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# 3. A pod that targets the node but has no toleration must stay Pending.
kubectl $CTX apply -f "$LAB/pod-blocked.yaml"
sleep 10
kubectl $CTX get pod taint-demo-blocked -o wide
kubectl $CTX get events --field-selector involvedObject.name=taint-demo-blocked | tail -2

# 4. The same pod with the toleration runs on the tainted node.
kubectl $CTX apply -f "$LAB/pod-allowed.yaml"
kubectl $CTX wait --for=condition=Ready pod/taint-demo-allowed --timeout=120s
kubectl $CTX get pods -o wide | grep -E 'taint-demo|NAME'

# 5. The proof is the pair: Pending vs Running, one field apart.
kubectl $CTX get pod taint-demo-allowed -o jsonpath='{.spec.nodeName}'; echo
