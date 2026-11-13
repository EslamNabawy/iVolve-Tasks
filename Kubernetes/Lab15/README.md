# Lab 15: Node.js app Deployment and ClusterIP Service

**Track:** Container Orchestration · **Cluster:** kind `ivolve` (Lab 9) ·
**Namespace:** `ivolve` · **Context:** `kind-ivolve`

> Deck Lab 15 asks for an `ivolveApp` Deployment (2 replicas), the app image
> environment from the Lab 12 ConfigMap/Secret, the Lab 13 volume for logs, an
> init container that prepares the database and grants, a ClusterIP Service
> `ivolvaAppSvc`, and proof that the app reaches MySQL and serves traffic.

## One deviation, stated up front

The slide says "use your custom Docker image from Docker Hub created in Lab 8".
Deck Lab 8 was not run in this repository, and this session has **no Docker Hub
credentials**, so the image is built locally from the upstream app and loaded
into kind:

```console
$ docker build -t ivolveapp:lab15 ~/labs-workspace/iVolveApp
$ kind load docker-image ivolveapp:lab15 --name ivolve
```

The Deployment sets `imagePullPolicy: IfNotPresent`, so the loaded image is
used. Everything else, the init container, the ConfigMap/Secret wiring, the
volume, the Service, is exactly what the lab asks. The source lives in
`~/labs-workspace/iVolveApp` (cloned upstream, not committed), per this repo's
rule that only authored files enter git.

## What the lab asks for

- [x] Deployment `ivolveapp`, 2 replicas on `ivolve-worker`
- [x] env from `ivolvecm` (`DB_HOST`, `DB_USER`) and `ivolvesecret`
      (`DB_PASSWORD`), plus `DB_NAME=ivolve`
- [x] Lab 13 PV mounted at `/app/logs`
- [x] init container (`mysql:8.4`) waits for MySQL, creates `ivolve`, grants
- [x] ClusterIP Service `ivolvaappsvc` on 3000
- [x] app logs show a successful MySQL connection
- [x] `/health` and `/ready` answer through the Service
- [x] grants verified with `SHOW GRANTS`
- [x] `access.log` appears on the node's `/mnt/app-logs`

## The run

| Check | Result |
|---|---|
| Pods | `ivolveapp-…-26xbf`, `ivolveapp-…-bs8fc`, `2/2 Running` on `ivolve-worker` |
| Quota | **3/3** (MySQL + two app replicas, exactly the Lab 11 cap) |
| Init container | `mysqld is alive` → `ivolve database and grants ready` |
| App log | `✅ Connected to MySQL and 'ivolve' DB found.` / `🚀 Server started on http://0.0.0.0:3000` |
| `/health` | `🚀 iVolve web app is working! ...` |
| `/ready` | `👍 iVolve web app is ready to rock and roll! 🤘` |
| Grants | `GRANT ALL PRIVILEGES ON \`ivolve\`.* TO \`ivolveapp\`@\`%\`` |
| Logs volume | `/mnt/app-logs/access.log` on `ivolve-worker`, written by morgan |

## Steps

### 1. Init container: prepare the database

MySQL's entrypoint already creates `ivolve` and the app user, but the lab asks
for an explicit init container, and it makes the pod self-sufficient:

```yaml
initContainers:
  - name: init-db
    image: mysql:8.4
    command:
      - sh
      - -c
      - |
        until mysqladmin ping -h "$DB_HOST" -uroot -p"$MYSQL_ROOT_PASSWORD" --silent; do
          echo "waiting for mysql at $DB_HOST"; sleep 3
        done
        mysql -h "$DB_HOST" -uroot -p"$MYSQL_ROOT_PASSWORD" -e \
          "CREATE DATABASE IF NOT EXISTS ivolve; GRANT ALL PRIVILEGES ON ivolve.* TO '$DB_USER'@'%'; FLUSH PRIVILEGES;"
        echo "ivolve database and grants ready"
```

Its environment comes from the same ConfigMap and Secret as the app, the
requirements are passed, not hard-coded:

```console
$ kubectl --context kind-ivolve -n ivolve logs <pod> -c init-db
mysqld is alive
ivolve database and grants ready
```

### 2. The Deployment

Two replicas, pinned to the Lab 10 node, tolerating its taint, with the Lab 13
claim mounted where the app writes its access log:

