# Lab 19 — RBAC: a service account that may only deploy

**Track:** Security · **Cluster:** kind `ivolve` · **Namespace:** `ivolve` ·
**Context:** `kind-ivolve`

> Deck Lab 19 asks for a `jenkinsSA` ServiceAccount, a token for it, a Role
> `ivolveDeployRole` granting create/update on Deployments in `ivolve`, a
> RoleBinding `ivolveDeployRoleBinding`, and proof that this is **all** it can
> do.

## Requirements

- [x] ServiceAccount `jenkinssa` in `ivolve`
- [x] short-lived token issued for it (TokenRequest API)
- [x] Role `ivolvdeployrole` — `apps/deployments`, verbs `create`, `update`
- [x] RoleBinding `ivolvdeployrolebinding` to that ServiceAccount
- [x] create/update allowed in `ivolve`
- [x] patch/list/delete denied; other namespaces denied; pods/services denied

## Names

`jenkinsSA` → **`jenkinssa`**, `ivolveDeployRole` → **`ivolvdeployrole`**,
`ivolveDeployRoleBinding` → **`ivolvdeployrolebinding`** — Kubernetes names are
lowercase RFC 1123 subdomains.

## Results

| Check (as `system:serviceaccount:ivolve:jenkinssa`) | Result |
|---|---|
| `create deployments` in `ivolve` | **yes** — `deployment.apps/rbac-demo created (server dry run)` |
| `update deployments` in `ivolve` | **yes** — `deployment.apps/ivolveapp replaced` |
| `patch` deployments in `ivolve` | **no** |
| `list` deployments in `ivolve` | **no** |
| `delete` deployments in `ivolve` | **no** |
| `create deployments` in `default` | **no** — `... cannot create resource "deployments" ... in the namespace "default"` |
| `list pods` / `create services` in `ivolve` | **no** |

## The three objects

```yaml
apiVersion: v1
kind: ServiceAccount
metadata: { name: jenkinssa, namespace: ivolve }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: ivolvdeployrole, namespace: ivolve }
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: ivolvdeployrolebinding, namespace: ivolve }
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ivolvdeployrole
subjects:
  - kind: ServiceAccount
    name: jenkinssa
    namespace: ivolve
```

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab19/serviceaccount.yaml \
    -f Kubernetes/Lab19/role.yaml -f Kubernetes/Lab19/rolebinding.yaml
serviceaccount/jenkinssa created
role.rbac.authorization.k8s.io/ivolvdeployrole created
rolebinding.rbac.authorization.k8s.io/ivolvdeployrolebinding created

$ kubectl --context kind-ivolve -n ivolve describe role ivolvdeployrole
PolicyRule:
  Resources         Non-Resource URLs  Resource Names  Verbs
  ---------         -----------------  --------------  -----
  deployments.apps  []                 []              [create update]
```

## The token

```console
$ TOKEN=$(kubectl --context kind-ivolve -n ivolve create token jenkinssa --duration=2h)
```

That is a **TokenRequest**-issued JWT with a two-hour life, not a legacy
Secret-based token: nothing long-lived is stored in the cluster. The tests
below use it through a throwaway kubeconfig, so they run as the ServiceAccount
for real — not with `--as` impersonation.

## What it can and cannot do

```console
$ kubectl --context kind-ivolve -n ivolve auth can-i create deployments \
    --as=system:serviceaccount:ivolve:jenkinssa
yes
$ kubectl --context kind-ivolve -n ivolve auth can-i update deployments \
    --as=system:serviceaccount:ivolve:jenkinssa
yes
$ kubectl --context kind-ivolve -n ivolve auth can-i list deployments \
    --as=system:serviceaccount:ivolve:jenkinssa
no
```

Real API calls with the token:

```console
$ kubectl --kubeconfig /tmp/rbac.kubeconfig -n ivolve \
    create deployment rbac-demo --image=busybox:1.36 --dry-run=server
deployment.apps/rbac-demo created (server dry run)

$ kubectl --kubeconfig /tmp/rbac.kubeconfig -n ivolve replace -f /tmp/ivolveapp.yaml
deployment.apps/ivolveapp replaced

$ kubectl --kubeconfig /tmp/rbac.kubeconfig -n default \
    create deployment rbac-demo --image=busybox:1.36 --dry-run=server
error: failed to create deployment: deployments.apps is forbidden:
User "system:serviceaccount:ivolve:jenkinssa" cannot create resource
"deployments" in API group "apps" in the namespace "default"
```

The replace added an annotation (`rbac-test: jenkinssa-updated`) to the live
Deployment, which is a genuine update — no rollout, because only metadata
changed.

## Things worth knowing

1. **A Role is namespaced; a ClusterRole is not.** `ivolvdeployrole` only
   exists in `ivolve`, so even with the right verbs it cannot touch another
   namespace. That is the "only in this namespace" half of the lab.
2. **`patch` is a separate verb from `update`.** `kubectl apply`, `annotate`
   and `label` all need `patch`; `replace` needs `update`. This role can
   replace but not apply — a subtle difference worth knowing before writing a
   Jenkins deploy step.
3. **`create` and `update` do not imply `get` or `list`.** The account can push
   a Deployment but cannot read it back; `kubectl rollout status` would fail
   with this Role. Least privilege is a trade-off, not free.
4. **`create token` is the modern way.** The old `kubernetes.io/service-account-token`
   Secret still works but creates long-lived credentials; TokenRequest tokens
   expire and are not persisted.
5. **RBAC is additive.** There is no deny rule here; "no" above comes from
   nothing granting it, which is exactly how deny-by-default works.

## Cleanup

The ServiceAccount, Role, RoleBinding and token stay for the Jenkins deployment
labs (20–22).

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab19
git commit -m "feat(lab19): RBAC role and service account for deploys"
```
