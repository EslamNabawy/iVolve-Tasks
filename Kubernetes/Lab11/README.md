# Lab 11 — Namespace management and ResourceQuota enforcement

**Track:** Container Orchestration · **Cluster:** kind `ivolve` (Lab 9) ·
**Namespace:** `ivolve` · **Context:** `kind-ivolve`

> Deck Lab 11 asks for a namespace `ivolve`, a ResourceQuota `ivolveQuota`
> limiting the namespace to **3 pods**, verification that the quota is applied,
> and proof that Kubernetes refuses a fourth pod.

## Requirements

- [x] namespace `ivolve` created (it is reused by Labs 12–17)
- [x] ResourceQuota limiting total pods to 3
- [x] quota verified as applied (`kubectl describe quota`, `get resourcequota`)
- [x] three pods run, a fourth is **refused by the API server**
- [x] the counter is live: freeing a slot lets the fourth pod in
- [x] the deck's name `ivolveQuota` documented as invalid Kubernetes syntax

## Results

| Check | Result |
|---|---|
| Namespace | `ivolve` — `Active` |
| Quota | `ivolvequota` — `pods: 3/3` |
| Pods running | `quota-demo-1`, `-2`, `-3` (all on `ivolve-worker2`) |
| Fourth pod | `Forbidden: exceeded quota: ivolvequota, requested: pods=1, used: pods=3, limited: pods=3` |
| Object after refusal | `NotFound` — the pod was never created |
| Counter test | delete one → `2/3` → fourth pod starts → `3/3` again |

## Steps

### 1 — Create the namespace

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab11/namespace.yaml
namespace/ivolve created

$ kubectl --context kind-ivolve get namespace ivolve
NAME     STATUS   AGE
ivolve   Active   0s
```

### 2 — The deck's quota name is not a legal Kubernetes name

The slide says "a ResourceQuota named `ivolveQuota`". Kubernetes object names
are lowercase RFC 1123 subdomains, so the API server rejects it outright:

```console
$ kubectl --context kind-ivolve create quota ivolveQuota --hard=pods=3 -n ivolve
error: failed to create quota: ResourceQuota "ivolveQuota" is invalid: metadata.name:
Invalid value: "ivolveQuota": a lowercase RFC 1123 subdomain must consist of lower
case alphanumeric characters, '-' or '.', and must start and end with an alphanumeric
character (e.g. 'example.com', regex used for validation is
'[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*')
```

The manifest therefore uses **`ivolvequota`**. The intent of the slide — one
quota on the `ivolve` namespace capping pods — is unchanged; only the casing
that the API accepts is.

### 3 — Create the quota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ivolvequota
  namespace: ivolve
spec:
  hard:
    pods: "3"
```

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab11/quota.yaml
resourcequota/ivolvequota created

$ kubectl --context kind-ivolve describe quota ivolvequota -n ivolve
Name:       ivolvequota
Namespace:  ivolve
Resource    Used  Hard
--------    ----  ----
pods        0     3
```

`pods: "3"` is a **count** quota, not a compute quota: it limits how many pod
objects may exist, so the demo pods need no `resources:` block.

### 4 — Fill it: three pods

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab11/demo-pods.yaml
pod/quota-demo-1 created
pod/quota-demo-2 created
pod/quota-demo-3 created
pod/quota-demo-1 condition met
pod/quota-demo-2 condition met
pod/quota-demo-3 condition met

$ kubectl --context kind-ivolve get pods -n ivolve -o wide
NAME           READY   STATUS    RESTARTS   AGE   IP               NODE
quota-demo-1   1/1     Running   0          1s    192.168.209.74   ivolve-worker2
quota-demo-2   1/1     Running   0          1s    192.168.209.73   ivolve-worker2
quota-demo-3   1/1     Running   0          1s    192.168.209.75   ivolve-worker2

$ kubectl --context kind-ivolve describe quota ivolvequota -n ivolve
Resource    Used  Hard
--------    ----  ----
pods        3     3
```

All three landed on `ivolve-worker2` — a side effect of Lab 10, whose
`NoSchedule` taint keeps ordinary pods off `ivolve-worker`. The labs compose.

### 5 — The fourth pod is refused

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab11/extra-pod.yaml
Error from server (Forbidden): error when creating
"Kubernetes/Lab11/extra-pod.yaml": pods "quota-demo-4" is forbidden:
exceeded quota: ivolvequota, requested: pods=1, used: pods=3, limited: pods=3

$ kubectl --context kind-ivolve get pod quota-demo-4 -n ivolve
Error from server (NotFound): pods "quota-demo-4" not found
```

`Forbidden` and `NotFound` together are the point: this is **admission
control**, so the object never enters etcd. It is not a pod sitting `Pending` —
the API server rejected the write.

### 6 — The counter is live

A quota is not a one-time gate. Deleting one pod frees a slot immediately:

```console
$ kubectl --context kind-ivolve delete pod quota-demo-3 -n ivolve
pod "quota-demo-3" deleted from ivolve namespace

$ kubectl --context kind-ivolve describe quota ivolvequota -n ivolve
Resource    Used  Hard
--------    ----  ----
pods        2     3

$ kubectl --context kind-ivolve apply -f Kubernetes/Lab11/extra-pod.yaml
pod/quota-demo-4 created
```

The lab state was then restored: `quota-demo-4` deleted, `quota-demo-3`
re-created, quota back to `3/3`.

## Things worth knowing

1. **Quota rejection happens at admission, not scheduling.** A scheduler
   problem leaves a pod `Pending`; a quota problem means the pod object is
   never created (`NotFound`).
2. **`pods: "3"` and compute quotas behave differently.** A count quota needs
   no `resources:` block. Add `requests.cpu`/`limits.memory` to the quota and
   every pod in the namespace must then declare those fields, or it is rejected
   with "must specify limits".
3. **Quotas are namespaced.** The three Lab 10 demo pods in `default` are
   unaffected; the cap applies only inside `ivolve`.
4. **Kubernetes names are lowercase.** `ivolveQuota` cannot exist. The
   lowercase form `ivolvequota` keeps the slide's intent and is what every
   later lab (`ivolveCM`, `ivolveSecret`, …) will have to do too.
5. **The counter is live.** Deleting a pod frees its slot right away, so a
   failed deploy can succeed after a cleanup without touching the quota.
6. **A quota does not reserve capacity.** Three pods are allowed, but whether
   they can run still depends on nodes — Lab 10's taint is why all three are on
   `ivolve-worker2`.

## Cleanup

The namespace, quota and three demo pods are left in place: Labs 12–17 all use
the `ivolve` namespace and this quota. To undo only this lab:

```bash
kubectl --context kind-ivolve delete namespace ivolve   # also deletes the quota and pods
```

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab11
git commit -m "feat(lab11): namespace and pod-count ResourceQuota"
```
