# Lab 13: Persistent storage for application logging

**Track:** Container Orchestration · **Cluster:** kind `ivolve` (Lab 9) ·
**Namespace:** `ivolve` · **Context:** `kind-ivolve`

> Deck Lab 13 asks for a 1Gi `hostPath` PersistentVolume named `ivolvePV` at
> `/mnt/app-logs`, access mode `ReadWriteMany`, reclaim policy `Retain`; a
> `ivolvePVC` claim of 1Gi with the same access mode; and **no StorageClass**.

## What it asks for

- [x] PV `ivolvepv`, 1Gi, `hostPath: /mnt/app-logs`, `ReadWriteMany`, `Retain`
- [x] PVC `ivolvepvc`, 1Gi, `ReadWriteMany`
- [x] neither object names a StorageClass (`storageClassName: ""` on both)
- [x] claim **Bound** to the volume, `1Gi` / `RWX`
- [x] data written through the claim is visible at the node path
- [x] the Lab 11 quota is restored to 3/3 after the test

## Names

The deck's `ivolvePV` / `ivolvePVC` are lowercased to **`ivolvepv`** /
**`ivolvepvc`**: Kubernetes object names are RFC 1123 subdomains, so capitals are
rejected, the same rule as Labs 11 and 12.

## Results

| Check | Result |
|---|---|
| PV | `ivolvepv`, `1Gi`, `RWX`, `Retain`, `Bound` |
| PVC | `ivolvepvc`, `Bound` to `ivolvepv`, `1Gi`, `RWX` |
| StorageClass | empty on both objects |
| Write test | pod mounted the claim at `/logs`, wrote `lab13.txt` |
| Read-back | `docker exec ivolve-worker cat /mnt/app-logs/lab13.txt` printed the same line |

## Walkthrough

### 1. Give the node the directory

A `hostPath` volume is a path on **one node**, so the directory has to exist
there. `DirectoryOrCreate` would make it on first mount; creating it explicitly
keeps the read-back test honest:

```console
$ docker exec ivolve-worker sh -c 'mkdir -p /mnt/app-logs && ls -ld /mnt/app-logs'
drwxr-xr-x 2 root root 4096 Nov  4 23:19 /mnt/app-logs
```

### 2. The PersistentVolume

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ivolvepv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /mnt/app-logs
    type: DirectoryOrCreate
```

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab13/pv.yaml
persistentvolume/ivolvepv created

$ kubectl --context kind-ivolve describe pv ivolvepv | grep -E 'Capacity|Access Modes|Reclaim Policy|StorageClass|Status'
StorageClass:
Status:          Bound
Reclaim Policy:  Retain
Access Modes:    RWX
Capacity:        1Gi
```

`storageClassName: ""` is the load-bearing line. The cluster has a default
StorageClass (`local-path`, installed by kind); a claim that omits the field
would be dynamically provisioned instead of binding to this volume, and the PV
would sit `Available` forever.

### 3. The claim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ivolvepvc
  namespace: ivolve
spec:
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
```

```console
$ kubectl --context kind-ivolve apply -f Kubernetes/Lab13/pvc.yaml
persistentvolumeclaim/ivolvepvc created

$ kubectl --context kind-ivolve get pvc ivolvepvc -n ivolve
NAME        STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
ivolvepvc   Bound    ivolvepv   1Gi        RWX                          49s
```

Bidirectional binding: the PV now shows `CLAIM ivolve/ivolvepvc`.

### 4. Prove the data really lands on the host path

`writer-pod.yaml` mounts the claim at `/logs`, writes a line, and exits. It is
pinned to `ivolve-worker` with `nodeSelector: project=ivolve` and tolerates
Lab 10's taint, exactly what Lab 14's StatefulSet will need, because the
`hostPath` only exists on that node.

```console
$ kubectl --context kind-ivolve logs log-writer -n ivolve
lab13 was here: 2026-11-04T23:20:22Z

$ kubectl --context kind-ivolve get pod log-writer -n ivolve -o wide
NAME         READY   STATUS      RESTARTS   AGE   IP              NODE
log-writer   0/1     Completed   0          2s    192.168.194.5   ivolve-worker
```

Read it from the node itself, bypassing Kubernetes:

```console
$ docker exec ivolve-worker sh -c 'ls -l /mnt/app-logs && cat /mnt/app-logs/lab13.txt'
-rw-r--r-- 1 root root 37 Nov  4 23:20 lab13.txt
lab13 was here: 2026-11-04T23:20:22Z
```

That is the whole point of the lab: the claim is backed by a real directory on
the node, and a pod's write survives the pod.

### 5. Quota housekeeping

The namespace is capped at three pods, so the writer required freeing a slot;
`quota-demo-3` was removed and re-created afterwards:

```console
$ kubectl --context kind-ivolve get resourcequota -n ivolve
NAME          REQUEST     LIMIT
ivolvequota   pods: 3/3
```

## Worth remembering

1. **`storageClassName: ""` is not the same as omitting the field.** Omitted
   means "use the default class"; `""` means "no class, bind me to a static
   PV". Getting this wrong is the classic reason a static PV stays `Available`.
2. **`hostPath` does not really implement `ReadWriteMany`.** Access modes are
   enforced by the volume plugin; `hostPath` has no multi-writer enforcement.
   The mode is a declaration that lets several pods mount it (single node), not
   a guarantee. Real RWX wants NFS/CephFS.
3. **A `hostPath` PV is tied to one node's filesystem.** If the pod lands
   elsewhere, the directory is empty or missing. Lab 14's `nodeSelector` and
   toleration are what keep MySQL on the node that owns the data.
4. **`Retain` is the safe default for data.** Deleting the claim leaves the PV
   `Released` with its contents intact instead of wiping them (`Delete` would
   remove the backing directory for dynamic volumes).
5. **Inside kind, `/mnt/app-logs` lives in the node container.** It survives
 pod restarts, not `kind delete cluster`, kind would need an `extraMounts`
   entry to put it on the Windows/WSL filesystem.
6. **The quota and the volume interact.** Nothing in the PV/PVC needs a pod
   but proving the write did; freeing a demo pod and restoring it keeps both
   labs' evidence valid.

## Cleanup

The PV and PVC stay: Lab 14 mounts this claim at `/var/lib/mysql`, and Lab 15
mounts it for logs.

## Commit

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab13
git commit -m "feat(lab13): static hostPath PV and PVC for app logs"
```
