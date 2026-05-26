const { Pool } = require('pg');
const fs = require('fs');

let dbConfig = {
    user: process.env.DB_USER || 'myuser',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'inventory',
    password: process.env.DB_PASSWORD || 'mypassword',
    port: 5432
};

const CONFIG_PATH = process.env.APP_CONFIG || './templates/config.json';
if (fs.existsSync(CONFIG_PATH)) {
    const fileConfig = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    dbConfig = { ...dbConfig, ...fileConfig.db };
}

const pool = new Pool(dbConfig);

async function runMigrations() {
    const client = await pool.connect();
    try {
        await client.query(`
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                quantity INTEGER NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);
        `);
        console.log("Migrations completed.");
    } finally {
        client.release();
    }
}

module.exports = { pool, runMigrations };