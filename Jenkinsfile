pipeline {
    agent any

    environment {
        // --- THAY THẾ CÁC GIÁ TRỊ NÀY ---
        DOCKER_REGISTRY      = 'your-docker-hub-id' // <<-- THAY BẰNG DOCKER HUB ID CỦA BẠN
        SONAR_HOST_URL       = 'http://<IP-CUA-EC2>:9000' // <<-- THAY BẰNG IP CỦA MÁY CHỦ EC2
        KUBERNETES_NAMESPACE = 'todo-app'
        
        // --- CÁC CREDENTIALS NÀY CẦN ĐƯỢC CẤU HÌNH TRONG JENKINS ---
        SONAR_TOKEN          = credentials('sonarqube-token')
        SNYK_TOKEN           = credentials('snyk-token')
        DOCKER_CREDENTIALS   = credentials('docker-credentials') // Loại Username/Password
        KUBECONFIG_CRED      = credentials('kubeconfig-ec2')     // Loại Secret File
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
                            sh 'mvn clean package test'
                        }
                    }
                }
                stage('Profile Service') {
                    steps {
                        dir('profile-service') {
                            sh 'mvn clean package test'
                        }
                    }
                }
                stage('Task Service') {
                    steps {
                        dir('task-service') {
                            sh 'mvn clean package test'
                        }
                    }
                }
                stage('Frontend') {
                    steps {
                        dir('todo-fe') {
                            sh 'npm install -g pnpm && pnpm install'
                            sh 'pnpm run test'
                            sh 'pnpm run build'
                        }
                    }
                }
            }
        }

        stage('SonarQube Analysis') {
            parallel {
                stage('Backend Analysis') {
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh '''
                                mvn sonar:sonar \
                                  -Dsonar.projectKey=todo-app-backend \
                                  -Dsonar.sources=./auth-service/src,./profile-service/src,./task-service/src \
                                  -Dsonar.tests=./auth-service/src/test,./profile-service/src/test,./task-service/src/test \
                                  -Dsonar.java.binaries=./auth-service/target,./profile-service/target,./task-service/target \
                                  -Dsonar.coverage.jacoco.xmlReportPaths=./auth-service/target/site/jacoco/jacoco.xml,./profile-service/target/site/jacoco/jacoco.xml,./task-service/target/site/jacoco/jacoco.xml
                            '''
                        }
                    }
                }
                stage('Frontend Analysis') {
                    steps {
                        withSonarQubeEnv('SonarQube') {
                            sh '''
                                sonar-scanner \
                                  -Dsonar.projectKey=todo-app-frontend \
                                  -Dsonar.sources=./todo-fe/src \
                                  -Dsonar.tests=./todo-fe/src/test \
                                  -Dsonar.javascript.lcov.reportPaths=./todo-fe/coverage/lcov.info
                            '''
                        }
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
                                sh "docker build -t ${imageName} ."
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
                                sh "docker build -t ${imageName} ."
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
                                sh "docker build -t ${imageName} ."
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
                                sh "docker build -t ${imageName} ."
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
                            trivy image ${DOCKER_REGISTRY}/auth-service:${BUILD_NUMBER} --format template --template '@html' -o trivy-auth-report.html
                            trivy image ${DOCKER_REGISTRY}/profile-service:${BUILD_NUMBER} --format template --template '@html' -o trivy-profile-report.html
                            trivy image ${DOCKER_REGISTRY}/task-service:${BUILD_NUMBER} --format template --template '@html' -o trivy-task-report.html
                            trivy image ${DOCKER_REGISTRY}/todo-fe:${BUILD_NUMBER} --format template --template '@html' -o trivy-frontend-report.html
                            archiveArtifacts artifacts: 'trivy-*-report.html'
                        '''
                    }
                }
                stage('Snyk Scan') {
                    steps {
                        sh '''
                            npm install -g snyk snyk-to-html
                            snyk auth ${SNYK_TOKEN}
                            snyk test --all-projects --json > snyk-results.json || true
                            snyk-to-html -i snyk-results.json -o snyk-report.html
                            archiveArtifacts artifacts: 'snyk-report.html'
                        '''
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                withCredentials([kubeconfigContent(credentialsId: 'kubeconfig-ec2')]) {
                    script {
                        env.KUBECONFIG = "${KUBECONFIG_CRED}"
                        
                        sh 'kubectl apply -f k8s/1-infra/'
                        sh 'kubectl apply -f k8s/2-db/'
                        sh 'kubectl rollout status statefulset/mysql-db -n ${KUBERNETES_NAMESPACE} --timeout=5m'

                        sh 'chmod +x jenkins/deploy.sh'
                        
                        sh "./jenkins/deploy.sh auth-service-deployment auth-service ${DOCKER_REGISTRY}/auth-service:${env.BUILD_NUMBER} ${KUBERNETES_NAMESPACE}"
                        sh "./jenkins/deploy.sh profile-service-deployment profile-service ${DOCKER_REGISTRY}/profile-service:${env.BUILD_NUMBER} ${KUBERNETES_NAMESPACE}"
                        sh "./jenkins/deploy.sh task-service-deployment task-service ${DOCKER_REGISTRY}/task-service:${env.BUILD_NUMBER} ${KUBERNETES_NAMESPACE}"
                        sh "./jenkins/deploy.sh frontend-deployment frontend ${DOCKER_REGISTRY}/todo-fe:${env.BUILD_NUMBER} ${KUBERNETES_NAMESPACE}"
                        
                        sh 'kubectl apply -f k8s/4-gateway/'
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up and archiving...'
            sh 'docker system prune -f'
            junit '**/target/surefire-reports/*.xml'
            junit '**/target/failsafe-reports/*.xml'
            publishCoverage adapters: [jacocoAdapter('**/target/site/jacoco/jacoco.xml')]
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