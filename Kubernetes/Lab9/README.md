# Lab 9 — A three-node Kubernetes cluster with Calico

**Track:** Container Orchestration · **Cluster:** kind v0.33.0 / Kubernetes v1.37.0 ·
**CNI:** Calico v3.33.0 · **Context:** `kind-ivolve`

> Deck Lab 9 asks for a kubeadm cluster: containerd on every node, kubeadm, kubelet
> and kubectl installed, `kubeadm init` on the control plane, `kubeadm join` on the
> workers, then the Calico CNI, and every node `Ready`.

## One deliberate deviation

The slide assumes three separate machines and root on each. This machine is one WSL2
host with no passwordless sudo and no second VM, so the cluster is built with **kind**
rather than typing `kubeadm init` by hand.

That is a smaller deviation than it sounds. kind does not fake a cluster: it starts
three containers and bootstraps each one with the same kubeadm flow the slide
describes — `kubeadm init` on the control plane, `kubeadm join` on the workers, and
containerd as the runtime inside every node. What changes is *who* runs the commands
(kind does) and that the "nodes" share one kernel instead of being separate machines.
Everything the lab verifies — one control plane, two workers, Calico as the pod
network, all nodes `Ready` — is real.

The default kind CNI is switched off in `kind-config.yaml`, so Calico is genuinely
what makes pod networking work. Without it the nodes stay `NotReady`.

## Requirements

