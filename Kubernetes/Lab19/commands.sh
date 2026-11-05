#!/usr/bin/env bash
# Lab 19 — ServiceAccount + Role + RoleBinding, verified with a real token.
set -euo pipefail
LAB="$HOME/iVolve-Tasks/Kubernetes/Lab19"
CTX="--context kind-ivolve"

kubectl $CTX apply -f "$LAB/serviceaccount.yaml" -f "$LAB/role.yaml" -f "$LAB/rolebinding.yaml"
kubectl $CTX -n ivolve get sa,role,rolebinding
kubectl $CTX -n ivolve describe role ivolvdeployrole

# Token + throwaway kubeconfig so the calls really run as the ServiceAccount.
TOKEN=$(kubectl $CTX -n ivolve create token jenkinssa --duration=2h)
SERVER=$(kubectl config view --raw --minify --context kind-ivolve -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --raw --minify --context kind-ivolve -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
cat > /tmp/rbac.kubeconfig <<KCFG
apiVersion: v1
kind: Config
clusters:
  - name: kind-ivolve
    cluster: { server: "$SERVER", certificate-authority-data: "$CA" }
users:
  - name: jenkinssa
    user: { token: "$TOKEN" }
contexts:
  - name: jenkinssa
    context: { cluster: kind-ivolve, user: jenkinssa, namespace: ivolve }
current-context: jenkinssa
KCFG
KC="--kubeconfig /tmp/rbac.kubeconfig"

for verb in create update patch list delete; do
  R=$(kubectl $CTX -n ivolve auth can-i "$verb" deployments --as=system:serviceaccount:ivolve:jenkinssa 2>/dev/null)
  printf '  %-6s deployments (ivolve): %s\n' "$verb" "$R"
done

kubectl $KC -n ivolve create deployment rbac-demo --image=busybox:1.36 --dry-run=server
kubectl $CTX -n ivolve get deployment ivolveapp -o yaml > /tmp/ivolveapp.yaml
python3 - <<'PY'
p = "/tmp/ivolveapp.yaml"
t = open(p).read()
t = t.replace("  annotations:\n", "  annotations:\n    rbac-test: \"jenkinssa-updated\"\n", 1)
open(p, "w").write(t)
PY
kubectl $KC -n ivolve replace -f /tmp/ivolveapp.yaml
kubectl $KC -n default create deployment rbac-demo --image=busybox:1.36 --dry-run=server || true
