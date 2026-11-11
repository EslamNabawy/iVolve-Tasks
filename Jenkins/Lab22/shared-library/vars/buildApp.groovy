/**
 * vars/buildApp.groovy — Lab 22 shared library step.
 *
 * Unit test + package the application. `mvn clean package` runs the test phase
 * before packaging, so a failing unit test stops the pipeline here.
 */
def call(Map cfg = [:]) {
    def workDir = cfg.dir ?: 'app'
    dir(workDir) {
        echo "[buildApp] mvn -B clean package  (${workDir})"
        sh 'mvn -B clean package'
        sh 'ls -l target/*.jar'
        junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
    }
}
