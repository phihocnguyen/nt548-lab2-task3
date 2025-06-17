# ỨNG DỤNG TODO - MICROSERVICES CI/CD PIPELINE

Ứng dụng Todo hoàn chỉnh dựa trên microservices với pipeline CI/CD tự động sử dụng Jenkins, Kubernetes và các thực hành DevOps hiện đại.

## TỔNG QUAN KIẾN TRÚC

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FRONTEND      │    │   AUTH SERVICE  │    │  PROFILE SERVICE│
│   (REACT/TS)    │    │   (GO/GIN)      │    │   (GO/GIN)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  NGINX GATEWAY  │
                    │   (API ROUTER)  │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │  TASK SERVICE   │
                    │   (GO/GIN)      │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   AUTH DB       │    │  PROFILE DB     │    │   TASK DB       │
│   (MYSQL)       │    │   (MYSQL)       │    │   (MYSQL)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## MỤC LỤC

1. [YÊU CẦU HỆ THỐNG](#yêu-cầu-hệ-thống)
2. [KHỞI ĐỘNG NHANH](#khởi-động-nhanh)
3. [THIẾT LẬP HẠ TẦNG](#thiết-lập-hạ-tầng)
4. [TRIỂN KHAI ỨNG DỤNG](#triển-khai-ứng-dụng)
5. [PIPELINE CI/CD](#pipeline-cicd)
6. [GIÁM SÁT VÀ XỬ LÝ SỰ CỐ](#giám-sát-và-xử-lý-sự-cố)
7. [TÀI LIỆU API](#tài-liệu-api)
8. [HƯỚNG DẪN PHÁT TRIỂN](#hướng-dẫn-phát-triển)

## YÊU CẦU HỆ THỐNG

### YÊU CẦU PHẦN CỨNG
- **EC2 INSTANCE**: t3.medium trở lên
  - CPU: 2+ vCPUs
  - RAM: 4GB+
  - Storage: 30GB+
  - OS: Ubuntu 20.04 LTS

### YÊU CẦU PHẦN MỀM
- Docker & Docker Compose
- Kubernetes (k3s)
- kubectl
- Git
- Go 1.19+
- Node.js 16+
- Java 11+ (cho Jenkins)

### YÊU CẦU MẠNG
- Mở các cổng: 22, 80, 443, 8080, 9000, 30000-32767

## KHỞI ĐỘNG NHANH

### 1. THIẾT LẬP TỰ ĐỘNG (KHUYẾN NGHỊ)
```bash
# Clone repository
git clone <repository-url>
cd todo

# Chạy script cài đặt tự động
chmod +x install.sh
./install.sh
```

### 2. THIẾT LẬP THỦ CÔNG
```bash
# Cài đặt dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y openjdk-17-jre git wget curl unzip

# Cài đặt Go
wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Cài đặt Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Cài đặt k3s (Kubernetes)
curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml kubeconfig-ec2
sudo chown $USER:$USER kubeconfig-ec2
```

## THIẾT LẬP HẠ TẦNG

### CÀI ĐẶT JENKINS
```bash
# Cài đặt Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update -y
sudo apt install -y jenkins
sudo systemctl enable --now jenkins
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

# Lấy mật khẩu ban đầu
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### CÀI ĐẶT SONARQUBE
```bash
# Cài đặt SonarQube
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.2.77730.zip
sudo unzip sonarqube-9.9.2.77730.zip -d /opt/
sudo mv /opt/sonarqube-9.9.2.77730 /opt/sonarqube
sudo chown -R $USER:$USER /opt/sonarqube
sudo chmod +x /opt/sonarqube/bin/linux-x86-64/sonar.sh

# Tạo systemd service
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

sudo systemctl daemon-reload
sudo systemctl enable sonarqube
sudo systemctl start sonarqube
```

## TRIỂN KHAI ỨNG DỤNG

### 1. TRIỂN KHAI CƠ SỞ DỮ LIỆU
```bash
# Tạo namespace
kubectl create namespace todo-app

# Triển khai hạ tầng cơ sở dữ liệu
kubectl apply -f k8s/database/database-config.yaml -n todo-app
kubectl apply -f k8s/database/database-secrets.yaml -n todo-app
kubectl apply -f k8s/database/database-storage.yaml -n todo-app
kubectl apply -f k8s/database/database-statefulsets.yaml -n todo-app

# Chờ cơ sở dữ liệu sẵn sàng
kubectl wait --for=condition=ready pod -l app=auth-mysql-db -n todo-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=profile-mysql-db -n todo-app --timeout=300s
kubectl wait --for=condition=ready pod -l app=task-mysql-db -n todo-app --timeout=300s
```

### 2. TRIỂN KHAI DỊCH VỤ ỨNG DỤNG
```bash
# Triển khai Redis
kubectl apply -f k8s/gateway/redis.yaml -n todo-app

# Triển khai các dịch vụ ứng dụng
kubectl apply -f k8s/deployment/auth-service-deployment.yaml -n todo-app
kubectl apply -f k8s/deployment/user-service-deployment.yaml -n todo-app
kubectl apply -f k8s/deployment/task-service-deployment.yaml -n todo-app
kubectl apply -f k8s/frontend/frontend-deployment.yaml -n todo-app

# Triển khai API Gateway (Nginx)
kubectl apply -f k8s/gateway/nginx-gateway.yaml -n todo-app
```

### 3. KIỂM TRA TRIỂN KHAI
```bash
# Kiểm tra tất cả pods
kubectl get pods -n todo-app

# Kiểm tra services
kubectl get svc -n todo-app

# Kiểm tra external IP của gateway
kubectl get svc nginx-gateway-service -n todo-app
```

## PIPELINE CI/CD

### CẤU HÌNH JENKINS

1. **TRUY CẬP JENKINS**: `http://your-ec2-ip:8080`
2. **CÀI ĐẶT PLUGINS**:
   - Kubernetes
   - Docker Pipeline
   - SonarQube Scanner
   - Git Integration
   - Pipeline: GitHub
   - Blue Ocean
   - Snyk Security Scanner
   - Trivy Scanner

3. **CẤU HÌNH CREDENTIALS**:
   - Docker Hub credentials
   - GitHub credentials
   - SonarQube token
   - Snyk token
   - Kubernetes kubeconfig

4. **TẠO PIPELINE**:
   - New Pipeline job
   - Configure GitHub webhook
   - Sử dụng Jenkinsfile có sẵn

### CÁC GIAI ĐOẠN PIPELINE

Pipeline CI/CD bao gồm:

1. **BUILD STAGE**: Biên dịch tất cả services
2. **TEST STAGE**: Chạy unit và integration tests
3. **SECURITY SCAN**: Quét lỗ hổng với Trivy và Snyk
4. **CODE QUALITY**: Phân tích chất lượng code với SonarQube
5. **DOCKER BUILD**: Tạo container images
6. **DEPLOY**: Triển khai lên Kubernetes

## GIÁM SÁT VÀ XỬ LÝ SỰ CỐ

### KIỂM TRA TRẠNG THÁI ỨNG DỤNG
```bash
# Trạng thái pods
kubectl get pods -n todo-app

# Trạng thái services
kubectl get svc -n todo-app

# Logs
kubectl logs -n todo-app -l app=auth-service
kubectl logs -n todo-app -l app=user-service
kubectl logs -n todo-app -l app=task-service
kubectl logs -n todo-app -l app=frontend
```

### XỬ LÝ SỰ CỐ CƠ SỞ DỮ LIỆU
```bash
# Kiểm tra database pods
kubectl get pods -n todo-app -l app=auth-mysql-db
kubectl get pods -n todo-app -l app=profile-mysql-db
kubectl get pods -n todo-app -l app=task-mysql-db

# Logs cơ sở dữ liệu
kubectl logs -n todo-app auth-db-0
kubectl logs -n todo-app profile-db-0
kubectl logs -n todo-app task-db-0

# Kết nối vào cơ sở dữ liệu
kubectl exec -it auth-db-0 -n todo-app -- mysql -u root -p
```

### CÁC VẤN ĐỀ THƯỜNG GẶP VÀ GIẢI PHÁP

#### VẤN ĐỀ KẾT NỐI CƠ SỞ DỮ LIỆU
```bash
# Kiểm tra xem databases có sẵn sàng không
kubectl describe pod auth-db-0 -n todo-app

# Kiểm tra secrets
kubectl get secret db-secrets -n todo-app -o yaml

# Khởi động lại database pods
kubectl delete pod auth-db-0 profile-db-0 task-db-0 -n todo-app
```

#### VẤN ĐỀ GIAO TIẾP GIỮA CÁC DỊCH VỤ
```bash
# Kiểm tra service endpoints
kubectl get endpoints -n todo-app

# Test kết nối giữa các services
kubectl run test-pod --image=busybox -it --rm --restart=Never -- nslookup auth-service
```

## TÀI LIỆU API

### DỊCH VỤ XÁC THỰC
- **BASE URL**: `http://gateway-ip/auth/`
- **ENDPOINTS**:
  - `POST /v1/authenticate` - Đăng nhập người dùng
  - `POST /v1/register` - Đăng ký người dùng

### DỊCH VỤ NGƯỜI DÙNG
- **BASE URL**: `http://gateway-ip/user/`
- **ENDPOINTS**:
  - `GET /v1/profile` - Lấy thông tin profile
  - `PUT /v1/profile` - Cập nhật profile

### DỊCH VỤ TASK
- **BASE URL**: `http://gateway-ip/task/`
- **ENDPOINTS**:
  - `GET /v1/tasks` - Danh sách tasks
  - `POST /v1/tasks` - Tạo task mới
  - `PUT /v1/tasks/{id}` - Cập nhật task
  - `DELETE /v1/tasks/{id}` - Xóa task

### FRONTEND
- **URL**: `http://gateway-ip/`
- **TÍNH NĂNG**: Giao diện React với xác thực và quản lý task

## HƯỚNG DẪN PHÁT TRIỂN

### THIẾT LẬP PHÁT TRIỂN CỤC BỘ
```bash
# Clone repository
git clone <repository-url>
cd todo

# Khởi động services cục bộ với Docker Compose
docker-compose up -d

# Chạy services cục bộ
cd auth-service && go run main.go
cd ../profile-service && go run main.go
cd ../task-service && go run main.go
cd ../todo-fe && npm install && npm run dev
```

### BUILD CÁC DỊCH VỤ
```bash
# Build Go services
cd auth-service && go build -o app .
cd ../profile-service && go build -o app .
cd ../task-service && go build -o app .

# Build frontend
cd todo-fe && npm run build
```

### TESTING
```bash
# Chạy Go tests
cd auth-service && go test ./...
cd ../profile-service && go test ./...
cd ../task-service && go test ./...

# Chạy frontend tests
cd todo-fe && npm test
```

## TÍNH NĂNG BẢO MẬT

- **XÁC THỰC**: Xác thực dựa trên JWT
- **MÃ HÓA MẬT KHẨU**: Mã hóa mật khẩu an toàn với salt
- **CORS**: Cấu hình chính sách CORS
- **QUÉT BẢO MẬT**: Quét lỗ hổng tự động
- **CHẤT LƯỢNG CODE**: Phân tích chất lượng và bảo mật với SonarQube

## HIỆU SUẤT VÀ MỞ RỘNG

- **MỞ RỘNG NGANG**: Các dịch vụ có thể mở rộng độc lập
- **CÂN BẰNG TẢI**: Nginx gateway cung cấp cân bằng tải
- **CƠ SỞ DỮ LIỆU**: Cơ sở dữ liệu riêng biệt cho từng dịch vụ
- **CACHE**: Redis cho quản lý session

## SAO LƯU VÀ KHÔI PHỤC

### SAO LƯU
```bash
# Sao lưu cấu hình Jenkins
sudo tar -czf jenkins-backup.tar.gz /var/lib/jenkins

# Sao lưu dữ liệu SonarQube
sudo tar -czf sonarqube-backup.tar.gz /opt/sonarqube/data

# Sao lưu cấu hình Kubernetes
kubectl get all -n todo-app -o yaml > k8s-backup.yaml
```

### KHÔI PHỤC
```bash
# Khôi phục Jenkins
sudo tar -xzf jenkins-backup.tar.gz -C /

# Khôi phục SonarQube
sudo tar -xzf sonarqube-backup.tar.gz -C /

# Khôi phục Kubernetes
kubectl apply -f k8s-backup.yaml
```

## ĐÓNG GÓP

1. Fork repository
2. Tạo feature branch
3. Thực hiện thay đổi
4. Thêm tests
5. Submit pull request

## GIẤY PHÉP

Dự án này được cấp phép theo MIT License.

## HỖ TRỢ

Để được hỗ trợ và giải đáp thắc mắc:
- Tạo issue trong repository
- Kiểm tra phần xử lý sự cố
- Xem lại logs để biết chi tiết lỗi

---

**LƯU Ý**: Ứng dụng này được thiết kế cho mục đích học tập và trình diễn. Để sử dụng trong môi trường production, cần thêm các biện pháp bảo mật, giám sát và chiến lược sao lưu bổ sung.

