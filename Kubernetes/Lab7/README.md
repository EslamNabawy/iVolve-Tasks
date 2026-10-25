# Lab 7 — Deploying the Lab 3 image to Kubernetes

**Track:** Kubernetes · **Cluster tool:** kind v0.33.0 · **Client:** kubectl v1.37.1 · **Image:** `app3`, Lab 3's multi-stage build

> This track has no slide photo — it is the first item on this repository's
> own **Next** list: *"☸️ Kubernetes — deploy the Lab 3 image to a cluster."*
> Everything below was executed on this machine; nothing is copied from a
> tutorial. Two kind clusters can exist here (`aiops` belongs to an unrelated
> project), so every `kubectl` call pins `--context kind-ivolve` and every
> `kind` call passes `--name ivolve` — the other cluster is never touched.

## Requirements

- [x] kind cluster created with one control-plane node
- [x] The Lab 3 image (`app3`) rebuilt and **loaded** into the cluster
- [x] A Deployment runs the image; pod reaches `1/1 Running`
- [x] The calculator computes **inside** the pod (`kubectl exec -i`)
- [x] Non-root proven inside the pod (`uid=1000(appuser)`)
- [x] CPU/memory requests and limits declared on the container
- [x] The stdin trap demonstrated honestly — default ENTRYPOINT → crash loop
- [x] `EXPOSE 8080` re-checked through a Service → `Connection refused`
- [x] Cluster and image cleaned up; the unrelated `aiops` cluster untouched

## Results

| Check | Result |
|---|---|
| Cluster | `ivolve` — 1 control-plane node, **Ready after 16 s** |
| Image | `app3` **256 MB**, `kind load docker-image` (never pulled from a registry) |
| Pod | `calculator-5565b9c99d-bgx5n` · `1/1 Running` · `uid=1000(appuser)` |
| Math in-cluster | 7 and 3 → Sum **10.0** · Subtract **4.0** · Multiply **21.0** · Divide **2.3333333333333335** |
| Deployed as-is | `0/1 Error`, **4 restarts**, `NoSuchElementException` |
| Resources | requests `100m / 128Mi` · limits `500m / 256Mi` |
| Service `:8080` | endpoint `10.244.0.7:8080` exists → **Connection refused** |
| Cleanup | cluster deleted, `app3` removed, `aiops` cluster still listed |

## Steps

### 1 — Rebuild the Lab 3 image

Lab 3's cleanup deleted `app3`, so it is rebuilt first. The build context must
be the upstream clone in `~/labs-workspace/` (outside this repo — the repo
holds only authored files). Building from inside the repo folder is the first
trap:

```console
$ cd ~/iVolve-Tasks/Docker/Lab3 && docker build -f Dockerfile.multistage -t app3 .
ERROR: failed to build: failed to solve: ... "/pom.xml": not found
```

With the correct context — same clone Labs 1–2 used, same Dockerfile
(byte-identical to [`Docker/Lab3/Dockerfile.multistage`](../../Docker/Lab3/Dockerfile.multistage)):

```console
$ cd ~/labs-workspace/CalculatorMavenApp
$ docker build -f Dockerfile.multistage -t app3 .
...
#16 exporting manifest list sha256:87fdd2ae486ae15de52023f5bb43c110259b69c61fc1bbe33cd618b60c33d009
#16 exporting manifest list sha256:87fdd2ae486ae15de52023f5bb43c110259b69c61fc1bbe33cd618b60c33d009 0.0s done
#16 naming to docker.io/library/app3:latest done
#16 unpacking to docker.io/library/app3:latest 0.1s done
#16 DONE 0.6s

$ docker images app3 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
app3:latest 256MB
```

(The cached layers made it a sub-second rebuild. Lab 3 recorded 265 MB on
21 Oct; this run printed 256 MB — the number of the run in front of us is
the one reported here, not the older figure.)

### 2 — Create the cluster

```console
$ kind create cluster --name ivolve --wait 120s
Creating cluster "ivolve" ...
 • Ensuring node image (kindest/node:v1.37.0) 🖼️  ...
 ✓ Ensuring node image (kindest/node:v1.37.0) 🖼️
 • Preparing nodes 📦   ...
 ✓ Preparing nodes 📦
 • Writing configuration 📜  ...
 ✓ Writing configuration 📜
 • Starting control-plane 🕹️  ...
 ✓ Starting control-plane 🕹️
 • Installing CNI 🔌  ...
 ✓ Installing CNI 🔌
 • Installing StorageClass 💾  ...
 ✓ Installing StorageClass 💾
 • Waiting ≤ 2m0s for control-plane = Ready ⏳  ...
 ✓ Waiting ≤ 2m0s for control-plane = Ready ⏳
 ✓ Ready after 16s 💚
Set kubectl context to "kind-ivolve"
```

