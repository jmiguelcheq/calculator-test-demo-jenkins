pipeline {
  agent {
    docker {
      image 'jenkins/test-runner:java17-node20-chrome'
      args '-v $JENKINS_HOME/.m2:/root/.m2'
      reuseNode true
    }
  }

  options {
    timestamps()
    durabilityHint('PERFORMANCE_OPTIMIZED')
  }

  parameters {
    string(name: 'APP_REPO', defaultValue: 'jmiguelcheq/calculator-demo-jenkins',
           description: 'GitHub app repo to pull if testing a specific SHA (LOCAL mode).')
    string(name: 'APP_SHA', defaultValue: '',
           description: 'When set, we clone app repo at this SHA and serve locally on :8080.')
    string(name: 'CALC_URL', defaultValue: 'https://jmiguelcheq.github.io/calculator-demo',
           description: 'Public URL to test when APP_SHA is empty (REMOTE mode).')
    booleanParam(name: 'HEADLESS', defaultValue: true, description: 'Run browser headless')
  }

  environment {
    BASE_URL = ''
  }

  stages {
    stage('Checkout (Testing repo)') {
      steps { checkout scm }
    }

    stage('Resolve Test Target') {
      steps {
        script {
          if (params.APP_SHA?.trim()) {
            echo "LOCAL mode: cloning ${params.APP_REPO} @ ${params.APP_SHA}"
            // No shell $()-style expansions here, so double quotes are OK
            sh """
              rm -rf app && mkdir -p app
              git clone https://github.com/${params.APP_REPO}.git app
              cd app
              git fetch --all --tags
              git checkout ${params.APP_SHA}
            """
            // Start local server – has $! and $(...) → use triple-single quotes
            sh '''
              set -e
              cd app/src
              nohup http-server -p 8080 -c-1 --silent > /tmp/http-server.log 2>&1 &
              echo $! > /tmp/http-server.pid
              for i in $(seq 1 20); do
                curl -fsS http://127.0.0.1:8080 >/dev/null && break || sleep 1
              done
            '''
            env.BASE_URL = 'http://127.0.0.1:8080'
          } else {
            echo "REMOTE mode: using CALC_URL=${params.CALC_URL}"
            env.BASE_URL = params.CALC_URL
          }
        }
      }
    }

    stage('Show resolved BASE_URL') {
      steps { echo "BASE_URL=${env.BASE_URL}" }
    }

    stage('Build & Run Tests') {
      steps {
        // Use shell env ($BASE_URL, $HEADLESS). Pass HEADLESS in via withEnv.
        script {
          withEnv(["HEADLESS=${params.HEADLESS}"]) {
            sh '''
              set -e
              mvn -B clean test \
                -DbaseUrl="$BASE_URL" \
                -Dheadless="$HEADLESS"
            '''
          }
        }
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '*/target/surefire-reports/*.xml, target/surefire-reports/*.xml'

          sh '''
            set +e
            if [ -d target/allure-results ] || ls -d **/allure-results >/dev/null 2>&1; then
              PATH_TO_RESULTS="target/allure-results"
              if [ ! -d "$PATH_TO_RESULTS" ]; then
                PATH_TO_RESULTS="$(ls -d **/allure-results | head -n1)"
              fi
              echo "Generating Allure single-file from: $PATH_TO_RESULTS"
              allure generate "$PATH_TO_RESULTS" --single-file --clean -o target/allure-single || true
            else
              echo "No allure-results found; skipping single-file generation."
            fi
          '''

          script {
            def hasAllure = fileExists('target/allure-results') ||
                            sh(script: 'ls -d **/allure-results 2>/dev/null | head -n1', returnStatus: true) == 0
            if (hasAllure) {
              def path = fileExists('target/allure-results') ? 'target/allure-results'
                                                             : sh(script: 'ls -d **/allure-results | head -n1', returnStdout: true).trim()
              allure includeProperties: false, jdk: '', results: [[path: path]]
            }
          }

          archiveArtifacts artifacts: '''
            **/target/surefire-reports/**,
            **/target/cucumber-reports/**,
            target/allure-single/**,
            **/target/allure-results/**
          '''.trim(), allowEmptyArchive: true
        }
      }
    }
  }

  post {
    always {
      sh '''
        if [ -f /tmp/http-server.pid ]; then
          kill "$(cat /tmp/http-server.pid)" 2>/dev/null || true
          rm -f /tmp/http-server.pid
        fi
      '''
    }
  }
}
