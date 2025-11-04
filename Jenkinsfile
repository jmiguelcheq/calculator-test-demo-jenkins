pipeline {
  agent {
    docker {
      image 'jenkins/test-runner:java17-node20-chrome'
      args '-v $JENKINS_HOME/.m2:/root/.m2'
      reuseNode true
    }
  }

  options { timestamps(); durabilityHint('PERFORMANCE_OPTIMIZED') }

  parameters {
    string(name: 'APP_REPO', defaultValue: 'jmiguelcheq/calculator-demo-jenkins',
           description: 'GitHub app repo to pull if testing a specific SHA (LOCAL mode).')
    string(name: 'APP_SHA',  defaultValue: '',
           description: 'When set, we clone app repo at this SHA and serve locally on :8080.')
    string(name: 'CALC_URL', defaultValue: 'https://jmiguelcheq.github.io/calculator-demo-jenkins',
           description: 'Public URL to test when APP_SHA is empty (REMOTE mode).')
    booleanParam(name: 'HEADLESS', defaultValue: true, description: 'Run browser headless')
  }

  environment {
    BASE_URL = ''  // computed, but we'll hand-off via file for reliability
  }

  stages {
    stage('Checkout (Testing repo)') {
      steps { checkout scm }
    }

    stage('Resolve Test Target') {
      steps {
        script {
          def baseUrl
          if (params.APP_SHA?.trim()) {
            echo "LOCAL mode: cloning ${params.APP_REPO} @ ${params.APP_SHA}"
            withEnv(["APP_REPO=${params.APP_REPO}", "APP_SHA=${params.APP_SHA}"]) {
              sh '''
                set -e
                rm -rf app && mkdir -p app
                git clone "https://github.com/$APP_REPO.git" app
                cd app
                git fetch --all --tags
                git checkout "$APP_SHA"

                # serve static app from app/src on :8080
                cd src
                if ! command -v http-server >/dev/null 2>&1; then npm i -g http-server >/dev/null 2>&1; fi
                nohup http-server -p 8080 -c-1 --silent > /tmp/http-server.log 2>&1 &
                echo $! > /tmp/http-server.pid
                for i in $(seq 1 30); do
                  curl -fsS http://127.0.0.1:8080 >/dev/null && break || sleep 1
                done
              '''
            }
            baseUrl = 'http://127.0.0.1:8080'
          } else {
            echo "REMOTE mode: using CALC_URL=${params.CALC_URL}"
            baseUrl = (params.CALC_URL ?: '').trim()
          }

          echo "Resolved BASE_URL(computed) = ${baseUrl}"
          if (!baseUrl) { error "BASE_URL is empty. Check CALC_URL parameter or LOCAL server." }

          // Hand-off across CPS/Docker boundaries safely
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

          withEnv(["BASE_URL=${base}", "HEADLESS=${params.HEADLESS.toString()}"]) {
            sh '''
              set -e
              echo "Using BASE_URL=$BASE_URL HEADLESS=$HEADLESS"
              printenv | grep -E 'BASE_URL|HEADLESS' || true
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

          // Generate Allure single-file (inside the container)
          sh '''
            set +e
            if [ -d target/allure-results ] || ls -d **/allure-results >/dev/null 2>&1; then
              PATH_TO_RESULTS="target/allure-results"
              [ -d "$PATH_TO_RESULTS" ] || PATH_TO_RESULTS="$(ls -d **/allure-results | head -n1)"
              echo "Generating Allure single-file from: $PATH_TO_RESULTS"
              allure generate "$PATH_TO_RESULTS" --single-file --clean -o target/allure-single || true
            else
              echo "No allure-results found; skipping single-file generation."
            fi
          '''

          // Keep artifacts (XMLs + Allure single-file + raw results)
          archiveArtifacts artifacts: '''
            **/target/surefire-reports/**,
            **/target/cucumber-reports/**,
            target/allure-single/**,
            **/target/allure-results/**
          '''.trim(), allowEmptyArchive: true

          // OPTIONAL: publish the single-file HTML in Jenkins UI (install "HTML Publisher" plugin)
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
      sh '''
        if [ -f /tmp/http-server.pid ]; then
          kill "$(cat /tmp/http-server.pid)" 2>/dev/null || true
          rm -f /tmp/http-server.pid
        fi
      '''
    }
  }
}
