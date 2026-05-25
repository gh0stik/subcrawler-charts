pipeline {
    agent {
        docker {
            // Spin up a container that already has Helm installed
            image 'alpine/helm:3.14.0' 
            reuseNode true
            args '-u root --entrypoint='
        }
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    stages {
        stage('Lint Chart') {
            steps {
                sh 'helm lint .'
            }
        }

        stage('Package Chart') {
            steps {
                sh 'helm package .'
            }
        }

        stage('Update Repository Index') {
            steps {
                sh 'helm repo index .'
                sh 'ls -ltr'
            }
        }
    }
}