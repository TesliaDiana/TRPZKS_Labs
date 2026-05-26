if [ "$(id -u)" -ne 0 ]; then 
  echo "Помилка: Запускайте від root (sudo)!"
  exit 1
fi

echo "--- [0/7] Встановлення системних пакетів ---"
apt update
apt install -y nodejs npm postgresql nginx curl

echo "--- [1/7] Створення користувачів та налаштування прав ---"
systemctl stop mywebapp.service mywebapp.socket || true

N_NUMBER=23

setup_user() {
    local username=$1
    local is_system=$2
    local force_expire=$3

    if ! id "$username" >/dev/null 2>&1; then
        if [ "$is_system" = "true" ]; then 
            useradd -r -s /usr/sbin/nologin "$username"
        else
            if [ "$username" = "operator" ]; then
                useradd -m -g operator -s /bin/bash "$username" || useradd -m -s /bin/bash "$username"
            else
                useradd -m -s /bin/bash "$username"
            fi
        fi
    fi
    
    if [ "$is_system" != "true" ]; then
        echo "$username:12345678" | chpasswd
        if [ "$force_expire" = "true" ]; then
            passwd --expire "$username"
        fi
    fi
}

setup_user "student" "false" "false"
setup_user "teacher" "false" "true"  
setup_user "operator" "false" "true" 
setup_user "app" "true" "false"      

echo "$N_NUMBER" > /home/student/gradebook
chown student:student /home/student/gradebook
chmod 644 /home/student/gradebook
chmod 755 /home/student 

cat <<EOF > /etc/sudoers.d/kpi_users
student ALL=(ALL) NOPASSWD:ALL
teacher ALL=(ALL) NOPASSWD:ALL
operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp, /usr/bin/systemctl stop mywebapp, /usr/bin/systemctl restart mywebapp, /usr/bin/systemctl status mywebapp, /usr/bin/systemctl reload nginx
EOF

echo "--- [2/7] Налаштування бази даних PostgreSQL ---"
systemctl start postgresql
sudo -u postgres psql -c "DROP DATABASE IF EXISTS inventory;" || true
sudo -u postgres psql -c "CREATE USER myuser WITH PASSWORD 'mypassword';" || true
sudo -u postgres psql -c "CREATE DATABASE inventory OWNER myuser;" || true
sudo -u postgres psql -d inventory -c "GRANT ALL ON SCHEMA public TO myuser;"

echo "--- [3/7] Копіювання файлів застосунку ---"
mkdir -p /opt/mywebapp/src
mkdir -p /opt/mywebapp/templates

cp src/server.js /opt/mywebapp/src/
cp src/migrate.js /opt/mywebapp/src/
cp src/database.js /opt/mywebapp/src/

cat <<EOF > /opt/mywebapp/templates/config.json
{
  "db": {
    "user": "myuser",
    "host": "localhost",
    "database": "inventory",
    "password": "mypassword",
    "port": 5432
  }
}
EOF

echo "--- [4/7] Встановлення залежностей ---"
cd /opt/mywebapp && npm install express pg --no-audit --no-fund
chown -R app:app /opt/mywebapp

echo "--- [5/7] Systemd Конфігурація ---"
cat <<EOF > /etc/systemd/system/mywebapp.service
[Unit]
Description=MyWebApp Service
Requires=mywebapp.socket
After=postgresql.service

[Service]
User=app
WorkingDirectory=/opt/mywebapp
Environment=APP_CONFIG=/opt/mywebapp/templates/config.json
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

echo "--- [6/7] Nginx Конфігурація з перехопленням ---"
cat <<EOF > /etc/nginx/sites-available/mywebapp
server {
    listen 80;

    location /health/ {
        return 404;
    }

    location = / {
        if (\$http_accept ~* "text/html") {
            return 406;
        }
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
    }

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/default

echo "--- [7/7] Запуск сервісів та блокування ---"
systemctl daemon-reload
systemctl enable --now mywebapp.socket
systemctl restart nginx

DEFAULT_USER=$SUDO_USER
if [ -n "$DEFAULT_USER" ] && [ "$DEFAULT_USER" != "root" ]; then
    passwd -l "$DEFAULT_USER"
    gpasswd -d "$DEFAULT_USER" sudo 2>/dev/null || true
fi

echo "--- ІНСТАЛЯЦІЮ ЗАВЕРШЕНО ---"