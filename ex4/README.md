# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## Mô tả

Kết nối cụm 2 Container (Backend Web API + PostgreSQL Database) bằng Docker CLI thủ công, sử dụng **Custom Bridge Network** cho DNS resolution nội bộ và **Named Volume** cho lưu trữ dữ liệu bền vững.

## Cấu trúc thư mục

```
ex4/
├── Dockerfile          # Dockerfile cho Backend container
├── .dockerignore       # Loại trừ file không cần thiết
├── package.json        # Dependencies (express + pg)
├── server.js           # Backend API kết nối PostgreSQL
├── commands.sh         # Script thực thi toàn bộ thao tác
└── README.md           # Tài liệu (file này)
```

## Kiến trúc hệ thống

```
┌─────────────────────────────────────────────────┐
│                 Docker Host                      │
│                                                  │
│  ┌──────────── app-net (Bridge Network) ───────┐ │
│  │                                              │ │
│  │  ┌──────────────┐    ┌──────────────────┐   │ │
│  │  │ app-container│    │    db-server      │   │ │
│  │  │ (Node.js)    │───▶│  (PostgreSQL)     │   │ │
│  │  │ Port: 3000   │DNS │  Port: 5432      │   │ │
│  │  └──────────────┘    └────────┬─────────┘   │ │
│  │                               │              │ │
│  └───────────────────────────────┼──────────────┘ │
│                                  │                │
│  ┌───────────────────────────────┘                │
│  │  db-data (Named Volume)                        │
│  │  → /var/lib/postgresql/data                    │
│  └────────────────────────────────────────────────│
│                                                   │
│  Port mapping: 8080 → 3000                        │
└───────────────────────────────────────────────────┘
```

## Hướng dẫn chạy

### Chạy script tự động

```bash
chmod +x commands.sh
./commands.sh
```

### Hoặc chạy từng bước thủ công

#### Bước 1: Tạo Custom Bridge Network

```bash
docker network create --driver bridge app-net
```

#### Bước 2: Tạo Named Volume

```bash
docker volume create db-data
```

#### Bước 3: Khởi chạy PostgreSQL Container

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine
```

#### Bước 4: Build và chạy Backend Container

```bash
docker build -t hw-backend:ex4 .

docker run -d \
  --name app-container \
  --network app-net \
  -p 8080:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres123 \
  -e DB_NAME=appdb \
  hw-backend:ex4
```

## Kiểm tra kết quả

```bash
# Kiểm tra network
docker network ls | grep app-net

# Kiểm tra volume
docker volume ls | grep db-data

# Inspect network
docker network inspect app-net

# Ping DNS resolution
docker exec -it app-container ping -c 2 db-server
```

## Test Data Persistence

```bash
# 1. Thêm dữ liệu
curl -X POST http://localhost:8080/messages \
  -H "Content-Type: application/json" \
  -d '{"content": "Test data persistence"}'

# 2. Xác minh dữ liệu
curl http://localhost:8080/

# 3. Xóa cứng container DB
docker rm -f db-server

# 4. Tái tạo container DB với cùng volume
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine

# 5. Xác minh dữ liệu KHÔNG bị mất
curl http://localhost:8080/
```

## API Endpoints

| Method | Path | Mô tả |
|--------|------|--------|
| GET | `/` | Lấy tất cả messages từ DB |
| POST | `/messages` | Thêm message mới |
| GET | `/health` | Health check (kiểm tra kết nối DB) |

## Dọn dẹp

```bash
docker rm -f app-container db-server
docker network rm app-net
docker volume rm db-data
docker rmi hw-backend:ex4
```