The node image was already on disk (the `aiops` cluster uses the same
`kindest/node:v1.37.0`), so nothing was pulled.

```console
$ kubectl --context kind-ivolve get nodes -o wide
NAME                   STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                              CONTAINER-RUNTIME
ivolve-control-plane   Ready    control-plane   52s   v1.37.0   172.18.0.2    <none>        Debian GNU/Linux 13 (trixie)   6.18.33.2-microsoft-standard-WSL2 (amd64)   containerd://2.3.4
```

One node, `Ready`, Kubernetes v1.37.0 on the WSL2 kernel.

### 3 — Load the image into the node

The node is a container running **containerd**, not the host's Docker
daemon — images `docker` knows about are invisible to it, and `app3` does
not exist in any registry:

```console
$ kind load docker-image app3 --name ivolve
Image: "app3" with ID "sha256:87fdd2ae486ae15de52023f5bb43c110259b69c61fc1bbe33cd618b60c33d009" not yet present on node "ivolve-control-plane", loading...
```

### 4 — First contact: one interactive pod

`kubectl run -i` with piped stdin is `docker run -i` in Kubernetes form:

```console
$ printf '10\n5\n' | kubectl --context kind-ivolve run calc-quick --rm -i --restart=Never \
    --image=app3 --image-pull-policy=Never
Enter first number: Enter second number: a = 10.0, b = 5.0
Sum: 15.0
Subtract: 5.0
Multiply: 50.0
Divide: 2.0
pod "calc-quick" deleted from default namespace
```

Same math Lab 3 produced with `docker run -i`, now inside a cluster pod.
Note `--image-pull-policy=Never`: the image was loaded, never pushed, so a
pull attempt can never succeed — saying so explicitly beats hoping the
default behaves.

### 5 — Deploy it as-is and watch it fail

The honest negative test. What happens if a Deployment simply uses the
image, exactly like `docker run` does?

```console
$ kubectl --context kind-ivolve run calc-asis --image=app3 --image-pull-policy=Never
pod/calc-asis created

$ sleep 10; kubectl --context kind-ivolve get pod calc-asis
NAME        READY   STATUS   RESTARTS     AGE
calc-asis   0/1     Error    1 (9s ago)   10s

$ kubectl --context kind-ivolve logs calc-asis --all-containers | head -10
Exception in thread "main" java.util.NoSuchElementException
	at java.base/java.util.Scanner.throwFor(Unknown Source)
	at java.base/java.util.Scanner.next(Unknown Source)
	at java.base/java.util.Scanner.nextDouble(Unknown Source)
	at com.example.calculator.Main.main(Main.java:12)
Enter first number:
```

The pod gives the process stdin connected to nothing; the calculator dies
inside its first second, and kubelet keeps restarting it:

```console
$ kubectl --context kind-ivolve describe pod calc-asis | tail -12
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  11s               default-scheduler  Successfully assigned default/calc-asis to ivolve-control-plane
  Normal   Pulled     9s (x2 over 10s)  kubelet            spec.containers{calc-asis}: Container image "app3" already present on machine and can be accessed by the pod
  Normal   Created    9s (x2 over 10s)  kubelet            spec.containers{calc-asis}: Container created
  Normal   Started    9s (x2 over 10s)  kubelet            spec.containers{calc-asis}: Container started
  Warning  BackOff    8s                kubelet            spec.containers{calc-asis}: Back-off restarting failed container calc-asis in pod calc-asis_default(73c86839-ddca-49de-89b2-36f7e6c5d4b0)
```

Lab 3's trap — *"the app is an interactive stdin CLI"* — did not disappear
because we moved to Kubernetes. A container orchestrator schedules
containers; it cannot type numbers into them.

### 6 — The pattern that works

[`deployment.yaml`](deployment.yaml) keeps the pod alive with a different
main process, and the calculator is invoked *inside* that pod on demand:

