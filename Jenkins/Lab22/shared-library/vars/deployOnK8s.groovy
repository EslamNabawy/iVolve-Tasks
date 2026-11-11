/**
 * vars/deployOnK8s.groovy — Lab 22 shared library step, extended in Lab 23.
 *
 * Lab 22: rewrite the image tag in the deployment manifest, apply namespace /
 * deployment / service, wait for the rollout.
 *
 * Lab 23: when `gitBranch` is given the step stops talking to the cluster. It
 * rewrites the manifest, commits it and pushes — Argo CD owns the apply. That
 * is the whole difference between CI and GitOps: Jenkins no longer needs
 * cluster credentials to deploy, only a repository it may write to.
 *
 * cfg.image         image reference to write into the manifest
 * cfg.dir           directory holding this repository (default 'repo')
 * cfg.manifest      manifest path inside cfg.dir
 * cfg.namespace     Kubernetes namespace (kubectl mode)
 * cfg.deployment    deployment name (kubectl mode)
 * cfg.gitBranch     push the commit to this branch instead of applying
 */
def call(Map cfg = [:]) {
    def workDir     = cfg.dir ?: 'repo'
    def manifest    = cfg.manifest ?: 'Jenkins/Lab22/deployment.yaml'
    def namespace   = cfg.namespace ?: 'lab22'
    def deployment  = cfg.deployment ?: 'demoapp'
    def gitBranch   = cfg.gitBranch ?: ''

    withEnv([
        "MANIFEST=${manifest}",
        "TARGET_IMAGE=${cfg.image}",
        "K8S_NS=${namespace}",
        "K8S_DEPLOYMENT=${deployment}",
        "GIT_BRANCH=${gitBranch}"
    ]) {
        dir(workDir) {
            echo "[deployOnK8s] ${cfg.image} -> ${manifest}"

            sh '''
                echo "old: $(grep 'image:' $MANIFEST)"
                sed -i "s|^\\( *image:\\).*|\\1 $TARGET_IMAGE|" $MANIFEST
                echo "new: $(grep 'image:' $MANIFEST)"
            '''

            if (gitBranch) {
                sh '''
                    git add "$MANIFEST"
                    git commit -m "ci(lab23): deploy $TARGET_IMAGE" || echo "no change to commit"
                    git push origin "HEAD:refs/heads/$GIT_BRANCH"
                '''
                echo "[deployOnK8s] pushed to ${gitBranch} — Argo CD applies it, Jenkins does not"
            } else {
                sh '''
                    kubectl apply -f Jenkins/Lab22/namespace.yaml
                    kubectl apply -f $MANIFEST
                    kubectl apply -f Jenkins/Lab22/service.yaml
                '''
                sh '''
                    kubectl -n $K8S_NS rollout status deployment/$K8S_DEPLOYMENT --timeout=240s
                    kubectl -n $K8S_NS get pods -o wide
                '''
            }
        }
    }
}
