const express = require('express');
const { Pool } = require('pg');

const app = express();
const pool = new Pool({
    user: 'myuser',
    host: 'localhost',
    database: 'inventory',
    password: 'mypassword',
    port: 5432
});

app.use(express.json());

app.get('/', (req, res) => {
    res.setHeader('Content-Type', 'text/html');
    const html = `
        <html>
            <body style="font-family: sans-serif; line-height: 1.6; padding: 20px;">
                <h1>Inventory API Entry Point</h1>
                <p>Доступні маршрути:</p>
                <ul>
                    <li><a href="/items">GET /items</a> - Список предметів (HTML/JSON)</li>
                    <li>GET /items/:id - Пошук конкретного предмета</li>
                </ul>
                <hr>
                <p>Статус: <a href="/health/alive">Alive</a> | <a href="/health/ready">Ready</a></p>
            </body>
        </html>`;
    res.send(html + '\n');
});

app.get('/health/alive', (req, res) => res.status(200).send('OK\n'));

app.get('/health/ready', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.status(200).send('OK\n');
    } catch (e) {
        res.status(500).send('Database not connected\n');
    }
});

app.get('/items', async (req, res) => {
    try {
        const result = await pool.query('SELECT name, quantity FROM items ORDER BY name ASC');
        
        if (req.headers.accept && req.headers.accept.includes('text/html')) {
            let table = '<html><body><h2>Inventory</h2><table border="1"><tr><th>Назва</th><th>К-сть</th></tr>';
            result.rows.forEach(item => {
                table += `<tr><td>${item.name}</td><td>${item.quantity}</td></tr>`;
            });
            return res.send(table + '</table><br><a href="/">Назад</a></body></html>\n');
        }
        
        res.setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(result.rows, null, 2) + '\n');
    } catch (err) {
        res.status(500).send(err.message + '\n');
    }
});

app.get('/items/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const result = await pool.query('SELECT * FROM items WHERE id = $1', [id]);
        if (result.rows.length === 0) return res.status(404).send('Not Found\n');
        
        res.setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(result.rows[0], null, 2) + '\n');
    } catch (err) {
        res.status(500).send(err.message + '\n');
    }
});

app.post('/items', async (req, res) => {
    try {
        const { name, quantity } = req.body;
        const result = await pool.query(
            'INSERT INTO items (name, quantity) VALUES ($1, $2) RETURNING *',
            [name, quantity || 0]
        );
        res.status(201).setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(result.rows[0], null, 2) + '\n');
    } catch (err) {
        res.status(500).send(err.message + '\n');
    }
});

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
        app.listen(listenTarget, () => console.log('Server is running...\n'));
    } catch (e) {
        process.exit(1);
    }
}

init();