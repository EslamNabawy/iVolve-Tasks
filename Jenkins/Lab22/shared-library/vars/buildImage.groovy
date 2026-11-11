/**
 * vars/buildImage.groovy — Lab 22 shared library step.
 *
 * Build, scan, push, then delete the local copy. All four belong together:
 * pushing an image and keeping the local one would let the deployment succeed
 * from a stale local image even when the push was broken.
 *
 * cfg.image       full image reference to build and push
 * cfg.dir         build context (default 'app')
 * cfg.ignoreFile  triage file path, relative to the build context
 * cfg.timeout     Trivy scan timeout (default 30m — the 5m default is too short
 *                 for a fat Spring Boot jar)
 */
def call(Map cfg = [:]) {
    def workDir    = cfg.dir ?: 'app'
    def image      = cfg.image
    def ignoreFile = cfg.ignoreFile ?: ''
    def timeout    = cfg.timeout ?: '30m'

    dir(workDir) {
        echo "[buildImage] build  ${image}"
        sh "docker build -t ${image} ."
        sh "docker images ${image} --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

        if (ignoreFile) {
            sh "cp ${ignoreFile} .trivyignore"
        }
        echo "[buildImage] scan   ${image}"
        sh """
            trivy image --no-progress --timeout ${timeout} --scanners vuln \
              --severity HIGH,CRITICAL --ignore-unfixed \
              --format table -o trivy-report.txt ${image}
            grep -E '^Total:' trivy-report.txt
            trivy image --no-progress --timeout ${timeout} --scanners vuln \
              --severity CRITICAL --ignore-unfixed --exit-code 1 ${image}
        """

        echo "[buildImage] push   ${image}"
        sh "docker push ${image}"
        sh 'curl -s localhost:5000/v2/_catalog'

        echo "[buildImage] delete the local copy"
        sh "docker rmi ${image}"
        sh "docker images ${image} --format '{{.Repository}}:{{.Tag}}' || true"
    }
}
