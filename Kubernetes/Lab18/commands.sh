#!/usr/bin/env bash
# Lab 18 — monitoring namespace: Prometheus, Alertmanager, Grafana, node-exporter.
set -euo pipefail
LAB="$HOME/iVolve-Tasks/Kubernetes/Lab18"
CTX="--context kind-ivolve"

# 1. Deploy everything.
kubectl $CTX apply -f "$LAB/namespace.yaml"
kubectl $CTX apply -f "$LAB/node-exporter.yaml" -f "$LAB/prometheus.yaml" -f "$LAB/alertmanager.yaml" -f "$LAB/grafana.yaml"
kubectl $CTX -n monitoring rollout status ds/node-exporter --timeout=420s
kubectl $CTX -n monitoring rollout status deploy/prometheus --timeout=420s
kubectl $CTX -n monitoring rollout status deploy/alertmanager --timeout=420s
kubectl $CTX -n monitoring rollout status deploy/grafana --timeout=420s
kubectl $CTX -n monitoring get pods -o wide

# 2. One exporter per node, on the node IP.
for ip in $(kubectl $CTX get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'); do
  echo "--- $ip:9100/metrics"
  curl -s --max-time 5 "http://$ip:9100/metrics" | head -3
done

# 3. Prometheus sees them up.
kubectl $CTX -n monitoring port-forward svc/prometheus 9090:9090 >/tmp/pf-prom.log 2>&1 &
P1=$!
kubectl $CTX -n monitoring port-forward svc/grafana 3001:3000 >/tmp/pf-graf.log 2>&1 &
P2=$!
kubectl $CTX -n monitoring port-forward svc/alertmanager 9094:9093 >/tmp/pf-alert.log 2>&1 &
P3=$!
sleep 4

curl -s http://127.0.0.1:9090/api/v1/targets | python3 -c '
import sys, json
for t in json.load(sys.stdin)["data"]["activeTargets"]:
    if t["labels"].get("job") == "node-exporter":
        print(t["labels"].get("instance"), t["health"], t["scrapeUrl"])
'
curl -s http://127.0.0.1:9090/api/v1/alertmanagers >/dev/null || true

# 4. Grafana provisioning and Alertmanager health.
curl -s http://127.0.0.1:3001/api/health; echo
curl -s -u admin:ivolveadmin http://127.0.0.1:3001/api/datasources | python3 -c '
import sys, json
for d in json.load(sys.stdin):
    print(d["name"], d["type"], d["url"], "default=", d.get("isDefault"))
'
curl -s -u admin:ivolveadmin 'http://127.0.0.1:3001/api/search?query=Kubernetes' | python3 -c '
import sys, json
for d in json.load(sys.stdin):
    print(d.get("title"), "|", d.get("folderTitle"), "|", d.get("uid"))
'
curl -s http://127.0.0.1:9094/-/healthy; echo

kill $P1 $P2 $P3 2>/dev/null || true
