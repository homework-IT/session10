# ==============================================================
# Dockerfile Multi-stage Build - Tối ưu hóa dung lượng Image
# ==============================================================

# ---------------------------------------------------------------
# Stage 1: Builder - Cài đặt dependencies
# ---------------------------------------------------------------
FROM node:18-alpine AS builder

WORKDIR /app

# Copy file khai báo phụ thuộc trước để tận dụng Build Cache
# Nếu package.json không đổi → layer này được cache, skip npm install
COPY package*.json ./

# Cài đặt tất cả dependencies (bao gồm devDependencies nếu cần build)
RUN npm install --production

# Copy toàn bộ mã nguồn
COPY . .

# ---------------------------------------------------------------
# Stage 2: Runtime - Image siêu nhẹ chỉ chứa sản phẩm cần thiết
# ---------------------------------------------------------------
FROM node:18-alpine

WORKDIR /app

# Chỉ copy những file cần thiết từ builder stage
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./

# Khai báo biến môi trường
ENV PORT=3000

# Khai báo port
EXPOSE 3000

# Khởi chạy ứng dụng
CMD ["node", "server.js"]
