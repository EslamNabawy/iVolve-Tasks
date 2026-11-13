# Lab 14: MySQL StatefulSet with a headless Service

**Track:** Container Orchestration · **Cluster:** kind `ivolve` (Lab 9) ·
**Namespace:** `ivolve` · **Context:** `kind-ivolve`

> Deck Lab 14 asks for an `ivolveDB` StatefulSet (1 replica, MySQL) that consumes
> the ConfigMap and Secret from Lab 12, runs on the labelled `ivolve-worker`
> (nodeSelector `project=ivolve`, toleration `workload=ivolveApp:NoSchedule`)
> keeps `/var/lib/mysql` on a `volumeClaimTemplate`, and is reached through a
> headless Service `ivolveDBSvc`. Confirm the database works and that its DNS
> name resolves.

## The ask

- [x] StatefulSet `ivolvedb`, 1 replica, MySQL 8.4.13
- [x] env from `ivolvecm` (`DB_HOST`, `DB_USER`) and `ivolvesecret`
      (`MYSQL_ROOT_PASSWORD`, `DB_PASSWORD`)
- [x] `nodeSelector: project=ivolve` + toleration for the Lab 10 taint
- [x] `volumeClaimTemplates` mounted at `/var/lib/mysql`
- [x] headless Service `ivolvedbsvc` (`clusterIP: None`) on 3306
- [x] `mysqladmin ping` → **mysqld is alive**
- [x] app user connects through the Service; `ivolve` database exists
- [x] `ivolvedbsvc` and `ivolvedb-0.ivolvedbsvc...` resolve in-cluster
- [x] data survives deleting the pod (same claim, same name)

## Names

`ivolveDB` → **`ivolvedb`**, `ivolveDBSvc` → **`ivolvedbsvc`**: object names are
lowercase RFC 1123 subdomains, so the deck's capitals cannot be stored.

## How it went

| Check | Result |
|---|---|
| Pod | `ivolvedb-0`, `Running` on `ivolve-worker` |
| MySQL | `8.4.13`, `mysqld is alive` on 3306 |
| App login via Service | `ivolveapp@%`, `SHOW DATABASES` lists **`ivolve`** |
| Headless DNS | `ivolvedbsvc` and `ivolvedb-0.ivolvedbsvc.ivolve.svc.cluster.local` → pod IP |
| Data claim | `data-ivolvedb-0`, `Bound`, 1Gi, `RWO` (dynamic `standard` class) |
| Persistence | marker row written, pod deleted, row still there afterwards |
| Quota | 1/3 used by MySQL |

## Step by step

### 1. Headless Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ivolvedbsvc
  namespace: ivolve
    spec:
  clusterIP: None          # headless: DNS returns pod IPs, not a VIP
  selector:
    app: ivolvedb
  ports:
    - name: mysql
      port: 3306
      targetPort: 3306
```

A StatefulSet needs a headless Service to give each replica a stable DNS name
(`ivolvedb-0.ivolvedbsvc...`). With a normal ClusterIP the name would resolve to
the Service, not to the pod.

### 2. StatefulSet

The pod consumes Lab 12's objects directly:

```yaml
env:
  - name: MYSQL_DATABASE
    value: ivolve
  - name: MYSQL_ROOT_PASSWORD
    valueFrom:
      secretKeyRef: { name: ivolvesecret, key: MYSQL_ROOT_PASSWORD }
  - name: MYSQL_USER
    valueFrom:
      configMapKeyRef: { name: ivolvecm, key: DB_USER }
  - name: MYSQL_PASSWORD
    valueFrom:
      secretKeyRef: { name: ivolvesecret, key: DB_PASSWORD }
  - name: DB_HOST
    valueFrom:
      configMapKeyRef: { name: ivolvecm, key: DB_HOST }
```

and is pinned to the node Lab 10 marked:

```yaml
nodeSelector:
  project: ivolve
tolerations:
  - key: workload
    operator: Equal
    value: ivolveApp
    effect: NoSchedule
```

The data volume comes from the StatefulSet itself:

```yaml
volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 1Gi
```

No `storageClassName` here on purpose: MySQL's data uses kind's default dynamic
class (`standard`), while **Lab 13's classless hostPath PV stays reserved for
application logs**, which Lab 15 mounts. Mixing them would have failed, a
template claim cannot bind a PV that is already bound to `ivolvepvc`.

### 3. Deploy and wait for initdb

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab14/service.yaml -f Kubernetes/Lab14/statefulset.yaml
service/ivolvedbsvc created
statefulset.apps/ivolvedb created
partitioned roll out complete: 1 new pods have been updated...

$ kubectl --context kind-ivolve -n ivolve get pods,pvc
NAME             READY   STATUS    AGE
pod/ivolvedb-0   1/1     Running   0   6s

NAME                                    STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS
persistentvolumeclaim/data-ivolvedb-0   Bound    pvc-...   1Gi        RWO            standard
persistentvolumeclaim/ivolvepvc         Bound    ivolvepv  1Gi        RWX
```

