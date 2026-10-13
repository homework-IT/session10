# Bài 3: Tối ưu hóa dung lượng Image & Layer Caching với Multi-stage Build

## Mô tả

Refactor Dockerfile của ứng dụng Web Backend sang chuẩn **Multi-stage Build** để giảm dung lượng Docker Image xuống mức tối thiểu, phục vụ môi trường Production.

## Cấu trúc thư mục

```
ex3/
├── Dockerfile          # Multi-stage Dockerfile (Production)
├── Dockerfile.single   # Single-stage Dockerfile (để so sánh)
├── .dockerignore       # Loại trừ file không cần thiết
├── package.json        # Khai báo dependencies
├── server.js           # Mã nguồn ứng dụng
└── README.md           # Tài liệu (file này)
```

## So sánh Single-stage vs Multi-stage

### Bảng so sánh dung lượng Image

| Tiêu chí | `hw-backend:single` | `hw-backend:multistage` | Giảm |
|-----------|---------------------|-------------------------|------|
| **Dung lượng** | ~180MB | ~80MB | ~55% |
| **Số Layer** | 8 layers | 6 layers | 25% |
| **Build Cache** | Hạn chế | Tối ưu | ✅ |
| **Dev Dependencies** | Có thể lẫn | Loại bỏ hoàn toàn | ✅ |
| **Attack Surface** | Lớn hơn | Nhỏ hơn | ✅ |

> **Lưu ý**: Dung lượng thực tế sẽ thay đổi tùy thuộc vào số lượng dependencies. Chạy `docker images | grep hw-backend` để xem kết quả thực.

### Giải thích kỹ thuật Multi-stage Build

#### Stage 1: Builder
```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./      # Copy dependency manifest trước
RUN npm install --production  # Cài đặt dependencies (layer được cache)
COPY . .                   # Copy source code
```

**Mục đích**: Cài đặt dependencies và chuẩn bị các file cần thiết. Stage này **không** nằm trong image cuối cùng.

#### Stage 2: Runtime
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./
```

**Mục đích**: Chỉ copy những file cần thiết từ builder stage. Image cuối cùng **không chứa** build tools, cache, hay file thừa.

### Cơ chế Layer Caching

```
Layer 1: FROM node:18-alpine          ← Cache nếu base image không đổi
Layer 2: COPY package*.json ./         ← Cache nếu package.json không đổi
Layer 3: RUN npm install               ← Cache nếu Layer 2 cache hit
Layer 4: COPY . .                      ← Invalidate khi source code thay đổi
```

**Lợi ích**: Khi chỉ thay đổi source code (`server.js`), Docker chỉ rebuild từ Layer 4 trở xuống. Layer `npm install` (tốn thời gian nhất) được giữ nguyên từ cache → **giảm thời gian build đáng kể**.

## Hướng dẫn chạy

### 1. Build cả 2 image để so sánh

```bash
# Build Single-stage
docker build -f Dockerfile.single -t hw-backend:single .

# Build Multi-stage
docker build -f Dockerfile -t hw-backend:multistage .
```

### 2. So sánh dung lượng

```bash
docker images | grep hw-backend
```

### 3. Chạy và kiểm tra Multi-stage container

```bash
docker run -d --name app-multistage -p 8080:3000 hw-backend:multistage

# Test API
curl -i http://localhost:8080/

# Xem logs
docker logs app-multistage
```

### Kết quả mong đợi

```
REPOSITORY    TAG           IMAGE ID       SIZE
hw-backend    single        xxxxxxxxxxxx   ~180MB
hw-backend    multistage    xxxxxxxxxxxx   ~80MB
```

→ Dung lượng giảm **50-70%** so với single-stage.

## Dọn dẹp

```bash
docker stop app-multistage
docker rm app-multistage
docker rmi hw-backend:single hw-backend:multistage
```
