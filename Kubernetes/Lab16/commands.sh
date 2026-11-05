#!/usr/bin/env bash
# Lab 16 — resource requests/limits, surge-free rollout, metrics-server.
set -euo pipefail
LAB="$HOME/iVolve-Tasks/Kubernetes/Lab16"
CTX="--context kind-ivolve"

# 1. Patch resources onto the existing Deployment.
kubectl $CTX patch deployment ivolveapp -n ivolve --type=strategic --patch-file "$LAB/resources-patch.yaml"
# 2. The 3-pod quota leaves no room for a surge pod.
kubectl $CTX -n ivolve patch deployment ivolveapp --type=merge \
  -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":0,"maxUnavailable":1}}}}'
kubectl $CTX rollout status deployment/ivolveapp -n ivolve --timeout=420s

# 3. Show the applied resources.
POD=$(kubectl $CTX -n ivolve get pod -l app=ivolveapp -o jsonpath='{.items[0].metadata.name}')
kubectl $CTX -n ivolve describe pod "$POD" | grep -A8 -E '^\s+Limits:|^\s+Requests:'

# 4. metrics-server for kubectl top.
kubectl $CTX apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl $CTX patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' || true
kubectl $CTX rollout status deployment/metrics-server -n kube-system --timeout=300s
sleep 20
kubectl $CTX top nodes
kubectl $CTX top pods -n ivolve
