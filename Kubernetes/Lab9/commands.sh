#!/usr/bin/env bash
# Lab 9 — reproduce the three-node cluster + Calico end to end.
# Leaves the cluster running for Labs 10-17; the unrelated aiops cluster is
# never touched.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Kubernetes/Lab9"
CTX="--context kind-ivolve"
CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml"

# 0. Remove a previous run of THIS lab only.
kind delete cluster --name ivolve 2>/dev/null || true

# 1. Create the cluster. kind bootstraps every node with kubeadm, so the
#    control plane and both workers are real kubelet nodes.
kind create cluster --name ivolve --config "$LAB/kind-config.yaml" --wait 180s

# 2. No CNI yet: NotReady is the expected state here.
kubectl $CTX get nodes

# 3. Calico provides the pod network.
curl -fsSL "$CALICO_URL" -o /tmp/calico.yaml
kubectl $CTX apply -f /tmp/calico.yaml
kubectl $CTX -n kube-system rollout status ds/calico-node --timeout=600s
kubectl $CTX -n kube-system rollout status deploy/calico-kube-controllers --timeout=600s
kubectl $CTX wait --for=condition=Ready nodes --all --timeout=300s

# 4. Every node Ready, Calico 3/3, one IP pool.
kubectl $CTX get nodes -o wide
kubectl $CTX -n kube-system get ds calico-node
kubectl $CTX get ippools.crd.projectcalico.org -o jsonpath='{.items[0].spec.cidr}'; echo

# 5. Pod-to-pod across two worker nodes.
kubectl $CTX apply -f "$LAB/nettest.yaml" -f "$LAB/nettest2.yaml"
kubectl $CTX wait --for=condition=Ready pod/nettest-worker pod/nettest-worker2 --timeout=180s
IP2=$(kubectl $CTX get pod nettest-worker2 -o jsonpath='{.status.podIP}')
IP1=$(kubectl $CTX get pod nettest-worker -o jsonpath='{.status.podIP}')
kubectl $CTX get pods -o wide -l app=nettest
kubectl $CTX exec nettest-worker -- ping -c 3 "$IP2"
kubectl $CTX exec nettest-worker2 -- ping -c 3 "$IP1"

# 6. DNS resolves through the Calico-routed service network.
kubectl $CTX exec nettest-worker -- nslookup kubernetes.default.svc.cluster.local
