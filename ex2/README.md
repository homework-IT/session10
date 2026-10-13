# Bài 2: Đóng gói ứng dụng Web Backend bằng Single-stage Dockerfile

## Mô tả

Đóng gói ứng dụng REST API (Node.js/Express) thành Docker Image sử dụng **Single-stage Dockerfile** để triển khai lên môi trường chạy thử nghiệm.

## Cấu trúc thư mục

```
ex2/
├── Dockerfile          # Single-stage Dockerfile
├── .dockerignore       # Loại trừ file không cần thiết
├── package.json        # Khai báo dependencies
├── server.js           # Mã nguồn ứng dụng Express.js
└── README.md           # Tài liệu hướng dẫn
```

## Giải thích Dockerfile

| Chỉ thị | Mô tả |
|---------|--------|
| `FROM node:18-alpine` | Base Image nhẹ (~170MB) dựa trên Alpine Linux |
| `WORKDIR /app` | Thiết lập thư mục làm việc trong container |
| `COPY package*.json ./` | Copy file khai báo dependencies trước (tận dụng layer cache) |
| `RUN npm install --production` | Cài đặt chỉ production dependencies |
| `COPY . .` | Copy toàn bộ mã nguồn |
| `ENV PORT=3000` | Khai báo biến môi trường PORT |
| `EXPOSE 3000` | Khai báo port ứng dụng lắng nghe |
| `CMD ["node", "server.js"]` | Lệnh khởi chạy (exec form) |

## Hướng dẫn chạy

### 1. Build Docker Image

```bash
docker build -t hw-backend:v1 .
```

### 2. Chạy Container

```bash
docker run -d --name app-single-stage -p 8080:3000 hw-backend:v1
```

### 3. Kiểm tra

```bash
# Kiểm tra container đang chạy
docker ps

# Xem logs
docker logs app-single-stage

# Test API
curl -i http://localhost:8080/
```

### Kết quả mong đợi

```
HTTP/1.1 200 OK
Content-Type: application/json

{"status":"success","message":"Hello from Docker Single-stage!"}
```

## API Endpoints

| Method | Path | Mô tả |
|--------|------|--------|
| GET | `/` | Trả về message chào mừng |
| GET | `/health` | Health check endpoint |

## Dọn dẹp

```bash
docker stop app-single-stage
docker rm app-single-stage
docker rmi hw-backend:v1
```
