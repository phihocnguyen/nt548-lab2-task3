# Hướng dẫn Deploy Microservices lên EC2 với Docker và Kubernetes

## Yêu cầu hệ thống

### EC2 Instance
- Ubuntu Server 20.04 LTS hoặc mới hơn
- Tối thiểu: t2.medium (2 vCPU, 4GB RAM)
- Khuyến nghị: t2.large (2 vCPU, 8GB RAM)
- Storage: tối thiểu 20GB

### Security Group
Mở các port sau:
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 30000-32767 (NodePort range cho Kubernetes)

## Các bước chuẩn bị

1. **Tạo EC2 Instance**
   ```bash
   # Tạo key pair
   aws ec2 create-key-pair --key-name todo-app-key --query 'KeyMaterial' --output text > todo-app-key.pem
   chmod 400 todo-app-key.pem
   ```

2. **Cấu hình Security Group**
   - Tạo security group mới
   - Thêm inbound rules cho các port cần thiết
   - Gán security group cho EC2 instance

3. **Chuẩn bị local environment**
   - Cài đặt AWS CLI
   - Cấu hình AWS credentials
   - Cài đặt kubectl
   - Cài đặt Docker

## Các bước deploy

1. **Chuẩn bị script**
   - Chỉnh sửa file `deploy-ec2.sh`:
     ```bash
     EC2_USER="ubuntu"  # Thay đổi nếu cần
     EC2_HOST="your-ec2-ip"  # Thay bằng IP của EC2 instance
     EC2_KEY_PATH="path/to/your-key.pem"  # Thay bằng đường dẫn đến key file
     ```

2. **Chạy script deploy**
   ```bash
   chmod +x deploy-ec2.sh
   ./deploy-ec2.sh
   ```

## Kiểm tra deployment

1. **Kiểm tra pods**
   ```bash
   kubectl get pods -n todo-app
   ```

2. **Kiểm tra services**
   ```bash
   kubectl get services -n todo-app
   ```

3. **Kiểm tra logs**
   ```bash
   # Auth Service
   kubectl logs -n todo-app deployment/auth-service
   
   # Profile Service
   kubectl logs -n todo-app deployment/profile-service
   
   # Task Service
   kubectl logs -n todo-app deployment/task-service
   
   # Frontend
   kubectl logs -n todo-app deployment/todo-fe
   ```

## Monitoring và Maintenance

1. **Kubernetes Dashboard**
   - Truy cập dashboard: `http://<ec2-ip>:30000`
   - Sử dụng token được cung cấp bởi script deploy

2. **Scaling Services**
   ```bash
   # Scale Auth Service
   kubectl scale deployment auth-service -n todo-app --replicas=3
   
   # Scale Profile Service
   kubectl scale deployment profile-service -n todo-app --replicas=3
   
   # Scale Task Service
   kubectl scale deployment task-service -n todo-app --replicas=3
   ```

3. **Update Services**
   ```bash
   # Update image version
   kubectl set image deployment/<service-name> <container-name>=<new-image>:<tag> -n todo-app
   
   # Rollback nếu cần
   kubectl rollout undo deployment/<service-name> -n todo-app
   ```

## Troubleshooting

1. **Pod không khởi động**
   ```bash
   # Kiểm tra pod status
   kubectl describe pod <pod-name> -n todo-app
   
   # Kiểm tra logs
   kubectl logs <pod-name> -n todo-app
   ```

2. **Service không thể kết nối**
   ```bash
   # Kiểm tra service endpoints
   kubectl get endpoints -n todo-app
   
   # Kiểm tra service details
   kubectl describe service <service-name> -n todo-app
   ```

3. **Database issues**
   ```bash
   # Kiểm tra database pods
   kubectl get pods -n todo-app | grep db
   
   # Kiểm tra database logs
   kubectl logs -n todo-app <db-pod-name>
   ```

## Backup và Recovery

1. **Backup databases**
   ```bash
   # Backup Auth DB
   kubectl exec -n todo-app <auth-db-pod> -- mysqldump -u root -p auth_db > auth_db_backup.sql
   
   # Backup Profile DB
   kubectl exec -n todo-app <profile-db-pod> -- mysqldump -u root -p profile_db > profile_db_backup.sql
   
   # Backup Task DB
   kubectl exec -n todo-app <task-db-pod> -- mysqldump -u root -p task_db > task_db_backup.sql
   ```

2. **Restore databases**
   ```bash
   # Restore Auth DB
   kubectl exec -i -n todo-app <auth-db-pod> -- mysql -u root -p auth_db < auth_db_backup.sql
   
   # Restore Profile DB
   kubectl exec -i -n todo-app <profile-db-pod> -- mysql -u root -p profile_db < profile_db_backup.sql
   
   # Restore Task DB
   kubectl exec -i -n todo-app <task-db-pod> -- mysql -u root -p task_db < task_db_backup.sql
   ```

## Cleanup

1. **Xóa toàn bộ deployment**
   ```bash
   kubectl delete namespace todo-app
   ```

2. **Xóa EC2 instance**
   ```bash
   aws ec2 terminate-instances --instance-ids <instance-id>
   ```

## Lưu ý quan trọng

1. **Security**
   - Luôn sử dụng HTTPS cho production
   - Cập nhật security groups thường xuyên
   - Sử dụng secrets cho sensitive data
   - Enable AWS CloudWatch cho monitoring

2. **Performance**
   - Monitor resource usage
   - Scale services dựa trên load
   - Sử dụng AWS CloudWatch để set up alerts

3. **Cost Optimization**
   - Sử dụng AWS Spot Instances cho non-critical workloads
   - Monitor và optimize resource usage
   - Clean up unused resources

## Hỗ trợ

Nếu gặp vấn đề trong quá trình deploy, vui lòng:
1. Kiểm tra logs của các services
2. Xem xét các common issues trong phần Troubleshooting
3. Tạo issue trên repository với thông tin chi tiết về lỗi 