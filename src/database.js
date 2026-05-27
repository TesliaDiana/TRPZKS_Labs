const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  user: process.env.DB_USER ? process.env.DB_USER.trim() : 'myuser',
  host: process.env.DB_HOST ? process.env.DB_HOST.trim() : '127.0.0.1',
  database: process.env.DB_NAME ? process.env.DB_NAME.trim() : 'inventory',
  password: process.env.DB_PASSWORD ? String(process.env.DB_PASSWORD).trim() : 'mypassword123',
  port: parseInt(process.env.DB_PORT || '5432', 10),
});

console.log(
  `DEBUG: Final check - User: "${process.env.DB_USER || 'undefined'}", Port: ${process.env.DB_PORT || 'undefined'}`
);

async function runMigrations() {
  let client;
  try {
    client = await pool.connect();
    await client.query(`
    CREATE TABLE IF NOT EXISTS items (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0
    );
    `);
    console.log("✔ База даних готова");
  } catch (err) {
    console.error("❌ ДЕТАЛІ ПОМИЛКИ:");
    console.error(`Host: ${pool.options.host}`);
    console.error(`Database: ${pool.options.database}`);
    console.error(`Message: ${err.message}`);
    throw err;
  } finally {
    if (client) client.release();
  }
}

module.exports = { pool, runMigrations };