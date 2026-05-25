const { Pool } = require('pg');
const fs = require('fs');

const CONFIG_PATH = process.env.APP_CONFIG || './templates/config.json';
const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));

const pool = new Pool(config.db);

async function runMigrations() {
    const client = await pool.connect();
    try {
        await client.query(`
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                quantity INTEGER NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        console.log("Migrations completed.");
    } finally {
        client.release();
    }
}

module.exports = { pool, runMigrations };