# Lab 23: GitOps with Argo CD

> **Deck task:** install Argo CD in the cluster, log in to its UI, connect it to
> the GitHub repository, create an Application that watches the repository and a
> manifest directory, enable automatic sync, extend the `DeployOnK8s` Jenkins
> step so it pushes the edited deployment file back to GitHub, then run the
> pipeline and confirm that Argo CD notices and syncs the change.

## What it asks for

- [x] Argo CD installed **in the cluster** (`kind-ivolve`), not on the host
- [x] UI reachable and a login obtained
- [x] Argo CD connected to `https://github.com/EslamNabawy/iVolve-Tasks.git`
- [x] An Application named `ivolve` watching a manifest directory
- [x] Automatic sync enabled (prune + self-heal)
- [x] `DeployOnK8s` changed: it now **pushes** the edited manifest to GitHub
- [x] Pipeline run confirms Argo CD detected the change and synced it

## The idea in one paragraph

Lab 22's pipeline ended with `kubectl apply`. That works, but it means the
pipeline holds cluster credentials, and the cluster's real state lives in
Jenkins' memory of what it once applied, the repository does not describe the
cluster. Lab 23 removes `kubectl` from the pipeline completely. Jenkins builds
and pushes the image, writes the new tag into a manifest that is **in Git**, and
pushes a commit. Argo CD watches that branch, compares it with the live cluster
and applies the difference. The cluster's desired state is now a file with a
commit hash behind it, and the pipeline needs no cluster credentials at all.

```
Jenkins: build → scan → push image → edit manifest → git commit + push
                                                          │
                                        GitHub branch `gitops`
                                                          │  (Argo CD polls)
                                                   Argo CD sync
                                                          ↓
                                            namespace lab23 ← kind-ivolve
```

---

## 1. Install Argo CD in the cluster

The official manifest cannot be applied the usual way. Its `ApplicationSet` CRD
annotation is larger than the 262 KB that `kubectl apply` stores in
`kubectl.kubernetes.io/last-applied-configuration`:

```
The CustomResourceDefinition "applicationsets.argoproj.io" is invalid:
metadata.annotations: Too long: must have at most 262144 bytes
```

`--server-side` does not write that annotation, and `--force-conflicts` settles
the field-manager clash on the CRDs:

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=600s
```

```
deployment "argocd-server" successfully rolled out
NAME                                                READY   STATUS    RESTARTS      AGE
argocd-application-controller-0                     1/1     Running   2 (23m ago)   68m
argocd-applicationset-controller-794bb95c9d-v5q7g   1/1     Running   2 (23m ago)   68m
argocd-dex-server-66cf64bfcf-svgz9                  1/1     Running   2 (23m ago)   68m
argocd-notifications-controller-5878c8d644-5865j    1/1     Running   2 (23m ago)   68m
argocd-redis-5869b7547-pzmlx                        1/1     Running   1 (28m ago)   68m
argocd-repo-server-7d55cc466b-mqpd2                 1/1     Running   2 (23m ago)   68m
argocd-server-85b849c688-bq4cp                      1/1     Running   2 (23m ago)   68m
argocd-server                      quay.io/argoproj/argocd:v3.6.1
```

The `RESTARTS` counts are from the WSL crash recorded in this session, not from
the installation, the pods were recreated when the cluster came back.

## 2. The UI and a login

`argocd-server` is a ClusterIP Service, so the UI is reached through a
port-forward, the same technique used for Grafana in Lab 18:

```bash
kubectl -n argocd port-forward svc/argocd-server 8443:443 &
curl -sk -o /dev/null -w 'HTTP %{http_code}\n' https://127.0.0.1:8443/
```

```
GET https://127.0.0.1:8443/ -> HTTP 200
login token: eyJhbGciOiJI... (257 chars)
```

The initial password is generated at install time and stored in a Secret. The
token above came from `POST /api/v1/session` with that password, which is what
the UI's login form does:

```bash
ARGOPASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)
curl -sk https://127.0.0.1:8443/api/v1/session -H 'Content-Type: application/json' \
  -d "{\"username\":\"admin\",\"password\":\"$ARGOPASS\"}"