```console
$ kubectl --context kind-ivolve apply -f deployment.yaml
deployment.apps/calculator created

$ kubectl --context kind-ivolve rollout status deploy/calculator --timeout=60s
Waiting for deployment "calculator" rollout to finish: 0 of 1 updated replicas are available...
deployment "calculator" successfully rolled out

$ kubectl --context kind-ivolve get deploy,po -l app=calculator
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/calculator   1/1     1            1           1s

NAME                              READY   STATUS    RESTARTS   AGE
pod/calculator-5565b9c99d-bgx5n   1/1     Running   0          1s
```

### 7 — The calculator, inside the cluster

`kubectl exec -i` opens a stream straight into the container — the same
contract as `docker run -i`:

```console
$ printf '7\n3\n' | kubectl --context kind-ivolve exec -i deploy/calculator -- java -jar /app/calculator.jar
Enter first number: Enter second number: a = 7.0, b = 3.0
Sum: 10.0
Subtract: 4.0
Multiply: 21.0
Divide: 2.3333333333333335
```

Different inputs than step 4 (7 and 3, as Lab 3 used) — it computes, it
does not echo.

### 8 — Non-root, and the declared resources

```console
$ kubectl --context kind-ivolve exec deploy/calculator -- id
uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)

$ kubectl --context kind-ivolve get pod -l app=calculator -o yaml | grep -E 'runAsUser|runAsGroup|runAsNonRoot'
      runAsGroup: 1000
      runAsNonRoot: true
      runAsUser: 1000

$ kubectl --context kind-ivolve describe pod -l app=calculator | grep -E 'Image:|runAs|cpu|memory|Limits|Requests'
    Image:         app3
    Limits:
      cpu:     500m
      memory:  256Mi
    Requests:
      cpu:        100m
      memory:     128Mi
```

The manifest's numbers reached the API server, and the process really runs
as `appuser` — the same non-root guarantee Labs 3–6 established, now
enforced by the scheduler instead of a `docker run` flag.

### 9 — The Service that has nothing to serve

Lab 3 proved `EXPOSE 8080` opens no socket. Kubernetes deserves the same
check — [`service.yaml`](service.yaml) declares port 8080 anyway:

```console
$ kubectl --context kind-ivolve apply -f service.yaml
service/calculator created
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice

$ kubectl --context kind-ivolve get svc,endpoints calculator
NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/calculator   ClusterIP   10.96.45.220   <none>        8080/TCP   0s

NAME                   ENDPOINTS         AGE
endpoints/calculator   10.244.0.7:8080   0s

$ kubectl --context kind-ivolve exec deploy/calculator -- wget -T3 -O- http://calculator:8080/
Connecting to calculator:8080 (10.96.45.220:8080)
wget: can't connect to remote host (10.96.45.220): Connection refused
command terminated with exit code 1
```

The endpoint exists — kube-proxy tracks the **pod**, not open sockets — and
the connection is still refused, because nothing in that container ever
listens. `EXPOSE` remains documentation; a Service routes to a socket that
must actually exist.

### 10 — Full picture, then tidy up

Both pods side by side — the image deployed the wrong way and the right
way:

```console
$ kubectl --context kind-ivolve get deploy,po,svc
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES   SELECTOR
deployment.apps/calculator   1/1     1            1           51s   calculator   app3     app=calculator

NAME                              READY   STATUS    RESTARTS      AGE   IP           NODE                   NOMINATED NODE   READINESS GATES
pod/calc-asis                     0/1     Error     4 (58s ago)   101s  10.244.0.6   ivolve-control-plane   <none>           <none>
pod/calculator-5565b9c99d-bgx5n   1/1     Running   0             51s   10.244.0.7   ivolve-control-plane   <none>           <none>

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE     SELECTOR
service/calculator   ClusterIP   10.96.45.220   <none>        8080/TCP   13s     app=calculator
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP    2m53s   <none>
```

The crashed pod has restarted 4 times and will do so forever — deleted.
Two honest gaps worth recording while the cluster is up:

```console
$ kubectl --context kind-ivolve top pod
error: Metrics API not available

$ kubectl --context kind-ivolve logs deploy/calculator | wc -c
0
```

kind ships no metrics-server, so `kubectl top` has no Lab 6 `docker stats`
twin here. And the deployment's own logs are empty by design: PID 1 is
`sleep`, while the calculator's output belonged to the `exec` session.

```console
$ kubectl --context kind-ivolve delete pod calc-asis --wait=false
pod "calc-asis" deleted from default namespace
```

### 11 — Cleanup

