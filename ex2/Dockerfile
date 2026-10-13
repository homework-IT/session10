# ==============================================================
# Single-stage Dockerfile - Node.js Express Backend
# ==============================================================

# 1. Base Image: sử dụng node:18-alpine (nhẹ, bảo mật)
FROM node:18-alpine

# 2. Thiết lập thư mục làm việc trong container
WORKDIR /app

# 3. Copy file khai báo dependencies trước (tận dụng layer cache)
COPY package*.json ./

# 4. Cài đặt dependencies
RUN npm install --production

# 5. Copy toàn bộ mã nguồn ứng dụng
COPY . .

# 6. Khai báo biến môi trường PORT
ENV PORT=3000

# 7. Khai báo cổng ứng dụng lắng nghe
EXPOSE 3000

# 8. Lệnh khởi chạy ứng dụng (exec form)
CMD ["node", "server.js"]