```

## 3. Connect Argo CD to GitHub, the Application

An `Application` is the link between a Git path and a namespace. Nothing is
copied into the cluster by hand; this object is the only thing that says "the
repository is the source of truth".

```yaml
source:
  repoURL: https://github.com/EslamNabawy/iVolve-Tasks.git
  targetRevision: gitops
  path: Jenkins/Lab23/manifests
destination:
  server: https://kubernetes.default.svc
  namespace: lab23
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

Three deliberate choices:

| Choice | Why |
|---|---|
| Branch `gitops`, not `main` | CI commits its own changes; `main` stays the human-authored history, and every automatic commit is isolated and easy to inspect or discard |
| Directory `Jenkins/Lab23/manifests` | Argo CD applies a directory, so this is the whole desired state of the app, one Deployment, one Service |
| `prune` + `selfHeal` | Manual edits and orphaned objects are reverted; the lab proves the repository wins |

The repository is public, so Argo CD needs no credentials to read it. The first
sync happened within seconds of `kubectl apply -f application.yaml`:

```
NAME     SYNC STATUS   HEALTH STATUS
ivolve   Synced        Healthy
```

## 4. The change to `DeployOnK8s`

The shared library from Lab 22 gained one parameter and one branch:

```groovy
if (gitBranch) {
    sh '''
        git add "$MANIFEST"
        git commit -m "ci(lab23): deploy $TARGET_IMAGE" || echo "no change to commit"
        git push origin "HEAD:refs/heads/$GIT_BRANCH"
    '''
} else {
    // Lab 22 behaviour: kubectl apply, rollout status
}
```

With `gitBranch` set, the step rewrites `image:` in the manifest, commits and
pushes, and never calls `kubectl`. Lab 22's pipeline is untouched: it simply
does not pass the parameter.

The credential is a Jenkins `usernamePassword` entry fed from the `gh` CLI's
token, so the token appears neither in the Jenkinsfile nor in Git.

## 5. Results

Pipeline, build #1, `SUCCESS`:

```
build tag: 20261112-014221
old:           image: 172.18.0.1:5000/eslamnabawy/demoapp:c88337f
new:           image: 172.18.0.1:5000/eslamnabawy/demoapp:20261112-014221
[gitops 2e0a472] ci(lab23): deploy 172.18.0.1:5000/eslamnabawy/demoapp:20261112-014221
 1 file changed, 1 insertion(+), 1 deletion(-)
To https://github.com/EslamNabawy/iVolve-Tasks.git
   eeb5337..2e0a472  HEAD -> gitops
[deployOnK8s] pushed to gitops — Argo CD applies it, Jenkins does not
```

The build pushed a commit, not a Deployment. Argo CD then moved on its own 
the wait loop prints the revision it reports every few seconds:

```
sync=Synced health=Healthy     revision=eeb5337      ← before the push
sync=Synced health=Progressing revision=2e0a472      ← new commit detected
sync=Synced health=Progressing revision=2e0a472
sync=Synced health=Healthy     revision=2e0a472      ← rollout finished
```

Final state, read back from the cluster and from GitHub:

```
--- argo application ---
NAME     SYNC STATUS   HEALTH STATUS
ivolve   Synced        Healthy
Synced|Healthy|2e0a47219f791ab07dd35ec5cccc032b5e70abcf|Succeeded

--- resources argo tracks ---
Service demoapp Synced
Deployment demoapp Synced

--- live cluster ---
172.18.0.1:5000/eslamnabawy/demoapp:20261112-014221
demoapp-5557974b59-drh82   1/1   Running   0   71s   192.168.209.107   ivolve-worker2

--- registry ---
{"name":"eslamnabawy/demoapp","tags":["c88337f","1","20261112-014221"]}

--- git branch ---
2e0a472 ci(lab23): deploy 172.18.0.1:5000/eslamnabawy/demoapp:20261112-014221
eeb5337 ci(lab23): deploy 172.18.0.1:5000/eslamnabawy/demoapp:c88337f
1b4a949 feat(lab23): Argo CD application and GitOps push in deployOnK8s
```

