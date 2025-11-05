pipeline {
  agent {
    docker {
      image 'jenkins/test-runner:java17-node20-chrome'
      args '-v $JENKINS_HOME/.m2:/root/.m2'
      reuseNode true
    }
  }

  options { timestamps(); durabilityHint('PERFORMANCE_OPTIMIZED') }

  // ✅ Re-add parameters so upstream can pass a SHA for LOCAL mode
  parameters {
    string(name: 'APP_REPO', defaultValue: 'jmiguelcheq/calculator-demo-jenkins',
           description: 'owner/repo to clone when APP_SHA is set (LOCAL mode)')
    string(name: 'APP_SHA',  defaultValue: '',
           description: 'commit SHA to test locally; leave empty to test CALC_URL (REMOTE mode)')
    string(name: 'CALC_URL', defaultValue: 'https://jmiguelcheq.github.io/calculator-demo-jenkins',
           description: 'Public URL to test when APP_SHA is empty')
    booleanParam(name: 'HEADLESS', defaultValue: true, description: 'Run browser headless')
  }

  environment {
    BASE_URL = ''
  }

  stages {
    stage('Checkout (Testing repo)') { steps { checkout scm } }

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
                cd src
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
          if (!baseUrl) { error "BASE_URL is empty" }
          writeFile file: 'BASE_URL.txt', text: baseUrl
          currentBuild.description = "BASE_URL=${baseUrl}"
        }
      }
    }

    stage('Build & Run Tests') {
      steps {
        script {
          def base = fileExists('BASE_URL.txt') ? readFile('BASE_URL.txt').trim() : ''
          withEnv(["BASE_URL=${base}", "HEADLESS=${params.HEADLESS.toString()}"]) {
            sh '''
              set -e
              mvn -B clean test -DbaseUrl="$BASE_URL" -Dheadless="$HEADLESS"
            '''
          }
        }
      }
      // ... keep your reporting/artifacts as you already have ...
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
}
