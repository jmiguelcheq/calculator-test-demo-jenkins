pipeline {
  agent {
    docker {
      image 'jenkins/test-runner:java17-node20-chrome'
      args '-v $JENKINS_HOME/.m2:/root/.m2'
      reuseNode true
    }
  }

  options { timestamps(); durabilityHint('PERFORMANCE_OPTIMIZED') }

  // ✅ Upstream app job will pass these; defaults make manual runs easy
  parameters {
    string(name: 'APP_REPO', defaultValue: 'jmiguelcheq/calculator-demo-jenkins',
           description: 'owner/repo to clone in LOCAL mode (when APP_SHA is set)')
    string(name: 'APP_SHA',  defaultValue: '',
           description: 'commit SHA to test locally; leave empty to use CALC_URL (REMOTE mode)')
    string(name: 'CALC_URL', defaultValue: 'https://jmiguelcheq.github.io/calculator-demo-jenkins',
           description: 'Public URL to test when APP_SHA is empty')
    booleanParam(name: 'HEADLESS', defaultValue: true, description: 'Run browser headless')
  }

  environment {
    BASE_URL = ''  // resolved in pipeline; persisted via file
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
			
			    # --- Detect site root (prefer docs/, then dist/, then src/) ---
			    SITE_ROOT=""
			    for d in docs dist src; do
			      if [ -d "$d" ]; then SITE_ROOT="$d"; break; fi
			    done
			    if [ -z "$SITE_ROOT" ]; then
			      echo "❌ Could not find a site root (docs/, dist/, or src/)"; exit 2
			    fi
			    echo "✅ Serving from: $SITE_ROOT"
			    cd "$SITE_ROOT"
			
			    # Install http-server if missing and serve on :8080
			    if ! command -v http-server >/dev/null 2>&1; then npm i -g http-server >/dev/null 2>&1; fi
			    nohup http-server -p 8080 -c-1 --silent > /tmp/http-server.log 2>&1 &
			    echo $! > /tmp/http-server.pid
			
			    # Wait for server to be ready
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
          // JUnit for "Tests" tab
          junit allowEmptyResults: true, testResults: '*/target/surefire-reports/*.xml, target/surefire-reports/*.xml'

          // Allure single-file -> zip only (clean Build Artifacts)
          sh '''
            set +e
            mkdir -p target
            if [ -d target/allure-results ] || ls -d **/allure-results >/dev/null 2>&1; then
              PATH_TO_RESULTS="target/allure-results"
              [ -d "$PATH_TO_RESULTS" ] || PATH_TO_RESULTS="$(ls -d **/allure-results | head -n1)"
              echo "Generating Allure single-file from: $PATH_TO_RESULTS"
              allure generate "$PATH_TO_RESULTS" --single-file --clean -o target/allure-single || true
              cp -f target/allure-single/index.html target/allure-report.html || true
              (cd target && zip -q -9 allure-report.zip allure-report.html) || true
            else
              echo "No allure-results found; skipping Allure generation."
            fi
          '''

          archiveArtifacts artifacts: '''
            target/allure-single/**,
            **/target/allure-results/**
          '''.trim(), allowEmptyArchive: true
        }
      }
    }
  }

  post {
    always {
      // Stop local server if started
      sh '''
        if [ -f /tmp/http-server.pid ]; then
          kill "$(cat /tmp/http-server.pid)" 2>/dev/null || true
          rm -f /tmp/http-server.pid
        fi
      '''
    }
  }
}