And the app itself, through the Service:

```
deployment "demoapp" successfully rolled out
service/demoapp   ClusterIP   10.96.234.221   <none>   80/TCP
GET http://127.0.0.1:8090/ -> HTTP 200
```

## 6. Argo CD wins: `selfHeal` in six seconds

The fastest way to show that Git, not `kubectl`, owns the cluster, overwrite
the image by hand:

```
--- selfHeal check: manual image edit is reverted ---
eslamnabawy/demoapp:initial  <- immediately after kubectl set image
reverted after ~6s: 172.18.0.1:5000/eslamnabawy/demoapp:20261112-014221
```

---

## What I'd do differently

1. **`--server-side` is not optional for the Argo CD install.** The CRD
   annotations exceed `kubectl apply`'s 262 KB client-side limit. The error names
   `applicationsets.argoproj.io` and reads like a manifest bug; it is a
   client-side limit.
2. **A stopped container is invisible to `docker ps`.** The Lab 8 registry
   survived a WSL restart as a *stopped* container. The "create it if missing"
   check passed, `docker run` then failed with a name conflict, and `set -e`
   ended the script before anything useful ran. The check is now `docker ps -a`
   plus `docker start`.
3. **A tag derived from the commit deadlocks a GitOps loop.** One run rebuilt
   the same tag, so the manifest did not change, so there was no commit, so Argo
 CD had nothing to sync, a green pipeline that proved nothing. The tag is now
   `date +%Y%m%d-%H%M%S`, computed inside the build stage.
4. **`read` in a `while` loop breaks `set -e`.** `read -r S H < <(kubectl …)`
   returns non-zero at EOF and ends the script right after the interesting part.
   The wait loop compares `git rev-parse origin/gitops` with Argo's
   `.status.sync.revision` instead.
5. **The pipeline never contacts the cluster.** It has no kubeconfig mounted in
   the GitOps branch of `deployOnK8s`; the push is the only side effect. That is
 the security argument for GitOps: the token can be scoped to one repository
   while a kubeconfig is a cluster key.
6. **Argo CD polls; it does not watch GitHub.** The default reconcile interval
   is three minutes. `kubectl annotate application ivolve
 argocd.argoproj.io/refresh=normal` forces a check, which is why the wait loop
   finishes in seconds. A GitHub webhook would be the production answer.
7. **The Application is namespaced but cluster-wide in effect.** It lives in
   `argocd`, yet it creates and prunes objects in `lab23`; `syncOptions:
   CreateNamespace=true` is what lets it create that namespace.
8. **CI commits land in the repository's history.** They go to `gitops`, not
 `main`, so the authored history stays clean, but they are real commits
   visible in `git log origin/gitops`, one per build.

## To replay this

```bash
cd ~/iVolve-Tasks/Jenkins/Lab23
./commands.sh
```

The script makes sure Argo CD is installed, creates the `gitops` branch, applies
the Application, builds the controller image, runs the pipeline, waits for the
sync, runs the `selfHeal` check, and stops. Argo CD and the Application stay
installed. They are the result of the lab.

## Clean up

```bash
kubectl -n argocd delete application ivolve
kubectl delete namespace argocd lab23
```

## Record it in git

```bash
git add Jenkins/Lab23 Jenkins/Lab22/shared-library/vars/deployOnK8s.groovy
git commit -m "feat(lab23): Argo CD application and GitOps push from the pipeline"
```
