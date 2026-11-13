<div align="center">

# DevOps Labs: iVolve Training

**One small app, taken from source code to a scanned image running on a cluster**

<br>

![Status](https://img.shields.io/badge/Labs_Complete-28-brightgreen?style=for-the-badge)
![Java](https://img.shields.io/badge/Java-17-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Maven](https://img.shields.io/badge/Maven-3.8.7-C71A36?style=for-the-badge&logo=apachemaven&logoColor=white)
![Gradle](https://img.shields.io/badge/Gradle-9.8.2-02303A?style=for-the-badge&logo=gradle&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-29.1.3-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-0.76.1-1904DA?style=for-the-badge&logo=aquasec&logoColor=white)
![Kubernetes](https://img.shields.io/badge/kind_1.37.0-Calico_3.33-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Jenkins](https://img.shields.io/badge/Jenkins-LTS-D24939?style=for-the-badge&logo=jenkins&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-core_2.16.3-EE0000?style=for-the-badge&logo=ansible&logoColor=white)

</div>

---

## About

| | |
|---|---|
| **Name** | Eslam Nabawy |
| **Program** | iVolve Technologies, DevOps Training |
| **GitHub** | [@EslamNabawy](https://github.com/EslamNabawy) |
| **Email** | eslamtarek.dev@gmail.com |
| **Repository** | [iVolve-Tasks](https://github.com/EslamNabawy/iVolve-Tasks) |
| **Environment** | Ubuntu 24.04 on WSL2, with Java 17, Maven, Gradle, Docker, Trivy, kind, kubectl, Jenkins, Prometheus, Grafana and Ansible |

## What this repo is

This is my work through the Cloud DevOps Accelerator deck from iVolve: 28 labs,
one tool at a time, all of them run on my own machine.

The idea is simple enough. Take a small Java calculator, build it, put it in a
container, shrink the container, scan it, run it on a cluster, wire up storage
and networking and monitoring, and then put the whole thing behind a pipeline so
I never do those steps by hand again. The last block flips it around: instead of
configuring servers, I describe them in a playbook and let Ansible do it.

I kept every lab folder to two things: the files I actually wrote, and a
`README.md` that shows the terminal output from the run that produced them.
If a command failed, the failure is in there too, because half of what I learned
came from output that refused to work the first time.

## A note on numbering

The deck and this repository do not agree on every number, and I did not
renumber anything to hide it. Labs 1 to 6 are the graded ones and share their
numbers with the deck. `Docker/Lab7` and `Docker/Lab8` are the deck's Docker labs
7 and 8, kept as D7 and D8 in the table below. The deck's Kubernetes block runs
as Labs 9 to 18, its Jenkins block as 20 to 22, Argo CD is 23, and Ansible takes
24 to 28.

Kubernetes Lab 7 and Jenkins Lab 8 are mine, not the deck's. I wanted the chain
to reach a running cluster and a real pipeline before the graded work was over,
so I added those two tracks and labelled them as additions.

## Progress

| # | Track | Lab | What it leaves behind | |
|:-:|---|---|---|:-:|
| 1 | Build Tools | [Packaging with **Maven**](Build%20Tools/Lab1/README.md) | `target/calculator.jar` | done |
| 2 | Build Tools | [Packaging with **Gradle**](Build%20Tools/Lab2/README.md) | `build/libs/calculator.jar` | done |
| 3 | Docker | [**Containerizing** the app](Docker/Lab3/README.md) | `app1`, `app2`, `app3` | done |
| 4 | Docker | [**Image optimization** and save/load](Docker/Lab4/README.md) | 671 MB down to 294 MB | done |
| 5 | Docker | [**Vulnerability scanning** with Trivy](Docker/Lab5/README.md) | 2,343 HIGH/CRITICAL down to 0 | done |
| 6 | Docker | [**Env vars** and resource limits](Docker/Lab6/README.md) | 3 runs, 1 CPU / 256 MB | done |
| D7 | Docker | [**Multi-network microservices**](Docker/Lab7/README.md) | 3 images, 2 bridge networks, 2 volumes | done |
| D8 | Docker | [**Compose stack** with MySQL](Docker/Lab8/README.md) | data and logs survive `down` then `up` | done |
| 7 | Kubernetes | [**Deploying to a cluster** with kind](Kubernetes/Lab7/README.md) | cluster `ivolve`, `app3` 1/1 Running | done |
| 8 | CI/CD | [**Jenkins pipeline** replaying Labs 1-6](Jenkins/Lab8/README.md) | `ivolve-labs-1-6`, build 11 `SUCCESS` | done |
| 9 | Kubernetes | [**Three-node cluster** and Calico](Kubernetes/Lab9/README.md) | 3 nodes Ready, pods talking across nodes | done |
| 10 | Kubernetes | [**Node isolation** with taints and labels](Kubernetes/Lab10/README.md) | Pending vs Running, on purpose | done |
| 11 | Kubernetes | [**Namespace and ResourceQuota**](Kubernetes/Lab11/README.md) | 3 pods max, the 4th refused | done |
| 12 | Kubernetes | [**ConfigMap and Secret**](Kubernetes/Lab12/README.md) | MySQL config plus a base64 Secret | done |
| 13 | Kubernetes | [**Persistent storage** with a hostPath PV](Kubernetes/Lab13/README.md) | 1Gi RWX Retain, PVC Bound | done |
| 14 | Kubernetes | [**MySQL StatefulSet** and headless Service](Kubernetes/Lab14/README.md) | `ivolvedb-0`, data survives the pod | done |
| 15 | Kubernetes | [**Node app and ClusterIP Service**](Kubernetes/Lab15/README.md) | 2 replicas, `/health` returns 200 | done |
| 16 | Kubernetes | [**CPU and memory requests/limits**](Kubernetes/Lab16/README.md) | `kubectl top` with real numbers | done |
| 17 | Kubernetes | [**NetworkPolicy** for MySQL](Kubernetes/Lab17/README.md) | only the app pods reach 3306 | done |
| 18 | Kubernetes | [**Monitoring stack**](Kubernetes/Lab18/README.md) | Prometheus, Alertmanager, Grafana, node-exporter | done |
| 19 | Security | [**RBAC and a service account**](Kubernetes/Lab19/README.md) | `jenkinssa`, Deployments only | done |
| 20 | CI/CD | [**Role-based authorization**](Jenkins/Lab20/README.md) | `user1` admin, `user2` read-only, 403 | done |
| 21 | CI/CD | [**Deployment pipeline**](Jenkins/Lab21/README.md) | build, scan, push, deploy, build #1 `SUCCESS` | done |
| 22 | CI/CD | [**Shared libraries and a build agent**](Jenkins/Lab22/README.md) | `ivolve-lib` on `docker-agent` | done |
| 23 | GitOps | [**Argo CD** watching the repository](Jenkins/Lab23/README.md) | the pipeline pushes, Argo CD syncs | done |
| 24 | Ansible | [**Control node, keys and inventory**](Ansible/Lab24/README.md) | 2 managed nodes, Docker by ad-hoc task | done |
| 25 | Ansible | [**One playbook, three installs**](Ansible/Lab25/README.md) | Docker, kubectl, Jenkins, `changed=6` then `changed=0` | done |
| 26 | Ansible | [**The same installs as roles**](Ansible/Lab26/README.md) | 3 roles, `changed=7` then `changed=0` | done |
| 27 | Ansible | [**MySQL role and Ansible Vault**](Ansible/Lab27/README.md) | `ivolve` DB, password as ciphertext | done |
| 28 | Ansible | [**Dynamic inventory**](Ansible/Lab28/README.md) | hosts discovered from a live API | done |

### What's done

- **Build tools.** The same calculator built twice, with Maven and with Gradle.
  Both test suites green and the two jars compared honestly.
- **Containers.** Three Dockerfile strategies with the sizes measured, and the
  stdin-only CLI proven with `docker run -i`.
- **Optimization.** 671 MB down to 294 MB, a non-root user, and a `save`/`load`
  round trip so the image can leave the machine.
- **Scanning.** Trivy's 2,343 HIGH/CRITICAL findings brought to zero, with the
  `--ignore-unfixed` caveat spelled out rather than quietly applied.
- **Configuration.** Environment variables, their precedence, and 1 CPU / 256 MB
  limits that the container really obeys.
- **Kubernetes.** A three-node cluster carrying scheduling controls, storage,
  MySQL, the app itself, a network policy and a monitoring stack.
- **Security.** A ServiceAccount that can create and update Deployments in one
  namespace and nothing else, proven with a real token rather than a `kubectl
  auth can-i` alone.
- **Jenkins access control.** Two users, one admin and one read-only, checked by
  HTTP status code: 201 for the admin, 403 for the other.
- **CI/CD.** A pipeline that rebuilds Labs 1-6 end to end, and a second one that
  takes the app all the way to a pod answering HTTP 200.
- **Microservices.** Three services, two networks, two log volumes and a bind
  mount, with the traffic path proven at both network boundaries.
- **Compose.** The app and MySQL in one file, with named volumes and a health
  check, and data that outlived `docker compose down`.
- **Shared libraries.** `BuildApp`, `BuildImage` and `DeployOnK8s` as global
  steps, running on a dedicated agent while the controller had zero executors.
- **GitOps.** Argo CD watching a branch that the pipeline writes to. When I
  changed a Deployment by hand, it was put back in six seconds.
- **Ansible.** A control node, its own key, an inventory of two hosts, and one
  idempotent playbook installing Docker, kubectl and Jenkins.
- **Roles.** The same three installs as `docker`, `kubectl` and `jenkins`, with
  versions and URLs in each role's `defaults/`.
- **Secrets.** A MySQL role whose application password exists only as vault
  ciphertext in the repository.
- **Dynamic inventory.** Hosts that came from an API query instead of a file,
  grouped, scoped and then targeted by a playbook.

### The deck, complete

All 28 labs are done. Each one has a write-up, a `commands.sh` that replays it,
and the terminal output that came out of the run.

## Headline results

<div align="center">

| | Lab 1, Maven | Lab 2, Gradle |
|---|:-:|:-:|
| Tests | **5 passed** | **5 passed** |
| Artifact | `target/calculator.jar` | `build/libs/calculator.jar` |
| Size | 3.7 KB | 2.3 KB |
| Rebuild | redoes everything | **7 of 8 tasks `UP-TO-DATE`** |

</div>

| Image | Size | Note |
|---|:-:|---|
| `app1` | **861 MB** | Maven builds inside the image |
| `app2` | **265 MB** | jar built on the host first |
| `app3` | **265 MB** | multi-stage, JRE, non-root |
| `image1` | **671 MB** | single stage |
| `image2` | **294 MB** | multi-stage, 2.28x smaller |
| `trivy-lab:v1` | **1.46 GB** | 2,122 HIGH, 221 CRITICAL |
| `ivolve-app:v2` | **252 MB** | **0** HIGH/CRITICAL |

| Area | What the run reported |
|---|---|
| Lab 6, limits | `NanoCpus=1000000000`, `Memory=268435456`, 24.67 MiB of 256 MiB used |
| Lab 7, cluster | `app3` 256 MB, loaded not pulled, 1/1 Running as uid 1000, CLI through `kubectl exec -i` |
| Lab 8, Jenkins | build 11 **`SUCCESS`** in 194.8 s, junit 10 tests 0 failures, six images built, scanned, gated and cleaned |
| Lab 9, network | 3 nodes plus Calico 3/3, cross-node ping 0% loss in both directions |
| Lab 10, isolation | untolerated pod **Pending**, tolerated pod running on the tainted node |
| Lab 11, quota | 3/3 pods, the fourth **refused at admission**, live counter proven |
| Lab 14, MySQL | 8.4.13, headless `ivolvedbsvc` resolves, data survived pod recreation |
| Lab 15, app | 2/2 replicas, init container created the DB and grants, `/health` 200 through the Service |
| Lab 16, limits | requests 1 CPU/1Gi, limits 2 CPU/2Gi, `kubectl top` live |
| Lab 17, policy | unrelated pods **blocked** on 3306, app traffic untouched |
| Lab 18, monitoring | node-exporter **3/3**, all targets `up`, Grafana 11.2.0 with a provisioned dashboard |
| Lab 19, RBAC | `jenkinssa`: create/update **yes**, patch/list/delete **no**, other namespaces **no** |
| Lab 20, Jenkins | `user1` build **201**, `user2` build **403**, anonymous **403** |
| D7, networks | 3 images at 198-202 MB, subnets `172.28.0.0/24` and `172.29.0.0/24`, notification log shows source `172.29.0.3` and backend request `172.28.0.3` |
| D8, compose | app 221 MB, `db` healthy, products survived `compose down` and `up`, image pushed to a local `registry:2` on `:5000` |
| Lab 21, pipeline | build #1 **`SUCCESS`**, 725 MB image pushed, CRITICAL gate with 9 triaged CVEs, pod `Running` and serving HTTP **200** |
| Lab 22, libraries | 3 library steps, `Running on docker-agent`, controller `numExecutors: 0` |
| Lab 23, GitOps | Argo CD **v3.6.1**, commit `2e0a472` pushed and reported `Synced`/`Healthy`, `selfHeal` reverted a manual edit in **6 s** |
| Lab 24, Ansible | `ansible-core 2.16.3`, 2 managed nodes, `ping` **SUCCESS**, Docker installed on both by one ad-hoc task |
| Lab 25, playbook | `changed=6` per node on the first run, **`changed=0`** on the second, Docker 29.1.3, kubectl v1.37.1 with a verified sha256, Jenkins 2.580.2 |
| Lab 26, roles | `changed=7` then **`changed=0`**, `site.yml` is three role names, every URL and version in `roles/*/defaults/`, same three versions on both nodes |
| Lab 27, vault | `changed=6` then **`changed=0`**, `ivolve` DB and `ivolveuser@%`, password only as `$ANSIBLE_VAULT;1.1;AES256`, logging in as the user shows `ivolve` |
| Lab 28, inventory | inventory built from a live API, `@managed: managed1, managed2` discovered and scoped by name, run 1 `changed=1`, run 2 **`changed=0`**, EC2 config ready for `tag:server=ivolve` |

## Repository layout

```
iVolve-Tasks
├── Build Tools
│   ├── Lab1          README · commands.sh · evidence/
│   └── Lab2          README · commands.sh · evidence/
├── Docker
│   ├── Lab3          Dockerfile.app1 · Dockerfile.app2 · Dockerfile.multistage
│   │                    .dockerignore · README
│   ├── Lab4          Dockerfile · Dockerfile.multistage · .dockerignore
│   │                    commands.sh · README
│   ├── Lab5          Dockerfile · Dockerfile.v2 · .dockerignore · package-lock.json
│   │                    commands.sh · README · reports/
│   ├── Lab6          Dockerfile · Dockerfile.env · env.txt · commands.sh · README
│   ├── Lab7          frontend/ backend/ notification/ (Dockerfiles) · commands.sh · README
│   └── Lab8          docker-compose.yml · commands.sh · README
├── Kubernetes
│   ├── Lab7          deployment.yaml · service.yaml · commands.sh · README
│   ├── Lab9          kind-config.yaml · nettest.yaml · nettest2.yaml
│   │                    commands.sh · README
│   ├── Lab10         pod-blocked.yaml · pod-allowed.yaml · commands.sh · README
│   ├── Lab11         namespace.yaml · quota.yaml · demo-pods.yaml
│   │                    extra-pod.yaml · commands.sh · README
│   ├── Lab12         configmap.yaml · secret.yaml · demo-pod.yaml
│   │                    commands.sh · README
│   ├── Lab13         pv.yaml · pvc.yaml · writer-pod.yaml · commands.sh · README
│   ├── Lab14         service.yaml · statefulset.yaml · commands.sh · README
│   ├── Lab15         deployment.yaml · service.yaml · commands.sh · README
│   ├── Lab16         resources-patch.yaml · commands.sh · README
│   ├── Lab17         networkpolicy.yaml · commands.sh · README
│   ├── Lab18         namespace.yaml · node-exporter.yaml · prometheus.yaml
│   │                    alertmanager.yaml · grafana.yaml · commands.sh · README
│   └── Lab19         serviceaccount.yaml · role.yaml · rolebinding.yaml
│                        commands.sh · README
├── Jenkins
│   ├── Lab8          Dockerfile · Jenkinsfile · jenkins.yaml · plugins.txt
│   │                    html.tpl · commands.sh · README
│   ├── Lab20         Dockerfile · plugins.txt · jenkins.yaml · job.xml
│   │                    commands.sh · README
│   ├── Lab21         Dockerfile · Jenkinsfile · jenkins.yaml · plugins.txt
│   │                    namespace/deployment/service.yaml · .trivyignore
│   │                    commands.sh · README
│   ├── Lab22         Dockerfile.agent · Jenkinsfile · jenkins.yaml
│   │                    namespace/deployment/service.yaml · .trivyignore
│   │                    shared-library/vars/  (buildApp · buildImage · deployOnK8s)
│   │                    commands.sh · README
│   └── Lab23         Jenkinsfile · jenkins.yaml · application.yaml
│                        manifests/deployment.yaml · manifests/service.yaml
│                        .trivyignore · commands.sh · README
├── Ansible
│   ├── Lab24         Dockerfile.node · inventory.ini · commands.sh · README
│   ├── Lab25         playbook.yml · commands.sh · README
│   ├── Lab26         site.yml · commands.sh · README
│   │                    roles/{docker,kubectl,jenkins}/{defaults,tasks}/main.yml
│   ├── Lab27         site.yml · commands.sh · README
│   │                    roles/mysql/{defaults,tasks}/main.yml
│   │                    group_vars/managed/vault.yml (AES-256) · .gitignore
│   └── Lab28         inventory.aws_ec2.yml · inventory.docker.yml
│                        verify.yml · commands.sh · README
└── README.md
```

The applications themselves are not in here. They get cloned into
`~/labs-workspace/` and gitignored, so what you see above is only the part I
wrote.

## How the labs run

Everything runs on WSL2 with Ubuntu 24.04, and every build happens inside the
Linux filesystem under `~`. Building under `/mnt/c` costs 5 to 20 times the time,
which I stopped doing after the first Maven build.

Each lab has a `commands.sh` that replays it from a clean state. Most of them
also rebuild their own starting point: Docker Labs 7 and 8 remove their
containers and volumes, and the Ansible labs recreate the managed nodes, because
a playbook that finds everything already installed just prints `changed=0` and
teaches nothing.

The Kubernetes labs share one cluster. Lab 9 creates `kind` cluster `ivolve` with
one control plane and two workers, Labs 10 to 18 build on it, and
`kind delete cluster --name ivolve` removes it at the end.

There is a second, unrelated `aiops` cluster and a set of `aiops-*` containers on
this machine that belong to another project. I stayed out of them.

The Ansible labs run against two containers acting as managed nodes, `managed1`
on `:2222` and `managed2` on `:2223`, reached with a dedicated key.

One last thing, because it explains most of the odd-looking output in these
write-ups: nothing here is transcribed from memory. Every console block is
copied from a run. Two exceptions exist and both are labelled in place, the
rendered terminal images in Labs 1 and 2, and one `sudo` line in Lab 1 that I
never actually executed.

## Where I deviated, and why

1. **Lab 9 uses kind, not kubeadm by hand.** I have one machine and no
   passwordless sudo. kind still bootstraps each node with kubeadm and
   containerd, so the control-plane/worker split and Calico are real; what is
   missing is the hand-typed `kubeadm init` that the deck describes. The README
   says which parts are proven and which are not.
2. **Lab 15's image was built locally and loaded into kind.** The deck wants the
   Docker Hub image from Lab 8, which I did not run, and I had no Hub
   credentials. `imagePullPolicy: IfNotPresent` makes the loaded image work.
3. **Kubernetes names are lowercase** where the deck capitalises them
   (`ivolveQuota` became `ivolvequota`, and the same for `ivolveCM`, `ivolveDBSvc`
   and `ivolveNP`). The API rejects uppercase in object names, so there was no
   choice.
4. **The evidence images in Labs 1 and 2 are rendered** from real captured
   output rather than being screenshots of a terminal. Both READMEs say so.
5. **Lab 14's MySQL data directory was re-initialised** after a full Windows disk
   caused WSL I/O errors in the middle of the first deployment. The incident and
   the recovery are recorded in that README rather than tidied away.
6. **"Three nodes" means three containerised kubelets** sharing one kernel, not
   three machines.
7. **Labs 21 and 22 push to a local registry, not Docker Hub.** No credentials,
   so the image goes to a `registry:2` container on `:5000`. The push, delete and
   pull cycle is real; only the destination differs from the deck.
8. **Lab 23's CI commits land on a `gitops` branch.** Argo CD watches that
   branch, so the history on `main` stays the work I wrote by hand.
9. **The Ansible managed nodes are containers with `sshd` in the foreground.**
   There is no systemd in them, so `docker.io` and `jenkins` are installed and
   verified, not started as services. On a VM the same playbook would need one
   more `service` task. Lab 27 needs MySQL running, so that role starts `mysqld
   --daemonize` itself, creates the socket directory and guards the start with
   `pgrep` to keep the second run clean.
10. **Labs 25 and 26 fetch large files on the control node.** A 59 MB kubectl
    download does not fit inside `get_url`'s socket timeout on this connection,
    and the Jenkins mirror apt picks drops the 53 MB `.deb`. Both are fetched
    once with `curl --retry-all-errors`, verified and copied out. The installs are
    real; the transport is not the textbook one.
11. **The Docker role retries a slow mirror.** `docker.io` is 93 MB across 46
    packages and `archive.ubuntu.com` served it at 73 to 113 kB/s. Lab 26's first
    attempt died halfway through. The role sets `Acquire::Retries "10"` and
    retries the task, which turns a failure into a 20-minute run.
12. **Lab 28 discovers hosts from the Docker API, not from EC2.** There is no AWS
    account here, so `aws_ec2` stops at `Unable to locate credentials`. The EC2
    inventory file is the deck's, ready as written; the evidence comes from the
    same mechanism pointed at the Docker daemon, a plugin querying a live API and
    a playbook targeting whatever it returns.
13. **Lab 27's vault key is generated, not committed.** `commands.sh` writes
    `.vault-pass` with a throwaway string so the lab reproduces from a clone. That
    is fine for lab data and wrong for a real secret. A committed ciphertext
    sitting next to a discoverable key is obfuscation, and the README says that
    out loud.

## Quick start

These labs need Linux. Docker and kind want a Linux kernel, so Windows CMD or
PowerShell alone will not get you through them. Use WSL2 (`wsl --install`), a
native install, or a VM, and keep the project under `/home/<you>`.

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk maven
```

```bash
git clone https://github.com/EslamNabawy/iVolve-Tasks.git && cd iVolve-Tasks
```

Pick a lab, open its `README.md`, run its `commands.sh`. The Kubernetes track
does have an order (9 through 18); the rest can be read on their own.

<div align="center">

**Eslam Nabawy**, iVolve DevOps Training, October and November 2026

</div>
