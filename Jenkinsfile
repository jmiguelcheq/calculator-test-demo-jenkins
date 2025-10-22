pipeline {
  agent {
    docker {
      image 'jenkins/test-runner:java17-node20-chrome'
      // share Maven cache with Jenkins for speed
      args '-v $JENKINS_HOME/.m2:/root/.m2'
      reuseNode true
    }
  }

  options {
    timestamps()
    durabilityHint('PERFORMANCE_OPTIMIZED')
  }

  // Parameters so the App pipeline can pass SHA (LOCAL mode) or we can run standalone (REMOTE mode)
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
    // Base URL resolves per mode (LOCAL vs REMOTE)
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
            // LOCAL mode → serve the app built files under app/src with http-server
            echo "LOCAL mode: cloning ${params.APP_REPO} @ ${params.APP_SHA}"
            sh """
              rm -rf app && mkdir -p app
              git clone https://github.com/${params.APP_REPO}.git app
              cd app
              git fetch --all --tags
              git checkout ${params.APP_SHA}
            """
            // Start local server (background) from app/src like in your GA workflow
            sh """
              set -e
              cd app/src
              nohup http-server -p 8080 -c-1 --silent > /tmp/http-server.log 2>&1 &
              echo $! > /tmp/http-server.pid
              # wait until healthy
              for i in \$(seq 1 20); do
                curl -fsS http://127.0.0.1:8080 >/dev/null && break || sleep 1
              done
            """
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
        // Your Maven command from GA with system properties
        sh """
          set -e
          mvn -B clean test \\
            -DbaseUrl="${BASE_URL}" \\
            -Dheadless="${params.HEADLESS}"
        """
      }
      post {
        always {
          // JUnit (allow empty in case only Cucumber JSON is produced)
          junit allowEmptyResults: true, testResults: '*/target/surefire-reports/*.xml, target/surefire-reports/*.xml'

          // Generate Allure single-file (same as GA)
          sh '''
            set +e
            if [ -d target/allure-results ] || ls -d **/allure-results >/dev/null 2>&1; then
              # prefer top-level, else first match
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

          // Publish Allure (plugin) if results exist (optional)
          script {
            def hasAllure = fileExists('target/allure-results') ||
                            sh(script: 'ls -d **/allure-results 2>/dev/null | head -n1', returnStatus: true) == 0
            if (hasAllure) {
              def path = fileExists('target/allure-results') ? 'target/allure-results'
                                                             : sh(script: 'ls -d **/allure-results | head -n1',
                                                                  returnStdout: true).trim()
              allure includeProperties: false, jdk: '', results: [[path: path]]
            }
          }

          // Keep artifacts (XMLs + Allure single-file) for inspection
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
      // Stop local server if it was started
      sh '''
        if [ -f /tmp/http-server.pid ]; then
          kill "$(cat /tmp/http-server.pid)" 2>/dev/null || true
          rm -f /tmp/http-server.pid
        fi
      '''
    }
  }
}
