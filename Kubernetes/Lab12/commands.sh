#!/usr/bin/env bash
# Lab 12 — ConfigMap + base64 Secret, proven through a consumer pod.
# Assumes Labs 9-11 state (kind-ivolve, namespace ivolve, 3-pod quota).
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Kubernetes/Lab12"
CTX="--context kind-ivolve"

# 1. The two objects.
kubectl $CTX apply -f "$LAB/configmap.yaml" -f "$LAB/secret.yaml"
kubectl $CTX get configmap ivolvecm -n ivolve -o yaml
kubectl $CTX get secret ivolvesecret -n ivolve -o yaml

# 2. base64 really decodes (length only — never print the secret).
kubectl $CTX get secret ivolvesecret -n ivolve -o jsonpath='{.data.DB_PASSWORD}' | base64 -d | wc -c

# 3. Free a quota slot, run the consumer, show what it saw.
kubectl $CTX delete pod quota-demo-3 -n ivolve --wait=true
kubectl $CTX apply -f "$LAB/demo-pod.yaml"
kubectl $CTX wait --for=jsonpath='{.status.phase}'=Succeeded pod/config-demo -n ivolve --timeout=120s
kubectl $CTX logs config-demo -n ivolve
kubectl $CTX get pod config-demo -n ivolve

# 4. Remove the consumer and restore 3/3.
kubectl $CTX delete pod config-demo -n ivolve --wait=true
kubectl $CTX apply -f "$HOME/iVolve-Tasks/Kubernetes/Lab11/demo-pods.yaml"
kubectl $CTX wait --for=condition=Ready pod/quota-demo-3 -n ivolve --timeout=120s
kubectl $CTX get resourcequota -n ivolve