```console
$ kind delete cluster --name ivolve
Deleting cluster "ivolve" ...
Deleted nodes: ["ivolve-control-plane"]

$ docker rmi app3
Untagged: app3:latest
Deleted: sha256:87fdd2ae486ae15de52023f5bb43c110259b69c61fc1bbe33cd618b60c33d009

$ kind get clusters
aiops

$ docker ps -a --format '{{.Names}}\t{{.Status}}' | grep -E 'control-plane|aiops|ivolve'
aiops-platform-api-1	Restarting (3) 7 seconds ago
aiops-platform-postgres-1	Exited (127) 13 days ago
aiops-platform-redis-1	Up About an hour (healthy)
aiops-platform-mesh-1	Up About an hour (healthy)
aiops-db	Exited (0) 11 days ago
aiops-control-plane	Exited (137) 11 days ago
```

The `ivolve` cluster and `app3` are gone; every `aiops-*` container is in
exactly the state it was in before this lab (`aiops-control-plane` still
`Exited (137) 11 days ago`).

## Why this lab looks different from every Docker lab

**Docker arguments and Kubernetes `command:` are not the same switch.**
While designing this lab I fed the image `sleep infinity` from the Docker
CLI, expecting a sleeping container:

```console
$ docker run --name sleeptest2 app3 sleep infinity
Enter first number: Exception in thread "main" java.util.NoSuchElementException
	at java.base/java.util.Scanner.throwFor(Unknown Source)
	at java.base/java.util.Scanner.next(Unknown Source)
	at java.base/java.util.Scanner.nextDouble(Unknown Source)
	at com.example.calculator.Main.main(Main.java:12)
```

The arguments never ran: `docker run`'s trailing words replace the image's
**CMD**, and this image sets an **ENTRYPOINT** (`java -jar …`) — so Java ran
instead, found no stdin, and died. Overriding the entrypoint explicitly
does work, and Alpine's `sleep` accepts `infinity`:

```console
$ docker run -d --name sleeptest3 --entrypoint sleep app3 infinity
0676c3419fb9428f838ec9b0c4550f10fa723911883394ed264cf269b26337e6

$ docker ps --filter name=sleeptest3 --format '{{.Names}} {{.Status}}'
sleeptest3 Up 3 seconds
```

Kubernetes' `command:` field is the `--entrypoint` equivalent — it
overrides the ENTRYPOINT, which is exactly what `deployment.yaml` does. So
the working shape of this lab is: **the pod's process keeps the container
alive; the calculator runs on `kubectl exec -i`.** Scaling `replicas` would
only produce more idle pods — a stdin CLI has no notion of concurrent
capacity to scale.

## Things worth knowing

1. **`imagePullPolicy: Never` is load-bearing.** kind nodes run containerd
   and never see the host Docker daemon's images; `kind load docker-image`
   is the bridge. The manifest pins the policy because the tag is
   `app3:latest`, whose Kubernetes default is `Always` — a pull that could
   only fail, since no registry on earth has `app3`.
2. **`runAsNonRoot` needs a number, not a name.** The Dockerfile says
   `USER appuser`. Kubernetes cannot resolve that name to a uid at admission
   time and would reject the pod ("image will run as root"), so the
   manifest states `runAsUser: 1000` — the uid `adduser -D` gave appuser,
   verified by `id` in step 8.
3. **`exec` output never reaches `kubectl logs`.** Logs capture PID 1 only;
   the calculator's answer belonged to the exec stream. That is why step 10
   shows `0` bytes of logs on a "successful" deployment.
4. **Endpoints ≠ open sockets.** The Service's endpoint was populated
   (`10.244.0.7:8080`) while the port refused connections — kube-proxy
   watches pod readiness, not listeners. Lab 3's `EXPOSE` lesson, restated
   by a different control plane.
5. **`kubectl top` needs metrics-server** — kind deliberately ships a bare
   cluster (`error: Metrics API not available`). Lab 6's `docker stats`
   observation has no default equivalent here.
6. **The `Endpoints` deprecation warning** in step 9 is Kubernetes telling
   us `kubectl get endpoints` is legacy UI on v1.33+; `EndpointSlice` is
   the backing object now. Cosmetic, kept in the output rather than edited
   out.
7. **Size honesty:** this rebuild printed `app3:latest 256MB`, Lab 3's
   table says 265 MB. The cause was not investigated (floating base tags
   and measurement timing are candidates); the figure each run actually
   printed is the one reported.

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab7
git commit -m "feat(lab7): deploy the Lab 3 image to Kubernetes with kind"
```
