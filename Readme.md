# Microservices CI/CD Pipeline Deployment Guide

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Infrastructure Setup](#infrastructure-setup)
3. [Jenkins Setup](#jenkins-setup)
4. [SonarQube Setup](#sonarqube-setup)
5. [Security Tools Setup](#security-tools-setup)
6. [Pipeline Configuration](#pipeline-configuration)
7. [Deployment Process](#deployment-process)
8. [Monitoring and Maintenance](#monitoring-and-maintenance)

## Prerequisites

### Hardware Requirements
- EC2 Instance (t3.medium or better)
  - CPU: 2+ vCPUs
  - RAM: 4GB+
  - Storage: 30GB+
  - OS: Ubuntu 20.04 LTS

### Software Requirements
- Docker
- Docker Compose
- Kubernetes (Minikube)
- kubectl
- Git
- Java 11+
- Node.js 16+
- Maven
- npm

### Network Requirements
- Open ports:
  - 22 (SSH)
  - 80 (HTTP)
  - 443 (HTTPS)
  - 8080 (Jenkins)
  - 9000 (SonarQube)
  - 30000-32767 (Kubernetes NodePort)

## Infrastructure Setup

1. **Launch EC2 Instance**
   ```bash
   # SSH into EC2
   ssh -i your-key.pem ubuntu@your-ec2-ip
   
   # Update system
   sudo apt update && sudo apt upgrade -y
   
   # Install required packages
   sudo apt install -y \
       apt-transport-https \
       ca-certificates \
       curl \
       software-properties-common \
       git \
       openjdk-11-jdk \
       maven
   ```

2. **Install Docker**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   
   # Add user to docker group
   sudo usermod -aG docker $USER
   
   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   ```

3. **Install Minikube**
   ```bash
   # Install Minikube
   curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
   sudo install minikube-linux-amd64 /usr/local/bin/minikube
   
   # Start Minikube
   minikube start --driver=docker
   
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

## Jenkins Setup

1. **Install Jenkins**
   ```bash
   # Add Jenkins repository
   curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee \
     /usr/share/keyrings/jenkins-keyring.asc > /dev/null
   echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
     https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
     /etc/apt/sources.list.d/jenkins.list > /dev/null
   
   # Install Jenkins
   sudo apt update
   sudo apt install -y jenkins
   
   # Start Jenkins
   sudo systemctl start jenkins
   sudo systemctl enable jenkins
   ```

2. **Configure Jenkins**
   - Access Jenkins UI: `http://your-ec2-ip:8080`
   - Get initial admin password:
     ```bash
     sudo cat /var/lib/jenkins/secrets/initialAdminPassword
     ```
   - Install recommended plugins
   - Create admin user
   - Install additional plugins:
     - Kubernetes
     - Docker Pipeline
     - SonarQube Scanner
     - Git Integration
     - Pipeline: GitHub
     - Blue Ocean
     - Snyk Security Scanner
     - Trivy Scanner

3. **Configure Jenkins Credentials**
   - Add Docker Hub credentials
   - Add GitHub credentials
   - Add SonarQube token
   - Add Snyk token
   - Add Kubernetes credentials

## SonarQube Setup

1. **Deploy SonarQube**
   ```bash
   # Create docker-compose.yml for SonarQube
   cat << EOF > docker-compose.yml
   version: "3"
   services:
     sonarqube:
       image: sonarqube:community
       ports:
         - "9000:9000"
       environment:
         - SONAR_JDBC_URL=jdbc:postgresql://db:5432/sonar
         - SONAR_JDBC_USERNAME=sonar
         - SONAR_JDBC_PASSWORD=sonar
       volumes:
         - sonarqube_data:/opt/sonarqube/data
         - sonarqube_extensions:/opt/sonarqube/extensions
         - sonarqube_logs:/opt/sonarqube/logs
       depends_on:
         - db
     db:
       image: postgres:12
       environment:
         - POSTGRES_USER=sonar
         - POSTGRES_PASSWORD=sonar
         - POSTGRES_DB=sonar
       volumes:
         - postgresql:/var/lib/postgresql
         - postgresql_data:/var/lib/postgresql/data
   volumes:
     sonarqube_data:
     sonarqube_extensions:
     sonarqube_logs:
     postgresql:
     postgresql_data:
   EOF
   
   # Start SonarQube
   docker-compose up -d
   ```

2. **Configure SonarQube**
   - Access SonarQube UI: `http://your-ec2-ip:9000`
   - Default credentials: admin/admin
   - Create new project
   - Generate token for Jenkins

## Security Tools Setup

1. **Install Trivy**
   ```bash
   # Install Trivy
   curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
   ```

2. **Configure Snyk**
   - Sign up for Snyk account
   - Get API token
   - Add token to Jenkins credentials

## Pipeline Configuration

1. **Create Jenkinsfile**
   - Use the existing Jenkinsfile in the repository
   - Ensure it includes:
     - Build stages
     - Test stages
     - SonarQube analysis
     - Security scanning
     - Docker image building
     - Kubernetes deployment

2. **Configure Pipeline in Jenkins**
   - Create new Pipeline job
   - Configure GitHub webhook
   - Set build triggers
   - Configure environment variables

## Deployment Process

1. **Initial Setup**
   ```bash
   # Clone repository
   git clone https://github.com/your-repo/todo-app.git
   cd todo-app
   
   # Create namespace
   kubectl create namespace todo-app
   ```

2. **Deploy Database**
   ```bash
   # Apply database configurations
   kubectl apply -f k8s/database-config.yaml
   kubectl apply -f k8s/database-storage.yaml
   kubectl apply -f k8s/database-statefulsets.yaml
   kubectl apply -f k8s/database-secrets.yaml
   ```

3. **Deploy Gateway**
   ```bash
   # Deploy Tyk Gateway
   ./gateway/deploy-gateway.sh
   ```

4. **Deploy Applications**
   ```bash
   # Trigger Jenkins pipeline
   # This will:
   # 1. Build and test applications
   # 2. Run SonarQube analysis
   # 3. Run security scans
   # 4. Build Docker images
   # 5. Deploy to Kubernetes
   ```

## Monitoring and Maintenance

1. **Monitor Applications**
   ```bash
   # Check pod status
   kubectl get pods -n todo-app
   
   # Check services
   kubectl get svc -n todo-app
   
   # Check logs
   kubectl logs -n todo-app -l app=<service-name>
   ```

2. **Monitor Jenkins**
   - Access Jenkins UI
   - Check build history
   - Monitor pipeline status
   - Review test results
   - Check SonarQube reports

3. **Monitor SonarQube**
   - Access SonarQube UI
   - Review code quality metrics
   - Check security vulnerabilities
   - Monitor code coverage

4. **Regular Maintenance**
   - Update Jenkins plugins
   - Update SonarQube
   - Update security tools
   - Clean up old Docker images
   - Monitor disk space
   - Review and rotate credentials

## Troubleshooting

1. **Jenkins Issues**
   ```bash
   # Check Jenkins logs
   sudo journalctl -u jenkins
   
   # Restart Jenkins
   sudo systemctl restart jenkins
   ```

2. **Kubernetes Issues**
   ```bash
   # Check pod status
   kubectl describe pod <pod-name> -n todo-app
   
   # Check service status
   kubectl describe svc <service-name> -n todo-app
   
   # Check logs
   kubectl logs <pod-name> -n todo-app
   ```

3. **SonarQube Issues**
   ```bash
   # Check SonarQube logs
   docker-compose logs sonarqube
   
   # Restart SonarQube
   docker-compose restart sonarqube
   ```

## Security Considerations

1. **Regular Security Updates**
   - Update system packages
   - Update Docker images
   - Update Kubernetes
   - Update Jenkins plugins
   - Update SonarQube

2. **Access Control**
   - Use strong passwords
   - Implement 2FA where possible
   - Regular credential rotation
   - Minimal required permissions

3. **Monitoring**
   - Regular security scans
   - Log monitoring
   - Alert on suspicious activities
   - Regular backup of configurations

## Backup and Recovery

1. **Backup Important Data**
   ```bash
   # Backup Jenkins configuration
   sudo tar -czf jenkins-backup.tar.gz /var/lib/jenkins
   
   # Backup SonarQube data
   docker-compose exec -T sonarqube tar -czf - /opt/sonarqube/data > sonarqube-backup.tar.gz
   
   # Backup Kubernetes configurations
   kubectl get all -n todo-app -o yaml > k8s-backup.yaml
   ```

2. **Recovery Process**
   - Restore Jenkins from backup
   - Restore SonarQube data
   - Reapply Kubernetes configurations
   - Verify all services are running

