<div align="center">

# DevOps Labs — iVolve Training

**From source code to a running container**

Hands-on labs from the iVolve DevOps track — building, testing, packaging,
containerizing, optimizing and scanning a set of small applications, one tool
at a time.

<br>

![Status](https://img.shields.io/badge/Labs_Complete-7%20%2F%207-brightgreen?style=for-the-badge)
![Java](https://img.shields.io/badge/Java-17-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Maven](https://img.shields.io/badge/Maven-3.8.7-C71A36?style=for-the-badge&logo=apachemaven&logoColor=white)
![Gradle](https://img.shields.io/badge/Gradle-9.8.2-02303A?style=for-the-badge&logo=gradle&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-29.1.3-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-0.76.1-1904DA?style=for-the-badge&logo=aquasec&logoColor=white)
![WSL](https://img.shields.io/badge/Ubuntu_24.04-WSL2-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

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
| **Environment** | Ubuntu 24.04 LTS on WSL2 · Java 17 · Maven · Gradle · Docker · Trivy · kind · kubectl |

---

## 🎯 What this repository is

Every lab in this training answers one question: **how does source code become
something you can actually ship — and trust?**

```
📄 Source code  →  🔧 Build tool  →  📦 Artifact  →  🐳 Image  →  🔍 Scan  →  ☸️ Running
   .java files      Maven/Gradle     calculator.jar   Docker      Trivy      Kubernetes
                     Labs 1 & 2                        Labs 3–6                Lab 7
```

Each stage consumes the previous one's output. **Labs 1 and 2 build the same
application with two different tools** so the app is held constant and the
*tooling* is the only variable. **Lab 3 takes Lab 1's jar** and packages it with
its own Java runtime. **Labs 4–6** work on a Spring Boot, an Express and a Flask
app to cover image size, non-root users, vulnerability scanning, environment
variables and resource limits.

Every lab folder holds the files I authored plus a write-up with the real
terminal output and an explanation of *why*, not just *what*.

> **Lab 3's app:** an interactive command-line calculator (Java 17). It reads two
> numbers from stdin and prints sum, difference, product and quotient. It is
> **not** a web service — nothing listens on a port, which is why Lab 3's
> `EXPOSE 8080` is inert and `docker run -i` is mandatory.

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

### ✅ To-do

**Done**
- [x] **Lab 1 — Maven** · 5/5 tests pass · `target/calculator.jar` (3.7 KB) · verified
- [x] **Lab 2 — Gradle** · 5/5 tests pass · `build/libs/calculator.jar` (2.3 KB) · verified
- [x] **Lab 3 — Docker** · `app1` 861 MB vs `app2` 265 MB · non-root confirmed · cleaned up
- [x] **Lab 4 — Optimization** · 671 MB → 294 MB · non-root `appuser` · `save`/`load` round trip
- [x] **Lab 5 — Trivy** · 2,343 HIGH/CRITICAL found, all remediated · `ivolve-app:v2` clean
- [x] **Lab 6 — Env & limits** · three config sources · 1 CPU / 256 MB enforced
- [x] **Lab 7 — Kubernetes** · kind cluster · `app3` loaded, Running as uid 1000 · calculator computed in-cluster
- [x] **Bonus** — multi-stage builds in Labs 3 & 4, remediation in Lab 5

**Next**
- [ ] 🔧 **Jenkins** — automate Labs 1–6 as a pipeline
- [ ] 🔄 **ArgoCD** — GitOps sync from this repository
- [ ] ⚙️ **Ansible** — provision the machines everything runs on

---

## 📊 Headline results

<div align="center">

| | Lab 1 · Maven | Lab 2 · Gradle |
|---|:-:|:-:|
| Tests | **5 passed** | **5 passed** |
| Artifact | `target/calculator.jar` | `build/libs/calculator.jar` |
| Size | 3.7 KB | 2.3 KB |
| Rebuild | redoes everything | **7 of 8 tasks `UP-TO-DATE`** |

| Lab 3 · Image | Build location | Size | Reproducible |
|---|:-:|:-:|:-:|
| `app1` | inside Docker | **861 MB** | ✅ |
| `app2` | on the host | **265 MB** | ❌ |
| `app3` 🏆 | multi-stage | **265 MB** | ✅ |

| Lab 4 · Image | Stages | Size |
|---|:-:|:-:|
| `image1` | single | **671 MB** |
| `image2` 🏆 | multi-stage, JRE, non-root | **294 MB** |

| Lab 5 · Scan | Size | HIGH | CRITICAL |
|---|:-:|:-:|:-:|
| `trivy-lab:v1` | 1.46 GB | **2,122** | **221** |
| `ivolve-app:v2` 🏆 | 252 MB | **0** | **0** |

**Multi-stage cut Lab 4's image by 2.28× and Lab 5's remediation removed all
2,343 HIGH/CRITICAL findings.**

</div>

---

## 📁 Structure

```
iVolve-Tasks
├── 📁 Build Tools
│   ├── 📁 Lab1          commands.sh · README.md
│   └── 📁 Lab2          commands.sh · README.md
├── 📁 Docker
│   ├── 📁 Lab3          Dockerfile.app1 · Dockerfile.app2
│   │                    Dockerfile.multistage · .dockerignore · README.md
│   ├── 📁 Lab4          Dockerfile · Dockerfile.multistage · .dockerignore
│   │                    commands.sh · README.md
│   ├── 📁 Lab5          Dockerfile · Dockerfile.v2 · .dockerignore
│   │                    package-lock.json · commands.sh · README.md
│   │                    reports/trivy-v1.html · reports/trivy-v2.html
│   └── 📁 Lab6          Dockerfile · Dockerfile.env · env.txt
│                        commands.sh · README.md
├── 📁 Kubernetes
│   └── 📁 Lab7          deployment.yaml · service.yaml
│                        commands.sh · README.md
└── 📄 README.md
```

Upstream application source is cloned to `~/labs-workspace/` and **never
committed** — this repository contains only work I authored.

---

## ⚡ Quick start

> **These labs require Linux.** Docker needs a Linux kernel; Windows CMD or
> PowerShell alone cannot run them. Use **WSL2** (`wsl --install`), a native
> Linux install, or a VM. On WSL keep projects under `/home/<you>`, never
> `/mnt/c` — builds there run 5–20× slower.

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk maven
```

```bash
git clone https://github.com/EslamNabawy/iVolve-Tasks.git && cd iVolve-Tasks
```

Then follow any lab's README, or run its `commands.sh` end to end.

---

<div align="center">

**Eslam Nabawy** · iVolve DevOps Training · October 2026

</div>
