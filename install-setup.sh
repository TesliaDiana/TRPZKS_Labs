set -e

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs postgresql nginx sudo

useradd -m student -s /bin/bash || true
useradd -m teacher -s /bin/bash || true
useradd -r -s /usr/sbin/nologin app || true
useradd -m operator -s /bin/bash || true

echo "student:12345678" | chpasswd
echo "teacher:12345678" | chpasswd
echo "operator:12345678" | chpasswd
chage -d 0 teacher
chage -d 0 operator

sudo -u postgres psql -c "CREATE DATABASE inventory;" || true
sudo -u postgres psql -c "CREATE USER myuser WITH PASSWORD 'mypassword';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE inventory TO myuser;"

mkdir -p /opt/mywebapp
cp -r src package.json /opt/mywebapp/
cd /opt/mywebapp
npm install
chown -R app:app /opt/mywebapp

mkdir -p /etc/mywebapp
cp /opt/mywebapp/templates/config.json /etc/mywebapp/config.json
cp /opt/mywebapp/templates/mywebapp.service /etc/systemd/system/
cp /opt/mywebapp/templates/mywebapp.socket /etc/systemd/system/
cp /opt/mywebapp/templates/nginx.conf /etc/nginx/sites-available/mywebapp

ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp, /usr/bin/systemctl stop mywebapp, /usr/bin/systemctl restart mywebapp, /usr/bin/systemctl status mywebapp, /usr/bin/systemctl reload nginx" > /etc/sudoers.d/operator

echo "23" > /home/student/gradebook
systemctl daemon-reload
systemctl enable --now mywebapp.socket
systemctl restart nginx

echo "Установка завершена!"