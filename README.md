<div align="center">

# DevOps Labs — iVolve Training

**From source code to a scanned, running, monitored workload**

Hands-on labs from the iVolve DevOps track — building, testing, packaging,
containerizing, optimizing, scanning, deploying, securing and monitoring a small
set of applications, one tool at a time.

<br>

![Status](https://img.shields.io/badge/Labs_Complete-20-brightgreen?style=for-the-badge)
![Java](https://img.shields.io/badge/Java-17-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Maven](https://img.shields.io/badge/Maven-3.8.7-C71A36?style=for-the-badge&logo=apachemaven&logoColor=white)
![Gradle](https://img.shields.io/badge/Gradle-9.8.2-02303A?style=for-the-badge&logo=gradle&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-29.1.3-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-0.76.1-1904DA?style=for-the-badge&logo=aquasec&logoColor=white)
![Kubernetes](https://img.shields.io/badge/kind_1.37.0-Calico_3.33-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Jenkins](https://img.shields.io/badge/Jenkins-LTS-D24939?style=for-the-badge&logo=jenkins&logoColor=white)

</div>

---

## 👤 About

| | |
|---|---|
| **Name** | Eslam Nabawy |
| **Program** | iVolve Technologies — DevOps Training |
| **GitHub** | [@EslamNabawy](https://github.com/EslamNabawy) |
| **Email** | eslamtarek.dev@gmail.com |
| **Repository** | [iVolve-Tasks](https://github.com/EslamNabawy/iVolve-Tasks) |
| **Environment** | Ubuntu 24.04 LTS on WSL2 · Java 17 · Maven · Gradle · Docker · Trivy · kind · kubectl · Jenkins · Prometheus · Grafana |

---

## 🎯 What this repository is

Every lab answers one question: **how does source code become something you can
actually ship — and trust?**

```
📄 Source      →  🔧 Build      →  📦 Artifact    →  🐳 Image     →  🔍 Scan     →  ☸️ Cluster     →  🤖 CI/CD     →  📊 Monitor
.java files       Maven/Gradle     calculator.jar    Docker          Trivy          kind + Calico     Jenkins        Prometheus
Labs 1–2          Labs 1–2         Labs 1–3          Labs 3–6        Lab 5          Labs 9–14         Lab 8          Lab 18
```

**Labs 1 and 2 build the same application with two different tools** so the app
is held constant and the *tooling* is the only variable. **Lab 3** packages
Lab 1's jar with its own Java runtime. **Labs 4–6** work on a Spring Boot, an
Express and a Flask app to cover image size, non-root users, vulnerability
scanning, environment variables and resource limits.

**Lab 7** deploys the app to a kind cluster, and **Lab 8** replays Labs 1–6 as
one Jenkins pipeline. Those two are additional tracks beyond the graded
reports.

**Labs 9–18** are the deck's Kubernetes block, end to end: a three-node cluster
built by kubeadm (via kind) with Calico, node isolation, quotas, config and
secrets, static storage, a MySQL StatefulSet, the Node application with its
ClusterIP Service, CPU/memory limits, a NetworkPolicy, and a full Prometheus /
Alertmanager / Grafana monitoring stack.

**Lab 19** adds the security layer — a ServiceAccount and Role that may only
create/update Deployments in `ivolve`. **Lab 20** moves to Jenkins and gives
`user1` admin rights and `user2` read-only access.

### A note on numbering

This repository numbers labs **in the order they were delivered**. The deck's
Docker labs 7–8 (multi-network microservices and a Compose stack) are **not**
in this repository and remain on the Next list; the repo's Lab 7 (Kubernetes)
and Lab 8 (Jenkins) are the additional tracks, and the deck's Kubernetes block
maps to Labs 9–18.

Every lab folder holds the files I authored plus a write-up with the **real
terminal output** and an explanation of *why*, not just *what*.

---

## 📋 Progress

| # | Track | Lab | Deliverable | Status |
|:-:|---|---|---|:-:|
| 1 | Build Tools | [Packaging with **Maven**](Build%20Tools/Lab1/README.md) | `target/calculator.jar` | ✅ |
| 2 | Build Tools | [Packaging with **Gradle**](Build%20Tools/Lab2/README.md) | `build/libs/calculator.jar` | ✅ |
| 3 | Docker | [**Containerizing** the app](Docker/Lab3/README.md) | `app1` · `app2` · `app3` | ✅ |
| 4 | Docker | [**Image optimization** + export/load](Docker/Lab4/README.md) | `image1` 671 MB → `image2` 294 MB | ✅ |
| 5 | Docker | [**Vulnerability scanning** with Trivy](Docker/Lab5/README.md) | 2,343 HIGH/CRITICAL → **0** | ✅ |
| 6 | Docker | [**Env vars** + resource limits](Docker/Lab6/README.md) | 3 runs · 1 CPU / 256 MB | ✅ |
| 7 | Kubernetes | [**Deploying to a cluster** with kind](Kubernetes/Lab7/README.md) | cluster `ivolve` · `app3` 1/1 Running | ✅ |
| 8 | CI/CD | [**Jenkins pipeline** replaying Labs 1–6](Jenkins/Lab8/README.md) | `ivolve-labs-1-6` — build 11 `SUCCESS` | ✅ |
| 9 | Kubernetes | [**Three-node cluster + Calico**](Kubernetes/Lab9/README.md) | 3 nodes `Ready` · cross-node pod network | ✅ |
| 10 | Kubernetes | [**Node isolation** with taints and labels](Kubernetes/Lab10/README.md) | taint + label · Pending vs Running | ✅ |
| 11 | Kubernetes | [**Namespace + ResourceQuota**](Kubernetes/Lab11/README.md) | `ivolve` ns · 3 pods max · 4th refused | ✅ |
| 12 | Kubernetes | [**ConfigMap + Secret**](Kubernetes/Lab12/README.md) | MySQL config + base64 Secret | ✅ |
| 13 | Kubernetes | [**Persistent storage** with hostPath PV/PVC](Kubernetes/Lab13/README.md) | 1Gi `RWX` `Retain` · PVC Bound | ✅ |
| 14 | Kubernetes | [**MySQL StatefulSet** + headless Service](Kubernetes/Lab14/README.md) | `ivolvedb-0` · headless DNS · data persists | ✅ |
| 15 | Kubernetes | [**Node app + ClusterIP Service**](Kubernetes/Lab15/README.md) | 2 replicas · init DB · `/health` 200 | ✅ |
| 16 | Kubernetes | [**CPU/memory requests & limits**](Kubernetes/Lab16/README.md) | 1 CPU / 1Gi · 2 CPU / 2Gi · `kubectl top` | ✅ |
| 17 | Kubernetes | [**NetworkPolicy** for MySQL](Kubernetes/Lab17/README.md) | only app pods → 3306 | ✅ |
| 18 | Kubernetes | [**Monitoring stack**](Kubernetes/Lab18/README.md) | Prometheus · Alertmanager · Grafana · node-exporter | ✅ |
| 19 | Security | [**RBAC + service account**](Kubernetes/Lab19/README.md) | `jenkinssa` · create/update Deployments only | ✅ |
| 20 | CI/CD | [**Role-based authorization**](Jenkins/Lab20/README.md) | `user1` admin · `user2` read-only · build 403 | ✅ |

### ✅ Done

- [x] **Build tools** — the same calculator with Maven and Gradle, both test
      suites green, jars compared honestly.
- [x] **Containerization** — three Dockerfile strategies, sizes measured, the
      stdin CLI proven with `docker run -i`.
- [x] **Optimization** — 671 MB → 294 MB, non-root user, `save`/`load` round trip.
- [x] **Scanning** — Trivy's 2,343 HIGH/CRITICAL findings remediated to **0**,
      with the ignored-count caveat stated.
- [x] **Configuration** — env vars, precedence and 1 CPU / 256 MB limits enforced.
- [x] **Kubernetes** — a real three-node cluster, scheduling controls, storage,
      MySQL, the app, policy and monitoring, all verified.
- [x] **Security** — a ServiceAccount that can create/update Deployments and
      nothing else, proven with a real token.
- [x] **Jenkins access control** — two users, admin vs read-only, verified by
      HTTP status codes (201 vs 403).
- [x] **CI/CD** — one Jenkins pipeline that rebuilds Labs 1–6 end to end.

### 🔭 Next

- [ ] 🐳 **Docker Labs 7–8** — multi-network microservices, Compose stack (deck)
- [ ] 🤖 **Jenkins CI/CD** — deployment pipeline, agents, shared libraries (deck 21–22)
- [ ] 🔄 **ArgoCD** — GitOps sync from this repository (deck Lab 23)
- [ ] ⚙️ **Ansible** — provision the machines everything runs on (deck 24–28)

---

## 📊 Headline results

<div align="center">

| | Lab 1 · Maven | Lab 2 · Gradle |
|---|:-:|:-:|
| Tests | **5 passed** | **5 passed** |
| Artifact | `target/calculator.jar` | `build/libs/calculator.jar` |
| Size | 3.7 KB | 2.3 KB |
| Rebuild | redoes everything | **7 of 8 tasks `UP-TO-DATE`** |

| Lab 3–6 · Image | Size | Note |
|---|:-:|---|
| `app1` | **861 MB** | Maven builds inside the image |
| `app2` | **265 MB** | jar built on the host |
| `app3` 🏆 | **265 MB** | multi-stage, JRE, non-root |
| `image1` | **671 MB** | single stage |
| `image2` 🏆 | **294 MB** | multi-stage (2.28× smaller) |
| `trivy-lab:v1` | **1.46 GB** | 2,122 HIGH · 221 CRITICAL |
| `ivolve-app:v2` 🏆 | **252 MB** | **0** HIGH/CRITICAL |

</div>

| Area | Verified result |
|---|---|
| Lab 6 · limits | `NanoCpus=1000000000`, `Memory=268435456`, 24.67 MiB / 256 MiB used |
| Lab 7 · cluster | `app3` 256 MB loaded, never pulled · 1/1 Running as uid 1000 · CLI via `kubectl exec -i` |
| Lab 8 · Jenkins | build 11 **`SUCCESS`** in 194.8 s · junit 10 tests, 0 failures · six images built, scanned, gated, cleaned |
| Lab 9 · network | 3 nodes + Calico 3/3 · cross-node ping **0% loss** both directions |
| Lab 10 · isolation | untolerated pod **Pending** · tolerated pod running on the tainted node |
| Lab 11 · quota | 3/3 pods · fourth **refused at admission** · live counter proven |
| Lab 14 · MySQL | 8.4.13 · headless `ivolvedbsvc` resolves · data survived pod recreation |
| Lab 15 · app | 2/2 replicas · init container created DB + grants · `/health` 200 through the Service |
| Lab 16 · limits | requests 1 CPU/1Gi · limits 2 CPU/2Gi · `kubectl top` live |
| Lab 17 · policy | unrelated pods **blocked** on 3306 · app traffic untouched |
| Lab 18 · monitoring | node-exporter **3/3** · all targets `up` · Grafana 11.2.0 with a provisioned dashboard |
| Lab 19 · RBAC | `jenkinssa` create/update **yes**, patch/list/delete **no**, other namespaces **no** |
| Lab 20 · Jenkins | `user1` build **201**, `user2` build **403**, anonymous **403** |

---

## 📁 Repository layout

```
iVolve-Tasks
├── 📁 Build Tools
│   ├── 📁 Lab1          README · commands.sh · evidence/
│   └── 📁 Lab2          README · commands.sh · evidence/
├── 📁 Docker
│   ├── 📁 Lab3          Dockerfile.app1 · Dockerfile.app2 · Dockerfile.multistage
│   │                    .dockerignore · README
│   ├── 📁 Lab4          Dockerfile · Dockerfile.multistage · .dockerignore
│   │                    commands.sh · README
│   ├── 📁 Lab5          Dockerfile · Dockerfile.v2 · .dockerignore · package-lock.json
│   │                    commands.sh · README · reports/
│   └── 📁 Lab6          Dockerfile · Dockerfile.env · env.txt · commands.sh · README
├── 📁 Kubernetes
│   ├── 📁 Lab7          deployment.yaml · service.yaml · commands.sh · README
│   ├── 📁 Lab9          kind-config.yaml · nettest.yaml · nettest2.yaml
│   │                    commands.sh · README
│   ├── 📁 Lab10         pod-blocked.yaml · pod-allowed.yaml · commands.sh · README
│   ├── 📁 Lab11         namespace.yaml · quota.yaml · demo-pods.yaml
│   │                    extra-pod.yaml · commands.sh · README
│   ├── 📁 Lab12         configmap.yaml · secret.yaml · demo-pod.yaml
│   │                    commands.sh · README
│   ├── 📁 Lab13         pv.yaml · pvc.yaml · writer-pod.yaml · commands.sh · README
│   ├── 📁 Lab14         service.yaml · statefulset.yaml · commands.sh · README
│   ├── 📁 Lab15         deployment.yaml · service.yaml · commands.sh · README
│   ├── 📁 Lab16         resources-patch.yaml · commands.sh · README
│   ├── 📁 Lab17         networkpolicy.yaml · commands.sh · README
│   ├── 📁 Lab18         namespace.yaml · node-exporter.yaml · prometheus.yaml
│   │                    alertmanager.yaml · grafana.yaml · commands.sh · README
│   └── 📁 Lab19         serviceaccount.yaml · role.yaml · rolebinding.yaml
│                        commands.sh · README
├── 📁 Jenkins
│   ├── 📁 Lab8          Dockerfile · Jenkinsfile · jenkins.yaml · plugins.txt
│   │                    html.tpl · commands.sh · README
│   └── 📁 Lab20         Dockerfile · plugins.txt · jenkins.yaml · job.xml
│                        commands.sh · README
└── 📄 README.md
```

Upstream application source is cloned to `~/labs-workspace/` and **never
committed** — this repository contains only work I authored.

---

## ⚙️ How the labs run

- **Everything runs on WSL2 (Ubuntu 24.04), builds inside the Linux filesystem**
  (`~/…`), never under `/mnt/c` — the 9p mount is 5–20× slower.
- **Each lab has a `commands.sh`** that replays it from a clean state, plus a
  `README.md` with the requirements, the real output and the reasoning.
- **The Kubernetes labs share one cluster.** Lab 9 creates `kind` cluster
  `ivolve` (1 control plane + 2 workers, Calico); Labs 10–18 build on it, and
  it is removed with `kind delete cluster --name ivolve` when the work is done.
- **The unrelated `aiops` cluster and containers belong to another project** and
  are never touched.
- **No fabricated output.** Every console block is a real run. The two
  exceptions are flagged where they appear: the rendered terminal images in
  Labs 1–2, and the one `sudo` line in Lab 1 that was never executed.

## 🧭 Known deviations and limits

1. **Lab 9 uses kind instead of hand-run kubeadm.** This host has no second
   machine and no passwordless sudo; kind still bootstraps each node with
   kubeadm and containerd, so the control-plane/worker split and Calico are
   real. The README says exactly what is and is not proven.
2. **Lab 15's image is built locally and `kind load`ed.** The deck asks for a
   Docker Hub image from Lab 8, which was not run, and this session had no Hub
   credentials. `imagePullPolicy: IfNotPresent` makes the loaded image work;
   the deviation is documented in that lab.
3. **Kubernetes names are lowercased** where the deck capitalises them
   (`ivolveQuota` → `ivolvequota`, `ivolveCM` → `ivolvecm`, `ivolveDBSvc` →
   `ivolvedbsvc`, `ivolveNP` → `ivolvenp`, …). The API rejects uppercase names.
4. **Labs 1–2's evidence images are rendered** from real captured output, not
   raw screenshots. Both READMEs say so.
5. **The Lab 14 MySQL data directory was re-initialised** after a full Windows
   host disk caused WSL I/O errors during the first deployment; the incident and
   the recovery are recorded in that README.
6. **The Kubernetes labs share one kernel.** "Three nodes" is three
   containerised kubelets, not three machines.

---

## 🚀 Quick start

> **These labs require Linux.** Docker and kind need a Linux kernel; Windows
> CMD or PowerShell alone cannot run them. Use **WSL2** (`wsl --install`), a
> native Linux install, or a VM. On WSL keep projects under `/home/<you>`.

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk maven
```

```bash
git clone https://github.com/EslamNabawy/iVolve-Tasks.git && cd iVolve-Tasks
```

Then open any lab's `README.md` and run its `commands.sh`. The labs build on
each other, so the order matters for the Kubernetes track (9 → 18).

---

<div align="center">

**Eslam Nabawy** · iVolve DevOps Training · October–November 2026

</div>