```yaml
nodeSelector: { project: ivolve }
tolerations:
  - { key: workload, operator: Equal, value: ivolveApp, effect: NoSchedule }
volumes:
  - name: app-logs
    persistentVolumeClaim: { claimName: ivolvepvc }
```

```console
$ kubectl --context kind-ivolve get deployment,svc,pods -n ivolve -o wide
NAME                       READY   UP-TO-DATE   AVAILABLE   IMAGES
deployment.apps/ivolveapp  2/2     2            2           ivolveapp:lab15

NAME                   TYPE        CLUSTER-IP    PORT(S)
service/ivolvaappsvc   ClusterIP   10.96.196.1   3000/TCP
service/ivolvedbsvc    ClusterIP   None          3306/TCP

NAME                           READY   STATUS    NODE
pod/ivolveapp-685887fc-26xbf   1/1     Running   ivolve-worker
pod/ivolveapp-685887fc-bs8fc   1/1     Running   ivolve-worker
pod/ivolvedb-0                 1/1     Running   ivolve-worker
```

### 3. The Service answers

Port-forwarding the ClusterIP for a local check:

```console
$ kubectl --context kind-ivolve -n ivolve port-forward svc/ivolvaappsvc 3000:3000
$ curl -s http://127.0.0.1:3000/health
🚀 iVolve web app is working! Keep calm and code on! 🎉

$ curl -s http://127.0.0.1:3000/ready
👍 iVolve web app is ready to rock and roll! 🤘

$ curl -s http://127.0.0.1:3000/ | grep -o '<title>[^<]*</title>'
<title>iVolve | Global Cloud Company</title>
```

Both endpoints run `SELECT 1` against MySQL, so a 200 is a real end-to-end
check from HTTP to the database.

### 4. The connection and the grants

```console
$ kubectl --context kind-ivolve -n ivolve logs <pod> --tail=12
🔄 Attempting to connect to MySQL...
✅ Connected to MySQL and 'ivolve' DB found.
🚀 Server started on http://0.0.0.0:3000

$ kubectl --context kind-ivolve exec ivolvedb-0 -n ivolve -- sh -c \
    'mysql -h ivolvedbsvc -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW GRANTS FOR \"ivolveapp\"@\"%\";"'
Grants for ivolveapp@%
GRANT USAGE ON *.* TO `ivolveapp`@`%`
GRANT ALL PRIVILEGES ON `ivolve`.* TO `ivolveapp`@`%`
```

### 5. Logs really go to the Lab 13 volume

```console
$ docker exec ivolve-worker sh -c 'ls -l /mnt/app-logs && tail -3 /mnt/app-logs/access.log'
-rw-r--r-- 1 root root 355 Nov  4 23:47 access.log
-rw-r--r-- 1 root root  37 Nov  4 23:20 lab13.txt
127.0.0.1 - - [04/Nov/2026:23:47:30 +0000] "GET /health HTTP/1.1" 200 59 "-" "curl/8.5.0"
127.0.0.1 - - [04/Nov/2026:23:47:30 +0000] "GET /ready HTTP/1.1" 200 51 "-" "curl/8.5.0"
127.0.0.1 - - [04/Nov/2026:23:47:30 +0000] "GET / HTTP/1.1" 200 2769 "-" "curl/8.5.0"
```

## Loose ends

1. **Init and app containers share the pod's labels.** NetworkPolicy (Lab 17)
   keys on `app=ivolveapp`, and the init container inherits it, so the DB
   preparation keeps working after the policy lands.
2. **Two replicas, one hostPath.** Lab 13's PV is declared `RWX`; both replicas
   sit on the same node, so both append to the same `access.log`. On a real
   multi-node RWX volume this is the intended behaviour; on hostPath it is a
   single-node convenience.
3. **`imagePullPolicy: IfNotPresent` is required for kind-loaded images.**
   With `Always`, kubelet would try Docker Hub and fail.
4. **The quota is exactly saturated.** MySQL (1) + app (2) = 3/3. Anything else
 in the namespace, even a debug pod, needs a slot or a quota change.
5. **`/health` is a database check, not a process check.** The app returns 200
   only after `SELECT 1` succeeds, which is why it is a meaningful probe.

## Cleanup

The Deployment, Service and pods stay for Labs 16–17.

## Putting it in git

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab15
git commit -m "feat(lab15): Node app Deployment with ClusterIP Service"
```
