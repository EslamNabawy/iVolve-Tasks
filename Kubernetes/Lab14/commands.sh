#!/usr/bin/env bash
# Lab 14 — MySQL StatefulSet + headless Service, verified end to end.
# Assumes Labs 9-13 state (kind-ivolve, namespace ivolve, CM/Secret).
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Kubernetes/Lab14"
CTX="--context kind-ivolve"

# 1. Free the quota: MySQL needs a slot, the Lab 11 demo pods were only proof.
kubectl $CTX delete pod quota-demo-1 quota-demo-2 quota-demo-3 -n ivolve --ignore-not-found --wait=true

# 2. Service + StatefulSet.
kubectl $CTX apply -f "$LAB/service.yaml" -f "$LAB/statefulset.yaml"
kubectl $CTX rollout status statefulset/ivolvedb -n ivolve --timeout=600s
kubectl $CTX get statefulset,svc,pods,pvc -n ivolve

# 3. Wait for mysqld to answer (Running != ready: no readiness probe).
for i in $(seq 1 60); do
  kubectl $CTX exec ivolvedb-0 -n ivolve -- sh -c 'mysqladmin ping -h127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD"' >/dev/null 2>&1 && break
  sleep 5
done
kubectl $CTX exec ivolvedb-0 -n ivolve -- sh -c 'mysqladmin ping -h127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD"'

# 4. Application user through the Service, with the database listing.
kubectl $CTX exec ivolvedb-0 -n ivolve -- sh -c 'mysql -h ivolvedbsvc -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SELECT VERSION() AS version, CURRENT_USER() AS whoami; SHOW DATABASES;"'

# 5. DNS: harness name and per-pod name.
kubectl $CTX exec ivolvedb-0 -n ivolve -- getent hosts ivolvedbsvc ivolvedb-0.ivolvedbsvc.ivolve.svc.cluster.local

# 6. Persistence: marker table survives pod recreation.
kubectl $CTX exec ivolvedb-0 -n ivolve -- sh -c 'mysql -h ivolvedbsvc -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" ivolve -e "CREATE TABLE IF NOT EXISTS lab14_marker (id INT PRIMARY KEY, note VARCHAR(40)); INSERT INTO lab14_marker VALUES (1, \"created before restart\") ON DUPLICATE KEY UPDATE note=VALUES(note);"'
kubectl $CTX delete pod ivolvedb-0 -n ivolve --wait=true
kubectl $CTX wait --for=condition=Ready pod/ivolvedb-0 -n ivolve --timeout=300s
for i in $(seq 1 60); do
  kubectl $CTX exec ivolvedb-0 -n ivolve -- sh -c 'mysqladmin ping -h127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD"' >/dev/null 2>&1 && break
  sleep 5
done
kubectl $CTX exec ivolvedb-0 -n ivolve -- sh -c 'mysql -h ivolvedbsvc -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" ivolve -e "SELECT * FROM lab14_marker;"'
