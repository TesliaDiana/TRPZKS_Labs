const express = require('express');
const { pool } = require('./src/database');

const app = express();

app.use(express.json());

app.get('/', (req, res) => {
    res.json({
        message: "Inventory API Entry Point",
        endpoints: {
            items: "/items",
            health_alive: "/health/alive",
            health_ready: "/health/ready"
        }
    });
});

app.get('/health/alive', (req, res) => res.status(200).send('OK\n'));

app.get('/health/ready', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.status(200).send('OK\n');
    } catch (err) {
        res.status(500).send(err.message + '\n' + 'Database not connected\n');
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

        const result = await pool.query(
            'SELECT * FROM items WHERE id = $1',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).send('Not Found\n');
        }

        res.setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(result.rows[0], null, 2) + '\n');
    } catch (err) {
        res.status(500).send(err.message + '\n');
    }
});

app.post('/items', async (req, res) => {
    try {
        const { name, quantity } = req.body;

        if (!name || name.trim().length === 0) {
            return res
                .status(400)
                .send('Error: Name cannot be empty or consist only of spaces\n');
        }

        const result = await pool.query(
            'INSERT INTO items (name, quantity) VALUES ($1, $2) RETURNING *',
            [name.trim(), quantity || 0]
        );

        res.status(201).setHeader('Content-Type', 'application/json');

        res.send(JSON.stringify(result.rows[0], null, 2) + '\n');
    } catch (err) {
        res.status(500).send(err.message + '\n');
    }
});

module.exports = {
    app,
    pool
};