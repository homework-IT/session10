const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

// Kết nối PostgreSQL qua hostname db-server (DNS resolution trong Docker Network)
const pool = new Pool({
  host: process.env.DB_HOST || 'db-server',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres123',
  database: process.env.DB_NAME || 'appdb'
});

// Khởi tạo bảng khi ứng dụng khởi động
async function initDB() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id SERIAL PRIMARY KEY,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('Database initialized successfully');
  } catch (err) {
    console.error('Database initialization failed:', err.message);
    // Retry sau 3 giây nếu DB chưa sẵn sàng
    setTimeout(initDB, 3000);
  }
}

// API: Lấy tất cả messages
app.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM messages ORDER BY id DESC');
    res.json({
      status: 'success',
      data: result.rows,
      count: result.rowCount
    });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// API: Thêm message mới
app.post('/messages', async (req, res) => {
  try {
    const { content } = req.body;
    if (!content) {
      return res.status(400).json({ status: 'error', message: 'Content is required' });
    }
    const result = await pool.query(
      'INSERT INTO messages (content) VALUES ($1) RETURNING *',
      [content]
    );
    res.status(201).json({ status: 'success', data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// API: Health check
app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'healthy', database: 'connected' });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', database: 'disconnected' });
  }
});

app.listen(PORT, () => {
  console.log(`Backend API listening on port ${PORT}`);
  initDB();
});
