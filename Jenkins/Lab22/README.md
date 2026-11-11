# Lab 22 — Jenkins Shared Libraries and a Build Agent

<p align="center"><em>The Lab 21 pipeline, rebuilt so that the Jenkinsfile only decides
<strong>what</strong> to run. The <strong>how</strong> lives in a shared library, and the work runs
on an agent, not on the controller.</em></p>

---

## Requirements

| # | Requirement | Where |
|---|---|---|
| 1 | Clone `DemoApp` with its `Dockerfile` | [Checkout](#1-checkout) |
| 2 | `BuildApp` library — unit test + build | [Build app](#2-build-app) |
| 3 | `BuildImage` library — build, scan, push, delete local | [Build, scan, push](#3-build-scan-push-delete) |
| 4 | `DeployOnK8s` library — edit the deployment file + deploy | [Deploy](#4-deploy-to-kubernetes) |
| 5 | Update the pipeline to use the libraries | [The pipeline](#the-pipeline) |
| 6 | Configure a Jenkins agent (slave) and run the pipeline there | [The agent](#the-agent) |

Two deviations carried over from Lab 21, unchanged here:

* **Registry = local, not Docker Hub** — no Hub credentials on this host, so the
  image goes to the `registry:2` container from Lab 8.
* **`DemoApp` is cloned from `file:///home/eslam/labs-workspace/DemoApp`** — the
  upstream repository, unmodified, because GitHub is unreliable from this host.

---

## The pipeline

```
Jenkinsfile  (Jenkins/Lab22/Jenkinsfile)
├── Checkout ────────────────── app/ (DemoApp) + repo/ (this repository)
├── Build app ───────────────── BuildApp.step  → mvn -B clean package + junit
├── Build, scan, push image ─── BuildImage.step → docker build / trivy / push / rmi
└── Deploy to Kubernetes ────── DeployOnK8s.step → sed manifest + kubectl apply + rollout
post { always / success / failure }
```

The pipeline body no longer contains a single Maven, Trivy, registry or kubectl
flag. Compare the Lab 21 stages with these four:

```groovy
stage('Build app')                { steps { buildApp(dir: 'app') } }
stage('Build, scan, push image')  { steps { buildImage(dir: 'app', image: env.IMAGE, ...) } }
stage('Deploy to Kubernetes')     { steps { deployOnK8s(dir: 'repo', image: env.DEPLOY_REF, ...) } }
```

Four of Lab 21's seven stages collapse into one library call, on purpose: build,
scan, push and "delete the local copy" are one decision, not four. If the push
fails, keeping the local image would let the next step deploy from a stale copy —
so they live together.

### The library

`Jenkins/Lab22/shared-library/vars/` — three global steps, loaded with
`@Library('ivolve-lib@main') _`:

| File | What it does |
|---|---|
| `buildApp.groovy` | `mvn -B clean package`, lists the jar, publishes `target/surefire-reports/*.xml` |
| `buildImage.groovy` | `docker build`, Trivy report + CRITICAL gate, `docker push`, `docker rmi` |
| `deployOnK8s.groovy` | rewrites `image:` in the manifest, applies namespace/deployment/service, waits for the rollout |

The library lives **inside this repository**, so the Jenkins global-library
configuration points at a subdirectory rather than the repository root:

```yaml
retriever:
  modernSCM:
    libraryPath: "Jenkins/Lab22/shared-library"
    scm:
      git:
        remote: "file:///home/eslam/iVolve-Tasks"
```

---

## The agent

`jenkins.yaml` declares one permanent inbound agent and **zero controller
executors**:

```yaml
numExecutors: 0
nodes:
  - permanent:
      name: "docker-agent"
      labelString: "docker linux"
      numExecutors: 1
      remoteFS: "/home/jenkins/agent"
      retentionStrategy: "always"
      launcher: jnlp
```

`numExecutors: 0` is the point of the lab: if the agent is not connected, the
pipeline cannot run anywhere. Jenkins itself generates the agent secret, so the
script reads it out of the running instance instead of inventing one:

```bash
curl -s -b "$JAR" -u "$USER:$PASS" -H "$CRUMB" -X POST \
  --data-urlencode 'script=println(Jenkins.instance.getComputer("docker-agent").jnlpMac)' \
  "$URL/scriptText"
```

The agent is a container built from `Dockerfile.agent` — the Lab 21 controller
image minus the Jenkins plugins, plus the official `jenkins/inbound-agent`
remoting client. It mounts the same docker socket, kubeconfig and repositories
as the controller, because the work it does is identical; only the process
running it is different.

---

## Results

Every block below is copied from the terminal or the build console of the run
that produced this README (build #1, 11 Nov 2026).

### 0. Controller with no executors, agent connected

```text
$ curl -s -u ivolve-admin:ivolve-admin http://127.0.0.1:8082/api/json?tree=mode,numExecutors
{"_class":"hudson.model.Hudson","mode":"NORMAL","numExecutors":0}agent secret: 01eb1137… (64 chars)
{"_class":"hudson.model.ComputerSet","computer":[
  {"_class":"hudson.model.Hudson$MasterComputer","displayName":"Built-In Node","numExecutors":0,"offline":false},
  {"_class":"hudson.slaves.SlaveComputer","displayName":"docker-agent","numExecutors":1,"offline":false}]}
INFO: WebSocket connection open
INFO: Connected
```

```text
trigger HTTP 201 (want 201)
pipeline result: SUCCESS
{
    "_class": "org.jenkinsci.plugins.workflow.job.WorkflowRun",
    "number": 1,
    "result": "SUCCESS"
}
```

### 1. Checkout

```text
Running on docker-agent in /home/jenkins/agent/workspace/lab22-pipeline
+ echo agent=docker-agent
agent=docker-agent
```

`Running on docker-agent` is the proof the whole pipeline left the controller.

### 2. Build app

```text
[buildApp] mvn -B clean package  (app)
[INFO] BUILD SUCCESS
[INFO] Total time:  01:03 min
[INFO] No tests to run.
```

`DemoApp` is a single `DemoApplication.java` with no test sources, so
`mvn package` has nothing to execute. The stage still publishes JUnit results
with `allowEmptyResults: true` — on a project with tests it would show them,
here it shows none, and that is the honest number.

### 3. Build, scan, push, delete

```text
[buildImage] build  localhost:5000/eslamnabawy/demoapp:1
localhost:5000/eslamnabawy/demoapp:1 725MB
[buildImage] scan   localhost:5000/eslamnabawy/demoapp:1
Total: 2 (HIGH: 2, CRITICAL: 0)      <- ubuntu 24.04 base
Total: 38 (HIGH: 38, CRITICAL: 0)    <- the Spring Boot jar
[buildImage] push   localhost:5000/eslamnabawy/demoapp:1
1: digest: sha256:6632358ae86f0aad9dc32f229bb790a54cfd33950e48159d1665a813e2541845 size: 856
{"repositories":["eslamnabawy/demoapp","eslamnabawy/ivolveapp"]}
[buildImage] delete the local copy
Untagged: localhost:5000/eslamnabawy/demoapp:1
Deleted: sha256:6632358ae86f0aad9dc32f229bb790a54cfd33950e48159d1665a813e2541845
```

The scan gate is identical to Lab 21's: CRITICAL, fixable, `--exit-code 1`, with
the nine inherited tomcat/spring CVEs triaged in `.trivyignore`. HIGH does not
fail the build — an application this old would never ship otherwise — but it is
counted and archived in `trivy-report.txt`.

### 4. Deploy to Kubernetes

```text
[deployOnK8s] 172.18.0.1:5000/eslamnabawy/demoapp:1 -> Jenkins/Lab22/deployment.yaml
old:           image: eslamnabawy/demoapp:initial
new:           image: 172.18.0.1:5000/eslamnabawy/demoapp:1
namespace/lab22 unchanged
deployment.apps/demoapp created
service/demoapp created
Waiting for deployment "demoapp" rollout to finish: 0 of 1 updated replicas are available...
deployment "demoapp" successfully rolled out
```

```text
NAME                       READY   UP-TO-DATE   AVAILABLE   AGE   IMAGES
deployment.apps/demoapp    1/1     1            1           20s   172.18.0.1:5000/eslamnabawy/demoapp:1

NAME                            READY   STATUS    RESTARTS   AGE   IP                NODE
pod/demoapp-657c885d84-97hfm    1/1     Running   0          20s   192.168.209.104   ivolve-worker2

NAME              TYPE        CLUSTER-IP      PORT(S)   AGE
service/demoapp   ClusterIP   10.96.198.148   80/TCP    20s
```

```text
GET http://127.0.0.1:8089/ -> HTTP 200
```

The image was deleted from the host before the deployment, so this `Running`
pod proves the push worked: the node pulled `demoapp:1` from the registry.

---

## Things worth knowing

1. **A shared library in a subdirectory needs `libraryPath`.** `modernSCM` has a
   `libraryPath` field, but the UI hides it unless you expand the retriever. Point
   it at `Jenkins/Lab22/shared-library` and `vars/*.groovy` resolves as usual —
   no extra repository, no copy step.
2. **`launcher: jnlp` creates the node; Jenkins creates its secret.** There is no
   way to set a known secret from configuration, so the sensible move is to read
   the generated one: `Jenkins.instance.getComputer("<name>").jnlpMac` via
   `/scriptText`. That endpoint needs the same CSRF crumb as any POST.
3. **`numExecutors: 0` is a real test.** With executors on the controller, a
   broken agent silently falls back to "Built-In Node" and the pipeline looks
   fine. Zero executors makes an offline agent a build failure, which is the
   behaviour you actually want to see while learning this.
4. **The agent is not a smaller machine.** It needs the same toolchain as the
   controller (Maven, JDK 17, docker CLI, Trivy, kubectl). Only the Jenkins
   plugins and the remoting client differ. Building it from `inbound-agent`
   instead of `jenkins/jenkins:lts` avoids shipping the Jenkins war and its
   plugins to a machine that only needs to run `sh` steps.
5. **`docker rmi` inside a library step is not a cleanup detail.** It is what
   makes the deployment meaningful: if the image still exists locally, a broken
   push still produces a running pod.
6. **`curl` reads `[ ]` in a Jenkins `tree=` query as a URL glob.** The very first
   run of this lab died silently after the agent connected, because
   `curl "…?tree=computer[displayName,offline]"` exits 3 (`URL malformed`) and
   `set -e` took the script down with it. `curl -g` fixes it. The same trap exists
   in every Jenkins API call that selects fields.
7. **`retentionStrategy: "always"`** keeps an agent from being parked after one
   idle build, which otherwise makes an interactive lab look broken.
8. **The library is versioned with the code it deploys.** `@Library('ivolve-lib@main')`
   pins to `main`, so a Jenkinsfile and the step it calls always come from the
   same commit. Pinning a tag is the production version of the same idea.

---

## Reproduce

```bash
cd ~/iVolve-Tasks/Jenkins/Lab22
bash commands.sh
```

The script is idempotent: registry, containerd trust, namespace, both images,
controller, agent, trigger, verification and cleanup. It expects the Lab 9
cluster (`kind-ivolve`) and the Lab 8 registry to exist — it recreates them if
they do not.

## Clean up

The script removes the controller, the agent, both images and
`~/jenkins-home-lab22` at the end, and leaves the `lab22` namespace with the
running deployment as evidence. To remove that too:

```bash
kubectl --context kind-ivolve delete namespace lab22
```

## Commit

```bash
git add Jenkins/Lab22 && git commit -m "feat(lab22): shared library steps and dedicated Jenkins agent"
```
