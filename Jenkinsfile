pipeline {
  agent any
  stages {
    stage('First') {
      steps {
        fingerprint '*.sh'
      }
    }

    stage('Sleep') {
      steps {
        sleep 5
      }
    }

    stage('Build') {
      steps {
        ws(dir: 'pippo') {
          sh 'touch FileDiTest'
          sh 'ls -all'
        }

      }
    }

    stage('Check') {
      steps {
        fingerprint '*'
      }
    }

  }
}