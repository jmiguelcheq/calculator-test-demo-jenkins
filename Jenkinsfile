pipeline {
  agent {
    docker {
      image 'jenkins/test-runner:java17-node20-chrome'
      args '-v $JENKINS_HOME/.m2:/root/.m2'
      reuseNode true
    }
  }

  options { timestamps(); durabilityHint('PERFORMANCE_OPTIMIZED') }

  // 👇 All default values moved here (no more user input)
  environment {
    APP_REPO = 'jmiguelcheq/calculator-demo-jenkins'
    APP_SHA  = ''   // Leave empty to use REMOTE mode
    CALC_URL = 'https://jmiguelcheq.github.io/calculator-demo-jenkins'
    HEADLESS = 'true'
    BASE_URL = ''   // Will be computed
  }

  stages {
    stage('Checkout (Testing repo)') {
      steps { checkout scm }
    }

    stage('Resolve Test Target') {
      steps {
        script {
          def baseUrl

          if (env.APP_SHA?.trim()) {
            echo "LOCAL mode: cloning ${env.APP_REPO} @ ${env.APP_SHA}"

            sh '''
              set -e
              rm -rf app && mkdir -p app
              git clone "https://github.com/$APP_REPO.git" app
              cd app
              git fetch --all --tags
              git checkout "$APP_SHA"

              # Serve static app from app/src on :8080
              cd src
              if ! command -v http-server >/dev/null 2>&1; then npm i -g http-server >/dev/null 2>&1; fi
              nohup http-server -p 8080 -c-1 --silent > /tmp/http-server.log 2>&1 &
              echo $! > /tmp/http-server.pid

              # Wait for local server to start
              for i in $(seq 1 30); do
                curl -fsS http://127.0.0.1:8080 >/dev/null && break || sleep 1
              done
            '''
            baseUrl = 'http://127.0.0.1:8080'
          } else {
            echo "REMOTE mode: using CALC_URL=${env.CALC_URL}"
            baseUrl = (env.CALC_URL ?: '').trim()
          }

          echo "Resolved BASE_URL = ${baseUrl}"
          if (!baseUrl) { error "BASE_URL is empty. Check CALC_URL or LOCAL app server." }

          // Persist for next stage
          writeFile file: 'BASE_URL.txt', text: baseUrl
          currentBuild.description = "BASE_URL=${baseUrl}"
        }
      }
    }

    stage('Build & Run Tests') {
      steps {
        script {
          def base = fileExists('BASE_URL.txt') ? readFile('BASE_URL.txt').trim() : ''
          if (!base) { error 'BASE_URL is empty at test stage.' }

          withEnv(["BASE_URL=${base}", "HEADLESS=${env.HEADLESS}"]) {
            sh '''
              set -e
              echo "Using BASE_URL=$BASE_URL HEADLESS=$HEADLESS"
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

          // Generate Allure single-file report
          sh '''
            set +e
            if [ -d target/allure-results ] || ls -d **/allure-results >/dev/null 2>&1; then
              PATH_TO_RESULTS="target/allure-results"
              [ -d "$PATH_TO_RESULTS" ] || PATH_TO_RESULTS="$(ls -d **/allure-results | head -n1)"
              echo "Generating Allure single-file report from: $PATH_TO_RESULTS"
              allure generate "$PATH_TO_RESULTS" --single-file --clean -o target/allure-single || true
            else
              echo "No allure-results found; skipping report generation."
            fi
          '''

          // Archive artifacts (JUnit + Allure reports)
          archiveArtifacts artifacts: '''
            **/target/surefire-reports/**,
            **/target/cucumber-reports/**,
            target/allure-single/**,
            **/target/allure-results/**
          '''.trim(), allowEmptyArchive: true

          // Optional: Uncomment if you want HTML report in Jenkins UI
          // publishHTML(target: [
          //   reportDir: 'target/allure-single',
          //   reportFiles: 'index.html',
          //   reportName: 'Allure Report',
          //   keepAll: true,
          //   allowMissing: true,
          //   alwaysLinkToLastBuild: true
          // ])
        }
      }
    }
  }

  post {
    always {
      // Stop local server if running
      sh '''
        if [ -f /tmp/http-server.pid ]; then
          kill "$(cat /tmp/http-server.pid)" 2>/dev/null || true
          rm -f /tmp/http-server.pid
        fi
      '''
    }
  }
}
