const express = require('express');
const { pool, runMigrations } = require('./src/database');

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

app.get('/health/alive', (req, res) => {
  res.status(200).send('OK');
});

app.get('/health/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).send('OK');
  } catch (err) {
    res.status(500).send('DB not ready');
    console.error(err);
  }
});

app.get('/items', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, quantity FROM items ORDER BY id ASC'
    );

    res.json(result.rows);
  } catch (err) {
    res.status(500).send(err.message);
    console.error(err);
  }
});

app.get('/items/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await pool.query(
      'SELECT id, name, quantity FROM items WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).send('Not Found');
    }

    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).send(err.message);
    console.error(err);
  }
});

app.post('/items', async (req, res) => {
  try {
    const { name, quantity } = req.body;

    if (!name || name.trim() === '') {
      return res.status(400).send('Invalid name');
    }

    const result = await pool.query(
      'INSERT INTO items (name, quantity) VALUES ($1, $2) RETURNING id, name, quantity',
      [name.trim(), quantity ?? 0]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).send(err.message);
    console.error(err);
  }
});

module.exports = { app, runMigrations, pool };