const { Pool } = require('pg');
const pool = new Pool({user:'myuser',host:'localhost',database:'inventory',password:'mypassword',port:5432});
async function migrate() {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                quantity INT DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);
        `);
        console.log("Migration successful");
        process.exit(0);
    } catch (e) { console.error(e); process.exit(1); }
}
migrate();