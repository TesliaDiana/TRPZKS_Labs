const { app, pool } = require('./app');

async function init() {
    try {
        await pool.query(`
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                quantity INT DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);

        const listenTarget = process.env.LISTEN_FDS ? { fd: 3 } : 8000;

        app.listen(listenTarget, () => {
            console.log('Server is running...\n');
        });
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

init();