pipeline {
    agent any

    environment {
        // This binds the secret file to a temporary environment path variable
        KUBECONFIG_CREDENTIAL_ID = 'microk8s-kubeconfig'
    }
    
    triggers {
        pollSCM('H/5 * * * *')
    }
    
    stages {
        stage('Deploy with Helm') {
            // This forces only this stage to execute inside the container
            agent {
                docker {
                    image 'alpine/helm:3.14.0' // Uses an official, lightweight Helm+Kubectl image
                    // Reuse the host's network and workspace
                    reuseNode true 
                    args '--entrypoint='
                }
            }
            steps {
                withCredentials([file(credentialsId: "${KUBECONFIG_CREDENTIAL_ID}", variable: 'KUBECONFIG_FILE')]) {
                    sh '''
                        echo "Checking raw network connectivity to port 16443..."
                        nc -zv -w 5 98.84.118.211 16443
                    
                        echo "Deploying application via Helm..."
                        helm upgrade --install subcrawler . \
                          -f values-dev.yaml \
                          --kubeconfig=$KUBECONFIG_FILE \
                          --insecure-skip-tls-verify
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up workspace...'
        }
    }
}