### 4. The database answers

The MySQL image has no readiness probe, so `Running` means "container started"
not "server ready". The check has to be a real connection:

```console
$ kubectl --context kind-ivolve exec ivolvedb-0 -n ivolve -- sh -c \
    'mysqladmin ping -h127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD"'
mysqld is alive
```

Connecting as the application user **through the headless Service name**:

```console
$ kubectl --context kind-ivolve exec ivolvedb-0 -n ivolve -- sh -c \
    'mysql -h ivolvedbsvc -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" \
     -e "SELECT VERSION() AS version, DATABASE() AS db, CURRENT_USER() AS whoami;"'
version   db     whoami
8.4.13    NULL   ivolveapp@%

$ kubectl --context kind-ivolve exec ivolvedb-0 -n ivolve -- sh -c \
    'mysql -h ivolvedbsvc -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;"'
Database
information_schema
ivolve
performance_schema
```

The password is expanded from the pod's own environment, the value never
appears in the command or this README.

### 5. DNS

Inside the pod:

```console
$ kubectl --context kind-ivolve exec ivolvedb-0 -n ivolve -- \
    getent hosts ivolvedbsvc ivolvedb-0.ivolvedbsvc.ivolve.svc.cluster.local
192.168.194.16  ivolvedbsvc.ivolve.svc.cluster.local
192.168.194.16  ivolvedb-0.ivolvedbsvc.ivolve.svc.cluster.local ivolvedb-0
```

From an unrelated pod:

```console
$ kubectl --context kind-ivolve run dns-check -n ivolve --image=busybox:1.36 \
    --restart=Never --command -- nslookup ivolvedbsvc.ivolve.svc.cluster.local
Server:   10.96.0.10
Name:     ivolvedbsvc.ivolve.svc.cluster.local
Address:  192.168.194.16
```

### 6. Identity and data survive a pod restart

```console
$ ... mysql ... -e "CREATE TABLE lab14_marker (id INT PRIMARY KEY, note VARCHAR(40)); INSERT INTO lab14_marker VALUES (1,'created before restart');"
id  note
1   created before restart

$ kubectl --context kind-ivolve delete pod ivolvedb-0 -n ivolve
pod "ivolvedb-0" deleted from ivolve namespace

$ kubectl --context kind-ivolve get pod ivolvedb-0 -n ivolve -o wide
NAME         READY   STATUS    AGE   IP
ivolvedb-0   1/1     Running   0     6s    192.168.194.17

$ ... mysql ... -e "SELECT * FROM lab14_marker;"
id  note
1   created before restart
```

Same pod name, new IP, same claim, same row. That is the StatefulSet contract:

## An incident worth recording

The first deployment did not survive, the Windows host filled its disk during
the MySQL image pull (C: went to 1.7 GB free), WSL returned
`Input/output error` on reads, and MySQL's data directory ended up only
half-initialised. The symptom was precise: `mysqld` ran, but logins returned
`Host '...' is not allowed to connect`, because the entrypoint had skipped user
creation on a non-empty datadir.

Recovery: `wsl --shutdown` released the dynamic VHD's working space (13.3 GB
free again), then the claim `data-ivolvedb-0` was deleted and the StatefulSet
scaled down/up so `initdb` ran cleanly with the same ConfigMap/Secret. Every
result above is from that clean run.

## Gotchas

1. **StatefulSet DNS is per-pod.** `ivolvedb-0.ivolvedbsvc.ivolve.svc.cluster.local`
   is stable; the pod IP is not. Clients should use the Service name.
2. **Headless ≠ ClusterIP.** `clusterIP: None` makes DNS return the pod
   addresses, which is what StatefulSets and per-pod discovery need.
3. **`Running` is not `ready` without a probe.** The MySQL image ships no
 readiness probe, so a TCP/`mysqladmin` check is the honest readiness test 
   and a readiness probe is worth adding in real deployments.
4. **The template claim is named `<template>-<statefulset>-<ordinal>`**:
   `data-ivolvedb-0`. Deleting the pod keeps the claim; deleting the claim
   wipes the data (reclaim policy of the dynamic class is `Delete`).
5. **Ordinals and identity survive restarts.** The recreated pod is still
   `ivolvedb-0` and still mounts the same claim.
6. **The Lab 13 PV is for logs, not for MySQL.** Two different storage paths
   on purpose: static classless PV for app logs, dynamic template claim for
   database state.
7. **Disk space is part of the lab.** A full host disk broke WSL I/O and
   half-initialised MySQL; `df` and the host's free space belong in the
   checklist before a stateful workload.

## Teardown

The StatefulSet, Service and claim stay: Lab 15 runs the Node app against this
database and mounts Lab 13's PV for logs.

## The commit

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab14
git commit -m "feat(lab14): MySQL StatefulSet with headless Service"
```
