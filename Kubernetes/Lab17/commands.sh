#!/usr/bin/env bash
# Lab 17 — NetworkPolicy, proven by an unrelated pod and by the app's health.
set -euo pipefail
LAB="$HOME/iVolve-Tasks/Kubernetes/Lab17"
CTX="--context kind-ivolve"

# 1. Baseline: unrelated pod reaches MySQL.
kubectl $CTX -n default exec nettest-worker -- sh -c 'nc -z -w 3 ivolvedbsvc.ivolve.svc.cluster.local 3306 && echo "TCP connect OK" || echo "TCP connect BLOCKED"'

# 2. Apply the policy.
kubectl $CTX apply -f "$LAB/networkpolicy.yaml"
kubectl $CTX -n ivolve describe networkpolicy ivolvenp

# 3. Calico needs a moment to program the rules.
sleep 10
kubectl $CTX -n default exec nettest-worker -- sh -c 'nc -z -w 3 ivolvedbsvc.ivolve.svc.cluster.local 3306 && echo "TCP connect OK" || echo "TCP connect BLOCKED"'
kubectl $CTX -n default exec nettest-worker2 -- sh -c 'nc -z -w 3 ivolvedbsvc.ivolve.svc.cluster.local 3306 && echo "TCP connect OK" || echo "TCP connect BLOCKED"'

# 4. Allowed path still works.
kubectl $CTX -n ivolve port-forward svc/ivolvaappsvc 3000:3000 >/tmp/pf17.log 2>&1 &
PF=$!
for i in $(seq 1 20); do curl -sf http://127.0.0.1:3000/health >/dev/null 2>&1 && break; sleep 1; done
curl -s http://127.0.0.1:3000/health; echo
kill $PF 2>/dev/null || true
