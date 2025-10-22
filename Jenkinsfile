pipeline {
  agent {
    docker {
      image 'maven:3.9-eclipse-temurin-21'
      args '-v $JENKINS_HOME/.m2:/root/.m2'
    }
  }
  options {
    timestamps()
    durabilityHint('PERFORMANCE_OPTIMIZED')
  }
  triggers { /* multibranch handles webhooks; keep empty */ }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Build & Test') {
      steps {
        sh 'mvn -B -q clean test'
      }
      post {
        always {
          // Publish JUnit
          junit allowEmptyResults: true, testResults: '*/target/surefire-reports/*.xml, target/surefire-reports/*.xml'
          // Publish Allure (if you have Allure plugin)
          script {
            def hasAllure = fileExists('target/allure-results') || sh(script: 'ls -d **/allure-results 2>/dev/null | head -n1', returnStatus: true) == 0
            if (hasAllure) {
              // Try top-level first, else first match
              if (fileExists('target/allure-results')) {
                allure includeProperties: false, jdk: '', results: [[path: 'target/allure-results']]
              } else {
                def rel = sh(script: 'ls -d **/allure-results | head -n1', returnStdout: true).trim()
                allure includeProperties: false, jdk: '', results: [[path: rel]]
              }
            }
          }
          archiveArtifacts artifacts: 'target/**, **/target/**', allowEmptyArchive: true
        }
      }
    }
  }
}
