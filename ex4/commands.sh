#!/bin/bash
# ==============================================================
# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI
# ==============================================================

set -e

echo "============================================"
echo "  Bài 4: Custom Network & Named Volume"
echo "============================================"

# -----------------------------------------------------------
# Bước 1: Dọn dẹp container/network/volume cũ (nếu có)
# -----------------------------------------------------------
echo ""
echo "[Bước 0] Dọn dẹp môi trường cũ..."
docker rm -f app-container db-server 2>/dev/null || true
docker network rm app-net 2>/dev/null || true

# -----------------------------------------------------------
# Bước 1: Tạo Custom Bridge Network
# -----------------------------------------------------------
echo ""
echo "[Bước 1] Tạo Custom Bridge Network: app-net"
docker network create --driver bridge app-net
echo "✅ Network app-net đã được tạo"

# -----------------------------------------------------------
# Bước 2: Tạo Named Volume
# -----------------------------------------------------------
echo ""
echo "[Bước 2] Tạo Named Volume: db-data"
docker volume create db-data
echo "✅ Volume db-data đã được tạo"

# -----------------------------------------------------------
# Bước 3: Khởi chạy Database Container (PostgreSQL)
# -----------------------------------------------------------
echo ""
echo "[Bước 3] Khởi chạy PostgreSQL container: db-server"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine

echo "✅ Container db-server đã khởi chạy"

# Đợi PostgreSQL sẵn sàng
echo "⏳ Đang đợi PostgreSQL khởi động..."
sleep 5

# -----------------------------------------------------------
# Bước 4: Build và khởi chạy Backend Container
# -----------------------------------------------------------
echo ""
echo "[Bước 4] Build Backend image..."
docker build -t hw-backend:ex4 .

echo ""
echo "[Bước 4] Khởi chạy Backend container: app-container"
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

echo "✅ Container app-container đã khởi chạy"
sleep 3

# -----------------------------------------------------------
# Bước 5: Kiểm tra kết nối
# -----------------------------------------------------------
echo ""
echo "============================================"
echo "  Kiểm tra kết nối"
echo "============================================"

echo ""
echo "[Kiểm tra] Danh sách network:"
docker network ls | grep app-net

echo ""
echo "[Kiểm tra] Danh sách volume:"
docker volume ls | grep db-data

echo ""
echo "[Kiểm tra] Inspect network app-net:"
docker network inspect app-net --format '{{range .Containers}}{{.Name}} - {{.IPv4Address}}{{"\n"}}{{end}}'

echo ""
echo "[Kiểm tra] Ping db-server từ app-container:"
docker exec app-container ping -c 2 db-server

echo ""
echo "[Kiểm tra] Trạng thái containers:"
docker ps --filter "network=app-net" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# -----------------------------------------------------------
# Bước 6: Test Data Persistence
# -----------------------------------------------------------
echo ""
echo "============================================"
echo "  Test Data Persistence"
echo "============================================"

echo ""
echo "[Test 1] Thêm dữ liệu vào database qua API..."
curl -s -X POST http://localhost:8080/messages \
  -H "Content-Type: application/json" \
  -d '{"content": "Dữ liệu test persistence - Bài 4 Docker"}' | python3 -m json.tool 2>/dev/null || \
curl -s -X POST http://localhost:8080/messages \
  -H "Content-Type: application/json" \
  -d '{"content": "Dữ liệu test persistence - Bài 4 Docker"}'

echo ""
echo "[Test 2] Xác minh dữ liệu đã được lưu..."
curl -s http://localhost:8080/

echo ""
echo ""
echo "[Test 3] Xóa cứng container DB..."
docker rm -f db-server
echo "✅ Container db-server đã bị xóa"

echo ""
echo "[Test 4] Khởi chạy lại container DB mới với cùng Volume db-data..."
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -e POSTGRES_DB=appdb \
  postgres:15-alpine

echo "⏳ Đang đợi PostgreSQL khởi động lại..."
sleep 5

echo ""
echo "[Test 5] Xác minh dữ liệu KHÔNG bị mất sau khi tái tạo container..."
curl -s http://localhost:8080/

echo ""
echo ""
echo "============================================"
echo "  ✅ Hoàn thành Bài 4!"
echo "  Dữ liệu vẫn nguyên vẹn sau khi xóa"
echo "  và tái tạo container DB."
echo "============================================"
