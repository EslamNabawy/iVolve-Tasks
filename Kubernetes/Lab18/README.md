# Lab 18 — Node-wide monitoring with a DaemonSet

**Track:** Container Orchestration · **Cluster:** kind `ivolve` ·
**Namespace:** `monitoring` · **Context:** `kind-ivolve`

> Deck Lab 18 asks for a `monitoring` namespace with Prometheus, Alertmanager,
> Grafana, and a node-exporter **DaemonSet** — one pod per node, metrics on
> `:9100`, Prometheus scraping it, and a Grafana Kubernetes dashboard.

## Requirements

- [x] `monitoring` namespace
- [x] Prometheus deployed and scraping `node-exporter`
- [x] Alertmanager deployed (default receiver)
- [x] Grafana deployed with a Prometheus datasource and a Kubernetes dashboard
- [x] node-exporter DaemonSet — **one pod on every node** (3/3)
- [x] metrics reachable at `<node_IP>:9100/metrics` on all three nodes
- [x] Prometheus shows all three targets `up`
- [x] Grafana serves the provisioned dashboard

## Results

| Check | Result |
|---|---|
| Pods | `prometheus`, `alertmanager`, `grafana` + `node-exporter` ×3 |
| DaemonSet | `3/3` — control-plane, worker, worker2 |
| `:9100/metrics` | `200` on `172.18.0.2`, `172.18.0.3`, `172.18.0.4` |
| Prometheus targets | control-plane / worker / worker2 → **`up`** |
| `up{job="node-exporter"}` | `1` for all three instances |
| Grafana | `11.2.0`, DB `ok`; datasource `Prometheus`; dashboard **Kubernetes — Nodes** (`ivolve-k8s`) |
| Alertmanager | `/-/healthy` → `OK` |

## Steps

### 1 — Namespace

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab18/namespace.yaml
namespace/monitoring created
```

### 2 — node-exporter as a DaemonSet

A DaemonSet places exactly one pod per node. `hostNetwork: true` makes the pod
share the node's network namespace, so `:9100` is the node's port, and
`tolerations: [{operator: Exists}]` is what lets it land on the tainted control
plane too:

```yaml
spec:
  template:
    spec:
      hostNetwork: true
      hostPID: true
      tolerations:
        - operator: Exists
      containers:
        - name: node-exporter
          image: prom/node-exporter:v1.8.2
          args: ["--path.procfs=/host/proc", "--path.sysfs=/host/sys", "--path.rootfs=/host"]
          ports: [{ containerPort: 9100, hostPort: 9100 }]
```

```console
$ kubectl --context kind-ivolve -n monitoring get pods -o wide
NAME                            READY   STATUS    IP           NODE
alertmanager-6d7cd8f766-7bfgg   1/1     Running   192.168.209.88   ivolve-worker2
grafana-84b4dd994b-d9r24        1/1     Running   192.168.209.89   ivolve-worker2
node-exporter-4g8kw             1/1     Running   172.18.0.3       ivolve-worker2
node-exporter-djkm8             1/1     Running   172.18.0.2       ivolve-control-plane
node-exporter-gwv69             1/1     Running   172.18.0.4       ivolve-worker
prometheus-65986c8b76-72dsw     1/1     Running   192.168.209.87   ivolve-worker2
```

Note the node-exporter pods have **node IPs** (`172.18.0.x`) — that is
`hostNetwork`.

### 3 — Metrics on the node address

```console
$ curl -s http://172.18.0.2:9100/metrics | head -3
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 1.9522e-05
```

(Same result on `.3` and `.4`.)

### 4 — Prometheus scraping it

Prometheus needs permission to list nodes, then service discovery finds them;
`role: node` yields the kubelet address `:10250`, so a relabel rewrites it to
the exporter's `:9100`:

```yaml
- job_name: node-exporter
  kubernetes_sd_configs: [{ role: node }]
  relabel_configs:
    - source_labels: [__address__]
      regex: '(.*):10250'
      replacement: '${1}:9100'
      target_label: __address__
```

```console
$ kubectl --context kind-ivolve -n monitoring port-forward svc/prometheus 9090:9090 &
$ curl -s http://127.0.0.1:9090/api/v1/targets | ...
ivolve-control-plane up http://172.18.0.2:9100/metrics
ivolve-worker up http://172.18.0.4:9100/metrics
ivolve-worker2 up http://172.18.0.3:9100/metrics

$ curl -s 'http://127.0.0.1:9090/api/v1/query?query=up%7Bjob%3D%22node-exporter%22%7D'
ivolve-worker2 = 1
ivolve-worker = 1
ivolve-control-plane = 1
```

### 5 — Alertmanager

Deployed with the minimal default route; the deck asks for the component, not
for alert rules:

```console
$ curl -s http://127.0.0.1:9094/-/healthy
OK
```

### 6 — Grafana: datasource and dashboard as code

Two provisioning mounts plus an authored dashboard JSON:

```console
$ curl -s http://127.0.0.1:3001/api/health
{ "database": "ok", "version": "11.2.0", ... }

$ curl -s -u admin:<lab-password> http://127.0.0.1:3001/api/datasources
Prometheus prometheus http://prometheus.monitoring.svc.cluster.local:9090 default= True

$ curl -s -u admin:<lab-password> 'http://127.0.0.1:3001/api/search?query=Kubernetes'
Kubernetes — Nodes | Kubernetes | ivolve-k8s
```

The dashboard (`grafana.yaml` → ConfigMap `grafana-dashboard`) has three panels:
node CPU busy %, node memory used %, and a stat of how many node-exporter
targets are up.

## Things worth knowing

1. **DaemonSets ignore the scheduler's usual placement rules per node** — they
   create one pod per matching node. Taints still apply, so the control plane
   needs `tolerations: [{operator: Exists}]` or it silently has no exporter.
2. **`hostNetwork` is what makes `<node_IP>:9100` work.** Without it the
   exporter listens on the pod IP and the node address is not a target.
3. **Kubelet is on 10250, node-exporter on 9100.** The relabel rule bridges the
   service-discovery address to the port that actually serves metrics.
4. **Grafana provisioning is files, not clicks.** Datasource, provider and
   dashboard JSON live in ConfigMaps; restarting Grafana re-reads them.
5. **Prometheus here uses `emptyDir`.** Metrics disappear if the pod is
   recreated — acceptable for the lab, but a real deployment needs a PVC (the
   Lab 13 pattern).
6. **Alertmanager is deployed, not wired to rules.** Adding real alerts means a
   rule file + `alerting` block in `prometheus.yml`; the deck only asks for the
   component.
7. **The monitoring namespace has no quota.** Lab 11's three-pod cap is scoped
   to `ivolve`, so Prometheus, Alertmanager, Grafana and three exporters fit
   without touching it.

## Cleanup

The monitoring stack stays for evidence; delete the namespace when the cluster
is torn down.

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab18
git commit -m "feat(lab18): monitoring stack with node-exporter DaemonSet"
```
