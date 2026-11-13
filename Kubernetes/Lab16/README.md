# Lab 16: CPU and memory requests/limits

**Track:** Container Orchestration · **Cluster:** kind `ivolve` ·
**Namespace:** `ivolve` · **Context:** `kind-ivolve`

> Deck Lab 16 asks to update the existing `ivolveApp` Deployment with requests
> (cpu 1, memory 1Gi) and limits (cpu 2, memory 2Gi), verify them with
> `kubectl describe pod`, and watch real usage with `kubectl top pod`.

## Requirements

- [x] requests `cpu: 1`, `memory: 1Gi`
- [x] limits `cpu: 2`, `memory: 2Gi`
- [x] visible in `kubectl describe pod`
- [x] `kubectl top pod` returns live numbers (metrics-server installed)
- [x] rollout completed without breaking the Lab 11 quota

## What I got

| Check | Result |
|---|---|
| Requests | `cpu: 1`, `memory: 1Gi` |
| Limits | `cpu: 2`, `memory: 2Gi` |
| Rollout | with `maxSurge: 0`, a surge pod is impossible at 3/3 quota |
| `kubectl top pods` | app replicas ~`1m` / `20Mi`; MySQL `4m` / `434Mi` |
| `kubectl top nodes` | control-plane `190m 3% 1550Mi 15%`, worker `89m 1% 1660Mi 16%`, worker2 `141m 2% 1100Mi 11%` |

## Walkthrough

### 1. The patch

`resources-patch.yaml` is a strategic merge patch, so it updates the existing
container by name rather than replacing the Deployment:

```yaml
    spec:
  template:
    spec:
      containers:
        - name: app
          resources:
            requests:
              cpu: "1"
              memory: 1Gi
            limits:
              cpu: "2"
              memory: 2Gi
```

```console
$ kubectl --context kind-ivolve patch deployment ivolveapp -n ivolve \
    --type=strategic --patch-file Kubernetes/Lab16/resources-patch.yaml
deployment.apps/ivolveapp patched
```

### 2. The rollout deadlock (and the fix)

The first rollout stalled. The reason was the Lab 11 quota, not resources:

```console
$ kubectl --context kind-ivolve -n ivolve get events --sort-by=.lastTimestamp | tail -3
Warning  FailedCreate  replicaset/ivolveapp-659fff8d5d
  Error creating: pods "ivolveapp-659fff8d5d-jdn6z" is forbidden:
  exceeded quota: ivolvequota, requested: pods=1, used: pods=3, limited: pods=3
```

A default `RollingUpdate` adds a surge pod before removing an old one
(`maxSurge: 25%` → 1 for two replicas). MySQL already holds one of the three
slots, so the surge pod is refused and the rollout waits forever.

The fix is zero surge, one old pod goes first, then its replacement:

```console
$ kubectl --context kind-ivolve -n ivolve patch deployment ivolveapp --type=merge \
    -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":0,"maxUnavailable":1}}}}'
$ kubectl --context kind-ivolve rollout status deployment/ivolveapp -n ivolve
deployment "ivolveapp" successfully rolled out
```

### 3. Verify with describe

```console
$ kubectl --context kind-ivolve -n ivolve describe pod <pod> | grep -A8 -E '^\s+Limits:|^\s+Requests:'
    Limits:
      cpu:     2
      memory:  2Gi
    Requests:
      cpu:     1
      memory:  1Gi
```

### 4. Live usage

kind ships no metrics pipeline, so `kubectl top` fails until metrics-server is
installed. The standard manifest needs one extra flag in kind, because the
kubelet's serving certificate is self-signed:

```console
$ kubectl --context kind-ivolve apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
$ kubectl --context kind-ivolve patch deployment metrics-server -n kube-system --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
deployment.apps/metrics-server patched

$ kubectl --context kind-ivolve top nodes
NAME                   CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
ivolve-control-plane   190m         3%       1550Mi          15%
ivolve-worker          89m          1%       1660Mi          16%
ivolve-worker2         141m         2%       1100Mi          11%

$ kubectl --context kind-ivolve top pods -n ivolve
NAME                         CPU(cores)   MEMORY(bytes)
ivolveapp-659fff8d5d-9z7gh   1m           20Mi
ivolveapp-659fff8d5d-jwtjh   1m           20Mi
ivolvedb-0                   4m           434Mi
```

## Notes

1. **Requests are for the scheduler, limits are for the kernel.** 1 CPU/1Gi
   requests reserve room on the node; 2 CPU/2Gi limits cap what the container
   may consume before being throttled (CPU) or OOM-killed (memory).
2. **A full quota makes default rollouts impossible.** `maxSurge` needs a spare
   pod slot; when the namespace is exactly full, use `maxSurge: 0` (or raise the
   quota) or every deploy hangs.
3. **`kubectl top` needs metrics-server, and kind needs `--kubelet-insecure-tls`.**
   Without that flag metrics-server cannot scrape the kubelet's self-signed
   certificate.
4. **`kubectl top` is a snapshot**, refreshed on the metrics-server scrape
 interval, not a monitoring system. Lab 18 installs Prometheus for history.
5. **Memory limits kill; CPU limits throttle.** A container over its memory
   limit is OOM-killed instantly; over its CPU limit it just runs slower.

## Clean up afterwards

The Deployment keeps these resources for Labs 17–18.

## Committing this

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab16
git commit -m "feat(lab16): CPU/memory requests and limits + metrics-server"
```
