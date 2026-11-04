# Lab 10 — Node isolation with taints and labels

**Track:** Container Orchestration · **Cluster:** kind `ivolve` (3 nodes, from Lab 9) ·
**Node:** `ivolve-worker` · **Context:** `kind-ivolve`

> Deck Lab 10 asks for a taint `workload=ivolveApp:NoSchedule` on a worker so
> pods cannot land there without a matching toleration, the label
> `project=ivolve` on the same worker for targeted scheduling, and verification
> with `kubectl describe node` and `kubectl get nodes --show-labels`.

## Requirements

- [x] taint `workload=ivolveApp:NoSchedule` applied to a worker node
- [x] label `project=ivolve` applied to the same node
- [x] taint and label verified with `describe node` and `--show-labels`
- [x] a pod that targets the node **without** a toleration stays `Pending`
- [x] the same pod **with** the toleration runs on that node
- [x] the other worker stays untainted and unlabelled (the control is honest)

## Results

| Check | Result |
|---|---|
| Taint | `workload=ivolveApp:NoSchedule` on `ivolve-worker` |
| Label | `project=ivolve` on `ivolve-worker` |
| Pod with `nodeSelector: project=ivolve`, no toleration | **`Pending`** — `2 node(s) had untolerated taint(s)` |
| Same pod + toleration `workload=ivolveApp:NoSchedule` | **`Running`** on `ivolve-worker`, `192.168.194.4` |
| `ivolve-worker2` | no taint, no `project` label |
| Control plane | already tainted `node-role.kubernetes.io/control-plane:NoSchedule` |

## Steps

### 1 — Taint and label the worker

```console
$ kubectl --context kind-ivolve taint nodes ivolve-worker workload=ivolveApp:NoSchedule --overwrite
node/ivolve-worker modified

$ kubectl --context kind-ivolve label nodes ivolve-worker project=ivolve --overwrite
node/ivolve-worker labeled
```

`--overwrite` matters for a re-run: without it, applying an existing
taint/label exits with "already has ..." and the script stops.

### 2 — Verify the taint

```console
$ kubectl --context kind-ivolve describe node ivolve-worker | grep -E '^Taints:|workload='
Taints:             workload=ivolveApp:NoSchedule

$ kubectl --context kind-ivolve get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
NAME                   TAINTS
ivolve-control-plane   [map[effect:NoSchedule key:node-role.kubernetes.io/control-plane]]
ivolve-worker          [map[effect:NoSchedule key:workload value:ivolveApp]]
ivolve-worker2         <none>
```

Two taints exist in the cluster for different reasons: the control-plane taint
is kind's own (it keeps normal workloads off the control plane), and ours is the
Lab 10 one. That detail explains the scheduler message in step 4.

### 3 — Verify the label

```console
$ kubectl --context kind-ivolve get nodes -L project
NAME                   STATUS   ROLES           AGE   VERSION   PROJECT
ivolve-control-plane   Ready    control-plane   30m   v1.37.0
ivolve-worker          Ready    <none>          29m   v1.37.0   ivolve
ivolve-worker2         Ready    <none>          29m   v1.37.0
```

```console
$ kubectl --context kind-ivolve get node ivolve-worker --show-labels | tr ',' '\n' | grep -E 'project|NAME'
NAME            STATUS   ROLES    AGE   VERSION   LABELS
project=ivolve
```

### 4 — A pod that wants the node but does not tolerate the taint

`pod-blocked.yaml` has `nodeSelector: {project: ivolve}` and no toleration:

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab10/pod-blocked.yaml
pod/taint-demo-blocked created

$ kubectl --context kind-ivolve get pod taint-demo-blocked -o wide
NAME                 READY   STATUS    RESTARTS   AGE   IP       NODE     NOMINATED NODE
taint-demo-blocked   0/1     Pending   0          10s   <none>   <none>   <none>

$ kubectl --context kind-ivolve get events --field-selector involvedObject.name=taint-demo-blocked
LAST SEEN   TYPE      REASON             OBJECT                 MESSAGE
10s         Warning   FailedScheduling   pod/taint-demo-blocked 0/3 nodes are available:
  1 node(s) didn't match Pod's node affinity/selector, 2 node(s) had untolerated taint(s).
  preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

Read the message literally — it names both halves of the lab:

- **1 node didn't match the selector** → `ivolve-worker2`, which has no
  `project=ivolve` label.
- **2 nodes had untolerated taints** → `ivolve-worker` (our `workload` taint)
  and the control plane (its own).
- **0/3** means the pod cannot be placed anywhere: the one node it asks for
  refuses it, and the others do not match.

### 5 — Add the toleration, and it schedules

`pod-allowed.yaml` is the same pod plus one toleration:

```yaml
tolerations:
  - key: workload
    operator: Equal
    value: ivolveApp
    effect: NoSchedule
```

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab10/pod-allowed.yaml
pod/taint-demo-allowed created
pod/taint-demo-allowed condition met

$ kubectl --context kind-ivolve get pods -o wide | grep -E 'taint-demo|NAME'
NAME                 READY   STATUS    RESTARTS   AGE   IP              NODE
taint-demo-allowed   1/1     Running   0          15s   192.168.194.4   ivolve-worker
taint-demo-blocked   0/1     Pending   0          25s   <none>          <none>
```

The two pods differ by exactly one field, so the result is attributable to the
toleration, not to timing or luck.

## Things worth knowing

1. **A taint repels; a label attracts.** The taint alone would have sent the pod
   anywhere else. The `nodeSelector` is what aims it at this node in the first
   place — the toleration only removes the objection.
2. **`NoSchedule` affects new pods, not running ones.** It is not an eviction
   policy; a pod already on the node keeps running. `NoExecute` is the effect
   that evicts (with an optional `tolerationSeconds`).
3. **A toleration is permission, not a request.** Adding it does not pin the pod
   to the tainted node; without the `nodeSelector` the scheduler could still
   choose `ivolve-worker2`.
4. **The API server injects default tolerations.** `kubectl get pod -o json`
   shows three, but only `workload=ivolveApp` came from the manifest; the
   `not-ready`/`unreachable` `NoExecute` ones are added by Kubernetes.
5. **The control-plane taint is why the message says 2, not 1.** kind keeps
   `node-role.kubernetes.io/control-plane:NoSchedule`, so a normal pod sees two
   tainted nodes in this cluster.
6. **`--overwrite` is the idempotency switch** for `kubectl taint` and
   `kubectl label`; without it a second run fails instead of converging.

## Cleanup

The cluster and demo pods are left in place for Labs 11–17. To undo only this
lab:

```bash
kubectl --context kind-ivolve taint nodes ivolve-worker workload=ivolveApp:NoSchedule-
kubectl --context kind-ivolve label node ivolve-worker project-
kubectl --context kind-ivolve delete pod taint-demo-blocked taint-demo-allowed
```

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab10
git commit -m "feat(lab10): node isolation with taints and labels"
```
