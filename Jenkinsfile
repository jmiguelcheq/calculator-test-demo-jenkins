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
    string(name: 'APP_REPO', defaultValue: 'jmiguelcheq/calculator-demo-jenkins', description: 'owner/repo to clone in LOCAL mode (when APP_SHA is set)')
    string(name: 'APP_SHA',  defaultValue: '', description: 'commit SHA to test locally; leave empty to use CALC_URL (REMOTE mode)')
    string(name: 'CALC_URL', defaultValue: 'https://jmiguelcheq.github.io/calculator-demo-jenkins', description: 'Public URL to test when APP_SHA is empty')
    booleanParam(name: 'HEADLESS', defaultValue: true, description: 'Run browser headless')
  }

  environment {
    BASE_URL = ''
  }

  stages {
    stage('Checkout (Testing repo)') {
      steps { checkout scm }
    }

    stage('CI Permissions') {
      steps {
        sh '''
          set -eu
          [ -f ci/push_to_loki.sh ] && chmod +x ci/push_to_loki.sh || true
          [ -f ci/summarize_tests.sh ] && chmod +x ci/summarize_tests.sh || true
        '''
      }
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

                SITE_ROOT=""
                for d in docs dist src; do
                  if [ -d "$d" ]; then SITE_ROOT="$d"; break; fi
                done
                if [ -z "$SITE_ROOT" ]; then echo "❌ No site root (docs/dist/src)"; exit 2; fi
                echo "✅ Serving from: $SITE_ROOT"
                cd "$SITE_ROOT"

                if ! command -v http-server >/dev/null 2>&1; then npm i -g http-server >/dev/null 2>&1; fi
                nohup http-server -p 8080 -c-1 --silent > /tmp/http-server.log 2>&1 &
                echo $! > /tmp/http-server.pid

                for i in $(seq 1 30); do curl -fsS http://127.0.0.1:8080 >/dev/null && break || sleep 1; done
              '''
            }
            baseUrl = 'http://127.0.0.1:8080'
          } else {
            echo "REMOTE mode: using CALC_URL=${params.CALC_URL}"
            baseUrl = (params.CALC_URL ?: '').trim()
          }
          if (!baseUrl) { error "BASE_URL is empty. Provide CALC_URL or APP_SHA." }
          writeFile file: 'BASE_URL.txt', text: baseUrl
          currentBuild.description = "BASE_URL=${baseUrl}"
        }
      }
    }

    stage('Build & Run Tests') {
      steps {
        script {
          def base = fileExists('BASE_URL.txt') ? readFile('BASE_URL.txt').trim() : ''
          if (!base) { error 'BASE_URL missing at test stage.' }
          withEnv(["BASE_URL=${base}", "HEADLESS=${params.HEADLESS.toString()}"]) {
            sh '''
              set -e
              echo "Using BASE_URL=$BASE_URL  HEADLESS=$HEADLESS"
              mvn -B clean test -DbaseUrl="$BASE_URL" -Dheadless="$HEADLESS"
            '''
          }
        }
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: '*/target/surefire-reports/*.xml, target/surefire-reports/*.xml'

          // Optional: install zip to quiet logs
          sh '''
bash -eu -c "
  if ! command -v zip >/dev/null 2>&1; then
    if   command -v apt-get >/dev/null 2>&1; then apt-get update -y && apt-get install -y zip >/dev/null 2>&1 || true;
    elif command -v apk     >/dev/null 2>&1; then apk add --no-cache zip >/dev/null 2>&1 || true;
    elif command -v yum     >/dev/null 2>&1; then yum install -y zip >/dev/null 2>&1 || true;
    fi
  fi
"
'''

          // Allure single-file + full report (for widgets/summary.json)
          sh '''
            set +e
            mkdir -p target
            if [ -d target/allure-results ] || ls -d **/allure-results >/dev/null 2>&1; then
              PATH_TO_RESULTS="target/allure-results"
              [ -d "$PATH_TO_RESULTS" ] || PATH_TO_RESULTS="$(ls -d **/allure-results | head -n1)"

              echo "Generating Allure single-file..."
              allure generate "$PATH_TO_RESULTS" --single-file --clean -o target/allure-single || true
              cp -f target/allure-single/index.html target/allure-report.html || true
              (cd target && zip -q -9 allure-report.zip allure-report.html) || true

              echo "Generating Allure full report (summary.json)…"
              allure generate "$PATH_TO_RESULTS" -o target/allure-report || true
            else
              echo "No allure-results found; skipping Allure generation."
            fi
          '''

          archiveArtifacts artifacts: '''
            target/allure-single/**,
            **/target/allure-results/**,
            target/allure-report/widgets/summary.json
          '''.trim(), allowEmptyArchive: true
        }
      }
    }

    // -------- Loki publish (all jq usage is inside ONE bash block) --------
    stage('Loki: Publish Test Summary') {
      steps {
        script {
          def statusVal = currentBuild?.currentResult ?: 'SUCCESS'
          withCredentials([
            string(credentialsId: 'grafana-loki-url', variable: 'LOKI_URL'),
            usernamePassword(credentialsId: 'grafana-loki-basic', passwordVariable: 'LOKI_TOKEN', usernameVariable: 'LOKI_USER')
          ]) {
            withEnv(["STATUS=${statusVal}"]) {
              sh '''
bash -eu -c "
  # Ensure jq
  if ! command -v jq >/dev/null 2>&1; then
    if   command -v apt-get >/dev/null 2>&1; then apt-get update -y && apt-get install -y jq >/dev/null 2>&1 || true;
    elif command -v apk     >/dev/null 2>&1; then apk add --no-cache jq >/dev/null 2>&1 || true;
    elif command -v yum     >/dev/null 2>&1; then yum install -y jq >/dev/null 2>&1 || true;
    fi
  fi

  # Summarize tests (fallback to zeros with VALID JSON)
  if ! ./ci/summarize_tests.sh > /tmp/test_summary.json 2>/dev/null; then
    echo '{\"total\":0,\"passed\":0,\"failed\":0,\"skipped\":0,\"duration_ms\":0}' > /tmp/test_summary.json
  fi
  cat /tmp/test_summary.json

  # Build labels & extras (JSON), *after* jq is available
  STREAM_LABELS=$(jq -n --arg job \\"calculator-tests\\" \
                        --arg repo \\"${GIT_URL:-unknown}\\" \
                        --arg branch \\"${BRANCH_NAME:-unknown}\\" \
                        --arg build \\"${BUILD_NUMBER}\\" \
                        --arg status \\"${STATUS}\\" \
                        '{job:$job,repo:$repo,branch:$branch,build:$build,status:$status}')
  export STREAM_LABELS

  EXTRA_FIELDS=$(jq -c '. + {
    build_url: env.BUILD_URL,
    commit: env.GIT_COMMIT,
    node: env.NODE_NAME
  }' /tmp/test_summary.json)
  export EXTRA_FIELDS

  LOG_MESSAGE=\\"Cucumber/Allure test summary for build ${BUILD_NUMBER}\\"
  export LOG_MESSAGE

  ./ci/push_to_loki.sh
"
'''
            }
          }
        }
      }
      post {
        always {
          withCredentials([
            string(credentialsId: 'grafana-loki-url', variable: 'LOKI_URL'),
            usernamePassword(credentialsId: 'grafana-loki-basic', passwordVariable: 'LOKI_TOKEN', usernameVariable: 'LOKI_USER')
          ]) {
            sh '''
bash -eu -c "
  # Best-effort console tail (path may differ by Jenkins setup)
  TAIL='no console tail'
  if [ -f \\"$WORKSPACE/../${JOB_NAME}@tmp/log\\" ]; then
    TAIL=\\"$(tail -n 120 \\"$WORKSPACE/../${JOB_NAME}@tmp/log\\" || true)\\"
  fi

  STREAM_LABELS=\\"{\\\\\\"job\\\\\\":\\\\\\"jenkins-console\\\\\\",\\\\\\"repo\\\\\\":\\\\\\"${GIT_URL:-unknown}\\\\\\",\\\\\\"branch\\\\\\":\\\\\\"${BRANCH_NAME:-unknown}\\\\\\"}\\"
  EXTRA_FIELDS=\\"{\\\\\\"build_url\\\\\\":\\\\\\"${BUILD_URL}\\\\\\"}\\"
  LOG_MESSAGE=\\"$TAIL\\"
  export STREAM_LABELS EXTRA_FIELDS LOG_MESSAGE

  ./ci/push_to_loki.sh || true
"
'''
          }
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
