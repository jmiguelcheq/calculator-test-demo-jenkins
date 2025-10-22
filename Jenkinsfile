/**
 * Jenkinsfile — Testing Repo (tests runner)
 * Runs UI/API tests, publishes JUnit (and optional Allure), returns pass/fail to the caller.
 *
 * Requirements:
 *  - Maven
 *  - If using Allure: Allure Jenkins plugin; tests must produce target/allure-results
 */

pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }

  parameters {
    string(name: 'UPSTREAM_BUILD_URL', defaultValue: '', description: 'Link to upstream App build (for traceability)')
    string(name: 'UPSTREAM_REPO',      defaultValue: '', description: 'Upstream repo name')
    string(name: 'UPSTREAM_SHA',       defaultValue: '', description: 'Upstream commit SHA')
  }

  environment {
    // Put any env vars needed by your tests here, e.g. BASE_URL, BROWSER, etc.
  }

  stages {
    stage('Checkout Tests') {
      steps { checkout scm }
    }

    stage('Prepare Dependencies') {
      steps {
        script {
          // If you need drivers/browsers/npm, install/configure here.
          echo "Preparing dependencies..."
        }
      }
    }

    stage('Run Tests') {
      steps {
        script {
          // Adjust to your stack; this assumes Maven
          if (isUnix()) {
            sh 'mvn -q -DskipTests=false test'
          } else {
            bat 'mvn -q -DskipTests=false test'
          }
        }
      }
      post {
        always {
          junit '**/target/surefire-reports/*.xml'
          // If using Allure and results exist, uncomment:
          // allure includeProperties: false, results: [[path: 'target/allure-results']]
        }
      }
    }
  }

  post {
    success { echo "Tests PASSED. Upstream: ${params.UPSTREAM_REPO} @ ${params.UPSTREAM_SHA}" }
    failure { echo "Tests FAILED. Upstream: ${params.UPSTREAM_REPO} @ ${params.UPSTREAM_SHA}" }
  }
}
