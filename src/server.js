const express = require('express');
const { pool, runMigrations } = require('./database');

const app = express();
app.use(express.json());

app.get('/', (req, res) => {
    res.send(`
        <h1>Simple Inventory API</h1>
        <ul>
            <li><a href="/items">GET /items</a></li>
            <li>POST /items</li>
            <li>GET /items/:id</li>
        </ul>
    `);
});

app.get('/health/alive', (req, res) => res.status(200).send('OK'));
app.get('/health/ready', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.status(200).send('OK');
    } catch (e) {
        res.status(500).send('Database not connected');
    }
});

app.get('/items', async (req, res) => {
    const result = await pool.query('SELECT id, name FROM items');
    
    if (req.headers.accept && req.headers.accept.includes('text/html')) {
        let table = '<table border="1"><tr><th>ID</th><th>Name</th></tr>';
        result.rows.forEach(item => {
            table += `<tr><td>${item.id}</td><td>${item.name}</td></tr>`;
        });
        return res.send(table + '</table>');
    }
    res.json(result.rows.map(r => ({ id: r.id, name: r.name })));
});

app.post('/items', async (req, res) => {
    const { name, quantity } = req.body;
    const result = await pool.query(
        'INSERT INTO items (name, quantity) VALUES ($1, $2) RETURNING id',
        [name, quantity]
    );
    res.status(201).json({ id: result.rows[0].id });
});

app.get('/items/:id', async (req, res) => {
    const result = await pool.query('SELECT * FROM items WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).send('Not Found');
    
    const item = result.rows[0];
    if (req.headers.accept && req.headers.accept.includes('text/html')) {
        return res.send(`
            <h1>Item Details</h1>
            <p>ID: ${item.id}</p>
            <p>Name: ${item.name}</p>
            <p>Quantity: ${item.quantity}</p>
            <p>Created At: ${item.created_at}</p>
        `);
    }
    res.json(item);
});

const start = async () => {
    await runMigrations();
    const listenTarget = process.env.LISTEN_FDS ? { fd: 3 } : 8000;
    app.listen(listenTarget, () => {
        console.log('Inventory Service started');
    });
};

start();