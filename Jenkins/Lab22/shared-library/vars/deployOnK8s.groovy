/**
 * vars/deployOnK8s.groovy — Lab 22 shared library step.
 *
 * Rewrite the image tag in the deployment manifest, apply namespace /
 * deployment / service, and wait for the rollout. In Lab 23 this step also
 * commits the rewritten manifest back to GitHub so Argo CD can pick it up.
 *
 * cfg.image         image reference to write into the manifest
 * cfg.dir           directory holding this repository (default 'repo')
 * cfg.manifest      manifest path inside cfg.dir
 * cfg.namespace     Kubernetes namespace
 * cfg.deployment    deployment name
 */
def call(Map cfg = [:]) {
    def workDir     = cfg.dir ?: 'repo'
    def manifest    = cfg.manifest ?: 'Jenkins/Lab22/deployment.yaml'
    def namespace   = cfg.namespace ?: 'lab22'
    def deployment  = cfg.deployment ?: 'demoapp'

    withEnv([
        "MANIFEST=${manifest}",
        "TARGET_IMAGE=${cfg.image}",
        "K8S_NS=${namespace}",
        "K8S_DEPLOYMENT=${deployment}"
    ]) {
        dir(workDir) {
            echo "[deployOnK8s] ${cfg.image} -> ${manifest}"

            sh '''
                echo "old: $(grep 'image:' $MANIFEST)"
                sed -i "s|^\\( *image:\\).*|\\1 $TARGET_IMAGE|" $MANIFEST
                echo "new: $(grep 'image:' $MANIFEST)"
            '''

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
