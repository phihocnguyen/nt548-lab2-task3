pipeline {
    agent any

    environment {
        DOCKER_REGISTRY      = 'phihocnguyen123'
        SONAR_HOST_URL       = 'http://54.151.221.118:9000'
        KUBERNETES_NAMESPACE = 'todo-app'
        SONAR_TOKEN          = credentials('sonar-token')
        SNYK_TOKEN           = credentials('snyk-token')
        DOCKER_CREDENTIALS   = credentials('docker-credentials')
        KUBECONFIG_CRED      = credentials('kubeconfig-ec2')
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }

        stage('Build & Unit Test') {
            parallel {
                stage('Auth Service') {
                    steps {
                        dir('auth-service') {
                            sh 'go mod download'
                            sh 'go test ./...'
                            sh 'go build -o app .'
                        }
                    }
                }
                stage('Profile Service') {
                    steps {
                        dir('profile-service') {
                            sh 'go mod download'
                            sh 'go test ./...'
                            sh 'go build -o app .'
                        }
                    }
                }
                stage('Task Service') {
                    steps {
                        dir('task-service') {
                            sh 'go mod download'
                            sh 'go test ./...'
                            sh 'go build -o app .'
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        dir('todo-fe') {
                            sh 'npm install'
                            sh 'npm run build'
                        }
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'SonarScanner'
                    withSonarQubeEnv('SonarServer') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }
        
        stage('Build & Push Docker Images') {
            parallel {
                stage('Auth Service Image') {
                    steps {
                        dir('auth-service') {
                            script {
                                def imageName = "${DOCKER_REGISTRY}/auth-service:${env.BUILD_NUMBER}"
                                sh "docker build -f Dockerfile -t ${imageName} ."
                                withCredentials([usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                                    sh "docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}"
                                    sh "docker push ${imageName}"
                                }
                            }
                        }
                    }
                }
                stage('Profile Service Image') {
                    steps {
                        dir('profile-service') {
                            script {
                                def imageName = "${DOCKER_REGISTRY}/profile-service:${env.BUILD_NUMBER}"
                                sh "docker build -f Dockerfile -t ${imageName} ."
                                withCredentials([usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                                    sh "docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}"
                                    sh "docker push ${imageName}"
                                }
                            }
                        }
                    }
                }
                stage('Task Service Image') {
                     steps {
                        dir('task-service') {
                            script {
                                def imageName = "${DOCKER_REGISTRY}/task-service:${env.BUILD_NUMBER}"
                                sh "docker build -f Dockerfile -t ${imageName} ."
                                withCredentials([usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                                    sh "docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}"
                                    sh "docker push ${imageName}"
                                }
                            }
                        }
                    }
                }
                stage('Frontend Image') {
                     steps {
                        dir('todo-fe') {
                            script {
                                def imageName = "${DOCKER_REGISTRY}/todo-fe:${env.BUILD_NUMBER}"
                                sh "docker build -f Dockerfile -t ${imageName} ."
                                withCredentials([usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                                    sh "docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}"
                                    sh "docker push ${imageName}"
                                }
                            }
                        }
                    }
                }
            }
        }
        
        stage('Security Scans') {
            parallel {
                stage('Trivy Scan') {
                    steps {
                        sh '''
                            # Install Trivy if not already installed
                            if ! command -v trivy &> /dev/null; then
                                echo "Installing Trivy..."
                                # Install to local directory to avoid permission issues
                                mkdir -p $HOME/bin
                                curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $HOME/bin v0.48.0
                                export PATH=$HOME/bin:$PATH
                            fi
                            
                            # Run Trivy scans
                            trivy image ${DOCKER_REGISTRY}/auth-service:${BUILD_NUMBER} --format template --template "@contrib/html.tpl" -o trivy-auth-report.html
                            trivy image ${DOCKER_REGISTRY}/profile-service:${BUILD_NUMBER} --format template --template "@contrib/html.tpl" -o trivy-profile-report.html
                            trivy image ${DOCKER_REGISTRY}/task-service:${BUILD_NUMBER} --format template --template "@contrib/html.tpl" -o trivy-task-report.html
                            trivy image ${DOCKER_REGISTRY}/todo-fe:${BUILD_NUMBER} --format template --template "@contrib/html.tpl" -o trivy-frontend-report.html
                        '''
                        archiveArtifacts artifacts: 'trivy-*-report.html'
                    }
                }
                stage('Snyk Scan') {
                    steps {
                        sh '''
                            # Install snyk and snyk-to-html locally to avoid permission issues
                            npm install snyk snyk-to-html
                            
                            # Use local installation
                            ./node_modules/.bin/snyk auth ${SNYK_TOKEN}
                            ./node_modules/.bin/snyk test --all-projects --json > snyk-results.json || true
                            ./node_modules/.bin/snyk-to-html -i snyk-results.json -o snyk-report.html
                            
                            # Debug info
                            ls -l snyk-report.html
                            file snyk-report.html
                            cat snyk-report.html | head -n 10
                        '''
                        archiveArtifacts artifacts: 'snyk-report.html'
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    withCredentials([kubeconfigContent(credentialsId: 'kubeconfig-ec2')]) {
                        env.KUBECONFIG = "${KUBECONFIG_CRED}"
                        
                        echo 'Creating namespace if not exists...'
                        sh 'kubectl create namespace ${KUBERNETES_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -'
                        
                        echo 'Deploying database infrastructure...'
                        sh 'kubectl apply -f k8s/database-config.yaml -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl apply -f k8s/database-secrets.yaml -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl apply -f k8s/database-storage.yaml -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl apply -f k8s/database-statefulsets.yaml -n ${KUBERNETES_NAMESPACE}'
                        
                        echo 'Waiting for database to be ready...'
                        sh 'kubectl wait --for=condition=ready pod -l app=mysql-db -n ${KUBERNETES_NAMESPACE} --timeout=300s'
                        
                        echo 'Deploying Redis...'
                        sh 'kubectl apply -f gateway/redis.yaml -n ${KUBERNETES_NAMESPACE}'
                        
                        echo 'Deploying services...'
                        sh 'kubectl apply -f gateway/auth-service.yaml -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl apply -f gateway/user-service.yaml -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl apply -f gateway/task-service.yaml -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl apply -f gateway/frontend-deployment.yaml -n ${KUBERNETES_NAMESPACE}'
                        
                        echo 'Updating deployment images...'
                        sh 'kubectl set image deployment/auth-service-deployment auth-service=${DOCKER_REGISTRY}/auth-service:${env.BUILD_NUMBER} -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl set image deployment/user-service-deployment user-service=${DOCKER_REGISTRY}/profile-service:${env.BUILD_NUMBER} -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl set image deployment/task-service-deployment task-service=${DOCKER_REGISTRY}/task-service:${env.BUILD_NUMBER} -n ${KUBERNETES_NAMESPACE}'
                        sh 'kubectl set image deployment/frontend-deployment frontend=${DOCKER_REGISTRY}/todo-fe:${env.BUILD_NUMBER} -n ${KUBERNETES_NAMESPACE}'
                        
                        echo 'Deploying API Gateway (Tyk)...'
                        sh 'kubectl apply -f gateway/tyk-deployment.yaml -n ${KUBERNETES_NAMESPACE}'
                        
                        echo 'Waiting for all deployments to be ready...'
                        sh 'kubectl rollout status deployment/auth-service-deployment -n ${KUBERNETES_NAMESPACE} --timeout=300s'
                        sh 'kubectl rollout status deployment/user-service-deployment -n ${KUBERNETES_NAMESPACE} --timeout=300s'
                        sh 'kubectl rollout status deployment/task-service-deployment -n ${KUBERNETES_NAMESPACE} --timeout=300s'
                        sh 'kubectl rollout status deployment/frontend-deployment -n ${KUBERNETES_NAMESPACE} --timeout=300s'
                        sh 'kubectl rollout status deployment/tyk-gateway -n ${KUBERNETES_NAMESPACE} --timeout=300s'
                        
                        echo 'Deployment completed successfully!'
                        sh 'kubectl get pods -n ${KUBERNETES_NAMESPACE}'
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up and archiving...'
            sh 'docker system prune -f'
            // Archive test results if any
            archiveArtifacts artifacts: '**/test-results/*.xml', allowEmptyArchive: true
        }
        success {
            echo 'Pipeline successful!'
            emailext (
                subject: "SUCCESS: Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: "Check console output at ${env.BUILD_URL}",
                recipientProviders: [[$class: 'DevelopersRecipientProvider']]
            )
        }
        failure {
            echo 'Pipeline failed.'
            emailext (
                subject: "FAILED: Pipeline '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: "Check console output at ${env.BUILD_URL}",
                recipientProviders: [[$class: 'DevelopersRecipientProvider']]
            )
        }
    }
}