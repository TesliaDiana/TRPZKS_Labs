if [ "$(id -u)" -ne 0 ]; then 
  echo "Error: Run as root (sudo)!"
  exit 1
fi

echo "--- [1/6] Користувачі, Директорії та Очищення ---"
systemctl stop mywebapp.service mywebapp.socket || true
rm -rf /opt/mywebapp

for u in student teacher operator app; do
    id "$u" &>/dev/null || useradd -m -s /bin/bash "$u"
done

echo "--- [2/6] База даних PostgreSQL ---"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS inventory;" || true
sudo -u postgres psql -c "CREATE USER myuser WITH PASSWORD 'mypassword';" || true
sudo -u postgres psql -c "CREATE DATABASE inventory OWNER myuser;" || true
sudo -u postgres psql -d inventory -c "GRANT ALL ON SCHEMA public TO myuser;"

mkdir -p /opt/mywebapp/src

echo "--- [3/6] Скрипт міграції (migrate.js) ---"
cat <<'EOF' > /opt/mywebapp/src/migrate.js
const { Pool } = require('pg');
const pool = new Pool({
    user: 'myuser', host: 'localhost', database: 'inventory',
    password: 'mypassword', port: 5432
});

async function runMigration() {
    try {
        console.log("Starting migration...");
        // Створення таблиці
        await pool.query(`
            CREATE TABLE IF NOT EXISTS items (
                id SERIAL PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                quantity INT DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
        // Створення індексу (вимога для міграцій)
        await pool.query(`CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);`);
        console.log("Migration finished successfully.");
        process.exit(0);
    } catch (err) {
        console.error("Migration failed:", err);
        process.exit(1);
    }
}
runMigration();
EOF

echo "--- [4/6] Код сервера (server.js) ---"
cat <<'EOF' > /opt/mywebapp/src/server.js
const express = require('express');
const { Pool } = require('pg');
const app = express();
const pool = new Pool({
    user: 'myuser', host: 'localhost', database: 'inventory',
    password: 'mypassword', port: 5432
});

app.use(express.json());

app.get('/', (req, res) => {
    res.setHeader('Content-Type', 'text/html');
    res.send('<html><body><h1>Inventory Service</h1><ul><li><a href="/items">Items List</a></li></ul></body></html>\n');
});

app.get('/items', async (req, res) => {
    try {
        const r = await pool.query('SELECT name, quantity FROM items ORDER BY id ASC');
        if (req.headers.accept && req.headers.accept.includes('text/html')) {
            let t = '<html><body><table border="1"><tr><th>Назва</th><th>Кількість</th></tr>';
            r.rows.forEach(i => t += `<tr><td>${i.name}</td><td>${i.quantity}</td></tr>`);
            return res.send(t + '</table><br><a href="/">Назад</a></body></html>\n');
        }
        res.setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(r.rows, null, 2) + '\n');
    } catch (err) { res.status(500).send(err.message + '\n'); }
});

app.get('/items/:id', async (req, res) => {
    try {
        const r = await pool.query('SELECT * FROM items WHERE id = $1', [req.params.id]);
        if (r.rows.length === 0) return res.status(404).send('Not Found\n');
        res.setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(r.rows[0], null, 2) + '\n');
    } catch (err) { res.status(500).send(err.message + '\n'); }
});

app.post('/items', async (req, res) => {
    try {
        const { name, quantity } = req.body;
        const r = await pool.query('INSERT INTO items (name, quantity) VALUES ($1, $2) RETURNING *', [name, quantity || 0]);
        res.status(201).setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(r.rows[0], null, 2) + '\n');
    } catch (err) { res.status(500).send(err.message + '\n'); }
});

app.get('/health/alive', (req, res) => res.status(200).send('OK\n'));
app.get('/health/ready', async (req, res) => {
    try { await pool.query('SELECT 1'); res.status(200).send('OK\n'); }
    catch (e) { res.status(500).send('DB Error\n'); }
});

const target = process.env.LISTEN_FDS ? { fd: 3 } : 8000;
app.listen(target, () => console.log('Service started\n'));
EOF

echo "--- [5/6] Встановлення залежностей та Міграція ---"
cd /opt/mywebapp && npm install express pg --no-audit --no-fund

node src/migrate.js
chown -R app:app /opt/mywebapp

echo "--- [6/6] Systemd та Nginx Reverse Proxy ---"

cat <<EOF > /etc/systemd/system/mywebapp.service
[Unit]
Description=MyWebApp Service
Requires=mywebapp.socket
After=postgresql.service
[Service]
User=app
WorkingDirectory=/opt/mywebapp
ExecStart=/usr/bin/node src/server.js
Restart=always
[Install]
WantedBy=multi-user.target
EOF


cat <<EOF > /etc/systemd/system/mywebapp.socket
[Socket]
ListenStream=8000
[Install]
WantedBy=sockets.target
EOF

cat <<EOF > /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    server_name localhost;
    access_log /var/log/nginx/mywebapp_access.log;

    # Дозволяємо тільки корінь та бізнес-логіку
    location = / { proxy_pass http://localhost:8000; }
    location /items { proxy_pass http://localhost:8000; }

    # Забороняємо все інше (включаючи /health)
    location / { return 404; }
}
EOF

ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/default
echo "operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl *" > /etc/sudoers.d/operator

systemctl daemon-reload
systemctl enable --now mywebapp.socket
systemctl restart nginx

echo "--- ІНСТАЛЯЦІЯ ЗАВЕРШЕНА ---"