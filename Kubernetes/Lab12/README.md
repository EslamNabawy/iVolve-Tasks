# Lab 12 — ConfigMaps and Secrets for MySQL

**Track:** Container Orchestration · **Cluster:** kind `ivolve` (Lab 9) ·
**Namespace:** `ivolve` · **Context:** `kind-ivolve`

> Deck Lab 12 asks for a ConfigMap `ivolveCM` holding `DB_HOST` and `DB_USER`,
> a Secret `ivolveSecret` holding `MYSQL_ROOT_PASSWORD` and `DB_PASSWORD` with
> **base64-encoded** values in the YAML, both in the `ivolve` namespace.

## Requirements

- [x] ConfigMap `ivolvecm` — `DB_HOST` (headless Service hostname), `DB_USER`
- [x] Secret `ivolvesecret` — `MYSQL_ROOT_PASSWORD`, `DB_PASSWORD`
- [x] both values written as base64 under `data:`
- [x] objects verified in the cluster; base64 proven to decode
- [x] a pod consuming both objects sees `DB_HOST`, `DB_USER`, `DB_PASSWORD`
- [x] the Lab 11 quota stays intact (3/3) after the test

## Two names that had to change

The slide says `ivolveCM` and `ivolveSecret`. Kubernetes object names are
lowercase RFC 1123 subdomains, so the manifests use **`ivolvecm`** and
**`ivolvesecret`** — the same rule Lab 11 hit with `ivolveQuota`.

`DB_HOST` is the headless Service that **Lab 14** creates (`ivolveDBSvc` on the
slide). Lowercased, that is **`ivolvedbsvc`**, and that is the value stored
today. It does not resolve yet — nothing named that exists until Lab 14 — which
is why this lab proves the variable reaches the container instead of resolving
it.

## Results

| Check | Result |
|---|---|
| ConfigMap | `ivolvecm` — `DB_HOST=ivolvedbsvc`, `DB_USER=ivolveapp` |
| Secret | `ivolvesecret` (Opaque) — 2 keys, base64 in the manifest and in the API |
| Base64 check | `DB_PASSWORD` decodes to **10 bytes** |
| Consumer pod | `DB_HOST=ivolvedbsvc` · `DB_USER=ivolveapp` · `DB_PASSWORD_length=10` |
| Quota | 3/3 before and after the test |

## Steps

### 1 — The ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ivolvecm
  namespace: ivolve
data:
  DB_HOST: ivolvedbsvc
  DB_USER: ivolveapp
```

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab12/configmap.yaml
configmap/ivolvecm created

$ kubectl --context kind-ivolve get configmap ivolvecm -n ivolve -o yaml
apiVersion: v1
data:
  DB_HOST: ivolvedbsvc
  DB_USER: ivolveapp
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"DB_HOST":"ivolvedbsvc","DB_USER":"ivolveapp"},...}
  creationTimestamp: "2026-11-04T23:14:04Z"
  name: ivolvecm
  namespace: ivolve
  resourceVersion: "4966"
  uid: 12e96304-24a8-4d84-a8a2-0bc44b6da58a
```

### 2 — The Secret, base64 in the manifest

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ivolvesecret
  namespace: ivolve
type: Opaque
data:
  # echo -n 'ivolveroot' | base64
  MYSQL_ROOT_PASSWORD: aXZvbHZlcm9vdA==
  # echo -n 'ivolvepass' | base64
  DB_PASSWORD: aXZvbHZlcGFzcw==
```

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab12/secret.yaml
secret/ivolvesecret created

$ kubectl --context kind-ivolve get secret ivolvesecret -n ivolve -o yaml
apiVersion: v1
data:
  DB_PASSWORD: aXZvbHZlcGFzcw==
  MYSQL_ROOT_PASSWORD: aXZvbHZlcm9vdA==
kind: Secret
metadata:
  name: ivolvesecret
  namespace: ivolve
  resourceVersion: "4967"
type: Opaque
```

**These are throwaway lab credentials**, committed so the lab is reproducible.
base64 is encoding, not encryption: `echo aXZvbHZlcGFzcw== | base64 -d` gives
the password back, and so does anyone with `get secret`. A real cluster needs
RBAC restricting who can read Secrets plus encryption at rest — never commit a
credential that matters.

The decode check here deliberately prints only the length:

```console
$ kubectl --context kind-ivolve get secret ivolvesecret -n ivolve -o jsonpath='{.data.DB_PASSWORD}' | base64 -d | wc -c
10
```

### 3 — Prove both objects reach a container

`demo-pod.yaml` injects the whole ConfigMap and Secret with `envFrom`, then
prints everything except the password value:

```yaml
envFrom:
  - configMapRef:
      name: ivolvecm
  - secretRef:
      name: ivolvesecret
```

The Lab 11 quota caps the namespace at 3 pods, so one demo pod is removed
first and restored afterwards:

```console
$ kubectl --context kind-ivolve delete pod quota-demo-3 -n ivolve
pod "quota-demo-3" deleted from ivolve namespace

$ kubectl --context kind-ivolve apply -f Kubernetes/Lab12/demo-pod.yaml
pod/config-demo created
pod/config-demo condition met

$ kubectl --context kind-ivolve logs config-demo -n ivolve
DB_HOST=ivolvedbsvc
DB_USER=ivolveapp
DB_PASSWORD_length=10

$ kubectl --context kind-ivolve get pod config-demo -n ivolve
NAME          READY   STATUS      RESTARTS   AGE
config-demo   0/1     Completed   0          3s
```

`Completed 0/1` is correct for a one-shot pod: it ran, printed, and exited.
The password arrived (10 characters, matching the decoded length) without ever
being printed.

### 4 — Restore the quota state

```console
$ kubectl --context kind-ivolve delete pod config-demo -n ivolve
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab11/demo-pods.yaml
$ kubectl --context kind-ivolve get resourcequota -n ivolve
NAME          REQUEST     LIMIT   AGE
ivolvequota   pods: 3/3           6m52s
```

## Things worth knowing

1. **base64 is not encryption.** A Secret hides values from `kubectl describe`,
   not from anyone allowed to `get` it. The protection is RBAC plus (in a real
   cluster) etcd encryption.
2. **`data:` is base64; `stringData:` is plaintext.** Both work; `stringData`
   is encoded by the API server on write, so the stored object still shows
   base64 under `data`.
3. **ConfigMap vs Secret is a policy line, not a technical one.** Both reach a
   container the same way; the difference is who is allowed to read them and
   how they are handled at rest and in logs.
4. **`envFrom` injects every key; `valueFrom` picks one.** `envFrom` is quick
   but makes the pod's environment depend on the whole object — adding a key
   later changes the pod. `valueFrom.secretKeyRef` names exactly one key.
5. **`DB_HOST` is forward-looking.** `ivolvedbsvc` resolves only after Lab 14
   creates the headless Service; this lab proves the value is injected, not
   that the host exists.
6. **The quota forces a trade.** With three pods allowed, a Lab 12 consumer
   needs a slot; deleting a demo pod and restoring it afterwards keeps Lab 11's
   evidence intact.

## Cleanup

Both objects stay: Labs 14 and 15 consume them for MySQL and the Node app.

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab12
git commit -m "feat(lab12): ConfigMap and base64 Secret for MySQL"
```
