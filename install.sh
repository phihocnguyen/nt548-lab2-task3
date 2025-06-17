#!/bin/bash

# Cập nhật hệ thống
sudo apt-get update -y && sudo apt-get upgrade -y

# Cài đặt các gói cần thiết
sudo apt-get install -y openjdk-17-jre git wget curl

# Cài đặt Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Cài đặt Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Cài đặt Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins
sudo systemctl enable --now jenkins
sudo usermod -aG docker jenkins # Cho phép Jenkins sử dụng Docker
sudo systemctl restart jenkins

# Cài đặt k3s (Kubernetes)
curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml # Cho phép truy cập kubeconfig

# Cài đặt SonarQube
mkdir -p sonarqube && cd sonarqube
# SỬA LẠI CÚ PHÁP YAML VÀ THỤT LỀ
cat << EOF > docker-compose.yml
version: "3.8"
services:
  sonarqube:
    image: sonarqube:lts-community
    ports:
      - "9000:9000"
    networks:
      - sonarnet
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://db:5432/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
  db:
    image: postgres:13
    networks:
      - sonarnet
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar
      - POSTGRES_DB=sonar
    volumes:
      - postgresql:/var/lib/postgresql
      - postgresql_data:/var/lib/postgresql/data
networks:
  sonarnet:
    driver: bridge
volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql:
  postgresql_data:
EOF

# THÊM SUDO VÀO LỆNH DOCKER-COMPOSE
sudo docker-compose up -d
cd .. # Quay trở lại thư mục trước đó

echo ""
echo "---- CÀI ĐẶT HOÀN TẤT ----"
echo ""
echo "Mật khẩu Jenkins admin ban đầu:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword