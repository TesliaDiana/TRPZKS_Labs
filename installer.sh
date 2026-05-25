if [ "$(id -u)" -ne 0 ]; then 
  echo "Помилка: Запускайте від root (через sudo)!"
  exit 1
fi

echo "--- [1/6] Створення користувачів та налаштування безпеки ---"
systemctl stop mywebapp.service mywebapp.socket || true

N_NUMBER=23

setup_user() {
    local username=$1
    local is_system=$2
    if ! id "$username" >/dev/null 2>&1; then
        if [ "$is_system" = "true" ]; then 
            useradd -r -s /usr/sbin/nologin "$username"
        else
            useradd -m -s /bin/bash "$username"
        fi
    fi
    
    if [ "$is_system" != "true" ]; then
        echo "$username:12345678" | chpasswd
        passwd --expire "$username"
    fi
}

setup_user "student" "false"
setup_user "teacher" "false"
setup_user "operator" "false"
setup_user "app" "true"

echo "$N_NUMBER" > /home/student/gradebook
chown student:student /home/student/gradebook
chmod 644 /home/student/gradebook

cat <<EOF > /etc/sudoers.d/kpi_users
student ALL=(ALL) NOPASSWD:ALL
teacher ALL=(ALL) NOPASSWD:ALL
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp, /usr/bin/systemctl stop mywebapp, /usr/bin/systemctl restart mywebapp, /usr/bin/systemctl status mywebapp, /usr/bin/systemctl reload nginx
EOF

echo "--- [2/6] База даних PostgreSQL ---"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS inventory;" || true
sudo -u postgres psql -c "CREATE USER myuser WITH PASSWORD 'mypassword';" || true
sudo -u postgres psql -c "CREATE DATABASE inventory OWNER myuser;" || true
sudo -u postgres psql -d inventory -c "GRANT ALL ON SCHEMA public TO myuser;"

echo "--- [3/6] Файли застосунку ---"
mkdir -p /opt/mywebapp/src

cat <<'EOF' > /opt/mywebapp/src/migrate.js
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
EOF

cat <<'EOF' > /opt/mywebapp/src/server.js
const express = require('express');
const { Pool } = require('pg');
const app = express();
const pool = new Pool({user:'myuser',host:'localhost',database:'inventory',password:'mypassword',port:5432});
app.use(express.json());

app.get('/', (req, res) => {
    res.setHeader('Content-Type', 'text/html');
    res.send('<html><body><h1>KPI Inventory API</h1><ul><li><a href="/items">Items</a></li></ul></body></html>\n');
});

app.get('/items', async (req, res) => {
    try {
        const r = await pool.query('SELECT name, quantity FROM items ORDER BY id ASC');
        if (req.headers.accept && req.headers.accept.includes('text/html')) {
            let t = '<html><body><table border="1"><tr><th>Назва</th><th>К-сть</th></tr>';
            r.rows.forEach(i => t += `<tr><td>${i.name}</td><td>${i.quantity}</td></tr>`);
            return res.send(t + '</table></body></html>\n');
        }
        res.setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(r.rows, null, 2) + '\n');
    } catch (e) { res.status(500).send(e.message + '\n'); }
});

app.get('/items/:id', async (req, res) => {
    try {
        const r = await pool.query('SELECT * FROM items WHERE id = $1', [req.params.id]);
        if (r.rows.length === 0) return res.status(404).send('Not Found\n');
        res.setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(r.rows[0], null, 2) + '\n');
    } catch (e) { res.status(500).send(e.message + '\n'); }
});

app.post('/items', async (req, res) => {
    try {
        const { name, quantity } = req.body;
        const r = await pool.query('INSERT INTO items (name, quantity) VALUES ($1, $2) RETURNING *', [name, quantity]);
        res.status(201).setHeader('Content-Type', 'application/json');
        res.send(JSON.stringify(r.rows[0], null, 2) + '\n');
    } catch (e) { res.status(500).send(e.message + '\n'); }
});

app.get('/health/alive', (req, res) => res.status(200).send('OK\n'));
app.get('/health/ready', async (req, res) => {
    try { await pool.query('SELECT 1'); res.send('OK\n'); } catch (e) { res.status(500).send('ERR\n'); }
});

const port = process.env.LISTEN_FDS ? { fd: 3 } : 8000;
app.listen(port);
EOF

echo "--- [4/6] Встановлення залежностей ---"
cd /opt/mywebapp && npm install express pg --no-audit --no-fund
chown -R app:app /opt/mywebapp

echo "--- [5/6] Systemd: Socket Activation та Міграція перед стартом ---"
cat <<EOF > /etc/systemd/system/mywebapp.service
[Unit]
Description=MyWebApp Service
Requires=mywebapp.socket
After=postgresql.service

[Service]
User=app
WorkingDirectory=/opt/mywebapp
ExecStartPre=/usr/bin/node /opt/mywebapp/src/migrate.js
ExecStart=/usr/bin/node /opt/mywebapp/src/server.js
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

echo "--- [6/6] Nginx: Reverse Proxy та Логування ---"
cat <<EOF > /etc/nginx/sites-available/mywebapp
server {
    listen 80;
    access_log /var/log/nginx/webapp_access.log;

    location = / { proxy_pass http://localhost:8000; }
    location /items { proxy_pass http://localhost:8000; }
    location / { return 404; }
}
EOF
ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/default

systemctl daemon-reload
systemctl enable --now mywebapp.socket
systemctl restart nginx

echo "--- ІНСТАЛЯЦІЮ ЗАВЕРШЕНО УСПІШНО ---"