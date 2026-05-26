pipeline {
    agent {
        docker {
            image 'alpine/helm:3.14.0'
            reuseNode true
            args '--entrypoint='
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

        stage('Push to Repository') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'github', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh "git config --local user.name 'Jenkins'"
                    sh "git config --local user.email 'jenkins@localjenkinsrepo.job'"
                    sh "git add ."
                    sh "git commit -m 'Update Helm chart' --allow-empty"
                    sh "git push https://${USER}:${PASS}@github.com/gh0stik/subcrawler-charts.git HEAD:main"
                }
            }
        }
    }
}
