# Lab 17: Only the app may reach MySQL

**Track:** Container Orchestration · **Cluster:** kind `ivolve` ·
**Namespace:** `ivolve` · **CNI:** Calico v3.33.0 · **Context:** `kind-ivolve`

> Deck Lab 17 asks for `ivolveNP` targeting the MySQL pod, `Ingress` only
> allowing traffic only from the application pods on port 3306.

## What it asks for

- [x] policy `ivolvenp` (lowercased from `ivolveNP`) selecting `app=ivolvedb`
- [x] `policyTypes: [Ingress]`
- [x] ingress only from `app=ivolveapp`, TCP 3306
- [x] an unrelated pod is **blocked** from 3306
- [x] the app keeps working (health check still 200)

## What happened

| Test | Before policy | After policy |
|---|---|---|
| `nettest-worker` (default ns) → `ivolvedbsvc:3306` | `TCP connect OK` | **`TCP connect BLOCKED`** |
| `nettest-worker2` (default ns) → 3306 | `TCP connect OK` | **`TCP connect BLOCKED`** |
| App `/health` through the Service | 200 | **200** (`DB query works`) |

## The policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ivolvenp
  namespace: ivolve
spec:
  podSelector:
    matchLabels:
      app: ivolvedb
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: ivolveapp
      ports:
        - protocol: TCP
          port: 3306
```

```console
$ kubectl --context kind-ivolve -n ivolve describe networkpolicy ivolvenp
Spec:
  PodSelector:     app=ivolvedb
  Allowing ingress traffic:
    To Port: 3306/TCP
    From:
      PodSelector: app=ivolveapp
  Not affecting egress traffic
  Policy Types: Ingress
```

## Step by step

### 1. Prove the hole exists first

The test pods come from Lab 9 (`default` namespace, label `app=nettest`), a
namespace outside `ivolve`, and not the app label, so the policy must stop them:

```console
$ kubectl --context kind-ivolve -n default exec nettest-worker -- \
    sh -c 'nc -z -w 3 ivolvedbsvc.ivolve.svc.cluster.local 3306 && echo "TCP connect OK"'
TCP connect OK
```

### 2. Apply and re-test

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab17/networkpolicy.yaml
networkpolicy.networking.k8s.io/ivolvenp created

$ kubectl --context kind-ivolve -n default exec nettest-worker -- \
    sh -c 'nc -z -w 3 ivolvedbsvc.ivolve.svc.cluster.local 3306 && echo "TCP connect OK" || echo "TCP connect BLOCKED"'
TCP connect BLOCKED
```

One gotcha: the first re-test still reported `TCP connect OK`. Calico needs a
few seconds to program the rules on the node; **the policy had applied but not
propagated**. Re-checking after a pause gave `BLOCKED`. Evidence capture should
sleep a few seconds after applying a NetworkPolicy.

### 3. The app keeps working

```console
$ curl -s http://127.0.0.1:3000/health   # through a port-forward of ivolvaappsvc
🚀 iVolve web app is working! Keep calm and code on! 🎉
```

That request runs `SELECT 1` against MySQL from an `app=ivolveapp` pod, so the
allowed path is proven, not just the blocked one.

## What I'd do differently

1. **NetworkPolicy is enforced by the CNI, not by kube-proxy.** kind's default
   CNI ignores NetworkPolicy; Calico (Lab 9) is what makes this lab real.
2. **An empty `from` means "everything".** A policy with `ingress: [{}]` allows
   all; the rule has to name the source selector and port.
3. **Policies are additive and namespaced.** Any policy selecting the pod
   applies; traffic must be allowed by at least one rule. Other pods in
   `ivolve` are blocked by this policy even though they are in the same
   namespace.
4. **Ingress-only leaves egress alone.** MySQL can still reach out (for DNS
   replication, etc.); the deck only asked to protect the ingress side.
5. **Propagation is asynchronous.** Apply → wait → test. A same-second check
   can report a false pass.
6. **Policy selectors are label-based.** The init container inherits the pod
   label `app=ivolveapp`, which is why database preparation still works.

## Cleanup

The policy stays in place; it is part of the final lab state.

## Commit

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab17
git commit -m "feat(lab17): NetworkPolicy restricting MySQL to app pods"
```