- [x] containerd 2.3.4 as the container runtime on all three nodes
- [x] kubeadm-bootstrapped control plane plus two joined workers
- [x] kubectl configured against the cluster (`context kind-ivolve`)
- [x] Calico v3.33.0 installed as the CNI (kind's default CNI disabled)
- [x] all three nodes `Ready`
- [x] pod-to-pod traffic across two different worker nodes, both directions, 0% loss
- [x] CoreDNS resolving `kubernetes.default.svc.cluster.local`

## Results

| Check | Result |
|---|---|
| Cluster | kind `ivolve` — 1 control-plane + 2 workers, v1.37.0 |
| Runtime | `containerd://2.3.4` on every node |
| CNI | Calico `v3.33.0`, `calico-node` **3/3** Ready |
| Pod CIDR | `192.168.0.0/16` (`default-ipv4-ippool`) |
| Cross-node ping | worker → worker2: **0% loss**, avg 0.300 ms · reverse: **0% loss**, avg 0.515 ms |
| DNS | `kubernetes.default.svc.cluster.local` → `10.96.0.1` |
| Unhealthy pods | **none** (0 after the fixes below) |

## Steps

### 1 — Declare the cluster

`kind-config.yaml` asks for three nodes and turns the stock CNI off:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: "192.168.0.0/16"
  apiServerAddress: "127.0.0.1"
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

`podSubnet` matters: Calico's default IP pool is `192.168.0.0/16`, and the two must
agree or pods get addresses Calico does not route.

### 2 — Create it

```console
$ kind create cluster --name ivolve --config Kubernetes/Lab9/kind-config.yaml --wait 180s
Creating cluster "ivolve" ...
 • Ensuring node image (kindest/node:v1.37.0) 🖼️
 ✓ Ensuring node image (kindest/node:v1.37.0) 🖼️
 • Preparing nodes 📦 📦 📦   ...
 ✓ Preparing nodes 📦 📦 📦
 • Writing configuration 📜  ...
 ✓ Writing configuration 📜
 • Starting control-plane 🕹️  ...
 ✓ Starting control-plane 🕹️
 • Installing StorageClass 💾  ...
 ✓ Installing StorageClass 💾
 • Joining worker nodes 🚜  ...
 ✓ Joining worker nodes 🚜
 • Waiting ≤ 3m0s for control-plane = Ready ⏳  ...
 ✗ Waiting ≤ 3m0s for control-plane = Ready ⏳
 • WARNING: Timed out waiting for Ready ⚠️
Set kubectl context to "kind-ivolve"
```

That timeout is expected, not a failure: with no CNI installed yet, a node cannot
report `Ready`. It is the first thing the Calico step fixes.

### 3 — Prove the cluster is incomplete without a CNI

```console
$ kubectl --context kind-ivolve get nodes
NAME                   STATUS     ROLES           AGE   VERSION
ivolve-control-plane   NotReady   control-plane   3m26s   v1.37.0
ivolve-worker          NotReady   <none>          3m4s    v1.37.0
ivolve-worker2         NotReady   <none>          3m4s    v1.37.0
```

### 4 — Install Calico

```console
$ curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml -o /tmp/calico.yaml
$ kubectl --context kind-ivolve apply -f /tmp/calico.yaml
clusterrolebinding.rbac.authorization.k8s.io/calico-node created
clusterrolebinding.rbac.authorization.k8s.io/calico-cni-plugin created
clusterrolebinding.rbac.authorization.k8s.io/calico-tier-getter created
daemonset.apps/calico-node created
deployment.apps/calico-kube-controllers created
```

Calico runs as a DaemonSet, so all three nodes get their own `calico-node`
(the images are pulled per node — that is why the first install is the slow part).

### 5 — Every node Ready, Calico 3/3

```console
$ kubectl --context kind-ivolve get nodes -o wide
NAME                   STATUS   ROLES           AGE   VERSION   INTERNAL-IP   CONTAINER-RUNTIME
ivolve-control-plane   Ready    control-plane   23m   v1.37.0   172.18.0.2    containerd://2.3.4
ivolve-worker          Ready    <none>          22m   v1.37.0   172.18.0.3    containerd://2.3.4
ivolve-worker2         Ready    <none>          22m   v1.37.0   172.18.0.4    containerd://2.3.4

$ kubectl --context kind-ivolve -n kube-system get ds calico-node
NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR
calico-node   3         3         3       3            3           kubernetes.io/os=linux

$ kubectl --context kind-ivolve get ippools.crd.projectcalico.org -o jsonpath='{.items[0].spec.cidr}'
192.168.0.0/16
```

### 6 — Prove pod networking actually crosses nodes

Two pods are pinned to different workers (`nettest.yaml` / `nettest2.yaml`), then each
pings the other's overlay address:

```console
$ kubectl --context kind-ivolve get pods -o wide -l app=nettest
NAME              READY   STATUS    IP               NODE
nettest-worker    1/1     Running   192.168.194.1    ivolve-worker
nettest-worker2   1/1     Running   192.168.209.72   ivolve-worker2

$ kubectl --context kind-ivolve exec nettest-worker -- ping -c 3 192.168.209.72
PING 192.168.209.72 (192.168.209.72): 56 data bytes
64 bytes from 192.168.209.72: seq=0 ttl=62 time=0.637 ms
64 bytes from 192.168.209.72: seq=1 ttl=62 time=0.145 ms
64 bytes from 192.168.209.72: seq=2 ttl=62 time=0.120 ms

--- 192.168.209.72 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.120/0.300/0.637 ms

$ kubectl --context kind-ivolve exec nettest-worker2 -- ping -c 3 192.168.194.1
--- 192.168.194.1 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.122/0.515/1.273 ms
```

`ttl=62` is the tell: the packet crossed one router (the node), i.e. it really went
from one node's pod network to the other's. Same-node traffic would be `ttl=64`.

### 7 — DNS

```console
$ kubectl --context kind-ivolve exec nettest-worker -- nslookup kubernetes.default.svc.cluster.local
Name:    kubernetes.default.svc.cluster.local
Address: 10.96.0.1
```

## What went wrong on the way

The first install did not finish cleanly, and the reasons are worth keeping:

1. **WSL ran out of host memory and restarted itself mid-install.** The Windows host
   was down to 0.5 GB free; after `wsl --shutdown` it came back with the cluster's
   containers restored by Docker. A short `Forbidden ... cannot list resource "nodes"`
   right after the restart was RBAC catching up, not a broken cert — it cleared on
   its own.
2. **Three images were corrupted by the interrupted pull.** kubelet kept reporting
   `exec /usr/bin/calico: input/output error`, `coredns ... no users found` and
   `local-path-provisioner: exec format error`. Deleting the image inside the node
   (`crictl rmi <image>`) and letting the pod re-create fixed each one.
3. **`kubectl wait` timeouts are not failures here.** With `disableDefaultCNI: true`,
   `NotReady` is the correct state until Calico is applied.

## Things worth knowing

1. **kind nodes are real kubeadm nodes.** Each container runs its own containerd,
   kubelet and kubeadm-generated PKI; the control plane genuinely is
   `kube-apiserver`/`etcd`/`controller-manager`/`scheduler` pods.
2. **The CNI is the switch between `NotReady` and `Ready`.** A node's `Ready`
   condition includes "network plugin ready", so an uninstalled CNI keeps the whole
   cluster unusable even though the API server answers.
3. **Pod CIDR must match the Calico IP pool.** `podSubnet: 192.168.0.0/16` in the kind
   config and `default-ipv4-ippool` in Calico are the same range; a mismatch leaves
   pods routable on their own node and invisible from the other.
4. **`disableDefaultCNI` is what makes the lab honest.** Leaving kindnet in place would
   let the cluster look healthy before Calico ran, and the CNI requirement would be
   untested.
5. **Calico pulls its images per node, not once.** Three nodes mean three copies of
   `calico/node`; the first install is roughly three times the download of a
   single-node cluster.
6. **Node containers share the host kernel.** "Three nodes" is three containerized
   kubelets and three pod networks, not three kernels — that is the price of doing
   this lab on one machine.

## Cleanup

The cluster is left running for Labs 10–17. Remove it only after those are done:

```bash
kind delete cluster --name ivolve
```

This deletes the `ivolve` cluster only; the unrelated `aiops` cluster is never touched.

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Kubernetes/Lab9
git commit -m "feat(lab9): three-node kind cluster with Calico CNI"
```
