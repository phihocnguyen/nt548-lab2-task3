#!/bin/bash

# Cập nhật hệ thống
sudo apt-get update -y && sudo apt-get upgrade -y

# Cài đặt các gói cần thiết
sudo apt-get install -y openjdk-17-jre git wget curl unzip

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

# Copy kubeconfig để sử dụng trong Jenkins
sudo cp /etc/rancher/k3s/k3s.yaml kubeconfig-ec2
sudo chown $USER:$USER kubeconfig-ec2

# Cài đặt SonarQube
echo "Installing SonarQube..."
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.2.77730.zip
sudo unzip sonarqube-9.9.2.77730.zip -d /opt/
sudo mv /opt/sonarqube-9.9.2.77730 /opt/sonarqube
sudo chown -R $USER:$USER /opt/sonarqube
sudo chmod +x /opt/sonarqube/bin/linux-x86-64/sonar.sh

# Tạo systemd service cho SonarQube
sudo tee /etc/systemd/system/sonarqube.service > /dev/null <<EOF
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=$USER
Group=$USER
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Khởi động SonarQube service
sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube

# Đợi SonarQube khởi động
echo "Waiting for SonarQube to start..."
sleep 30

# Xóa file zip đã tải
sudo rm sonarqube-9.9.2.77730.zip

echo ""
echo "---- CÀI ĐẶT HOÀN TẤT ----"
echo ""
echo "Mật khẩu Jenkins admin ban đầu:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword