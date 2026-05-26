# Лабораторна робота №1: Розгортання Web-сервісу з автоматизацією

## 1. Варіант індивідуального завдання

Номер у групі - **23**, тож варіанти для завдання:

> V2 = (N % 2) + 1 = (23 % 2) + 1 = 1 + 1 = **2**
>
> V3 = (N % 3) + 1 = (23 % 3) + 1 = 2 + 1 = **3**
>
> V5 = (N % 5) + 1 = (23 % 5) + 1 = 3 + 1 = **4**

Характеристиками мого проєкту:

**Застосунок:** Simple Inventory — сервіс обліку обладнання.

**Спосіб конфігурації:** Конфігураційний файл за шляхом `/etc/mywebapp/config.<extension>`

**Порт застосунку:** `8000`

**База даних:** `PostgreSQL`

---

# 2. Документація веб-застосунку

## 2.1. Призначення застосунку

Simple Inventory (`mywebapp`) — це сервіс для обліку обладнання. Застосунок дозволяє:

- Виводити список усіх предметів в інвентарі (id,name);
- Створювати новий запис у системі обліку;
- Виводити детальну інформацію по записам в інвентарі (id, name, quantity, created_at).

Об’єкт інвентарю містить наступні поля:

- `id` — унікальний ідентифікатор;
- `name` — назва предмета;
- `quantity` — кількість;
- `created_at` — дата створення запису.

---

## 2.2. Стек технологій

- **ОС:** Ubuntu Server 24.04.4 LTS
- **Середовище виконання:** Node.js
- **Framework:** Express.js
- **База даних:** PostgreSQL
- **Reverse Proxy:** Nginx
- **Керування сервісами:** Systemd
- **Автоматизація:** Bash scripts

---

## 2.3. API ендпоінти

### Бізнес-логіка

- **`GET /`**
  
  Кореневий ендпоінт. Повертає HTML-сторінку зі списком доступних маршрутів.

---

- **`GET /items`**
  
  Повертає список усіх предметів інвентарю (`id`, `name`).

  Якщо клієнт запитує непідтримуваний формат — повертається HTTP `406 Not Acceptable`.

---

- **`POST /items`**
  
  Створює новий запис інвентарю.

  Очікує JSON:

```json
{
  "name": "Laptop",
  "quantity": 5
}
```

Валідація:
- `name` не може бути порожнім.

---

- **`GET /items/:id`**
  
  Повертає детальну інформацію про предмет:

- `id`
- `name`
- `quantity`
- `created_at`

Якщо запис не знайдено — HTTP `404 Not Found`.

---

## 2.4. Healthcheck ендпоінти

> Дані ендпоінти доступні лише локально (`127.0.0.1:8000`) і не проксіюються через Nginx назовні.

- **`GET /health/alive`**
  
  Завжди повертає:
  
```text
OK
```

та HTTP `200 OK`.

---

- **`GET /health/ready`**
  
  Перевіряє підключення до PostgreSQL.

Повертає:
- HTTP `200 OK`, якщо БД доступна;
- HTTP `500 Internal Server Error`, якщо БД недоступна.

---

## 2.5. Налаштування середовища (локальна розробка)

Для локального запуску необхідно:

### 1. Встановити Node.js та PostgreSQL

```bash
sudo apt update
sudo apt install -y nodejs npm postgresql
```

---

### 2. Створити БД та користувача PostgreSQL

```bash
sudo -u postgres psql
```

```sql
CREATE USER mywebapp WITH PASSWORD 'mypassword';
CREATE DATABASE mywebapp OWNER mywebapp;
GRANT ALL PRIVILEGES ON DATABASE mywebapp TO mywebapp;
```

---

### 3. Встановити залежності

```bash
npm install
```

---

### 4. Створити конфігураційний файл

```bash
sudo mkdir -p /etc/mywebapp
sudo nano /etc/mywebapp/config.json
```

Приклад конфігурації:

```json
{
  "host": "127.0.0.1",
  "port": 8000,
  "db": {
    "host": "127.0.0.1",
    "port": 5432,
    "user": "mywebapp",
    "password": "mypassword",
    "database": "mywebapp"
  }
}
```

---

### 5. Виконати міграцію БД

```bash
node src/migrate.js
```

---

### 6. Запустити застосунок

```bash
node src/app.js
```

---

# 3. Документація по розгортанню

## 3.1. Базовий образ віртуальної машини

Для розгортання використовується офіційний образ:

- Ubuntu Server 24.04.4 LTS  
- https://ubuntu.com/download/server

Для перевірки використовується Oracle VirtualBox.

---

## 3.2. Вимоги до ресурсів ВМ

- CPU — 2 ядра
- RAM — 4096 MB
- Disk — 35 GB
- Тип диска — Dynamically Allocated

---

## 3.3. Налаштування VirtualBox

Під час створення ВМ необхідно:

1. Вибрати ISO-образ Ubuntu Server.
2. Увімкнути мережевий адаптер:
   - `Settings → Network`
   - `Enable Network Adapter`
3. Тип мережі:
   - `Bridged Adapter` (Проміжний адаптер)

---

## 3.4. Встановлення Ubuntu

Під час встановлення необхідно:

- створити користувача (стандартно буде`vboxuser`);
- встановити пароль (12345678);
- увімкнути:
  
```text
Install OpenSSH Server
```

---

## 3.5. Підключення до ВМ

### Через консоль VirtualBox

Вхід виконується через terminal Ubuntu Server.

---

### Через SSH

Спочатку потрібно дізнатись IP-адресу ВМ:

```bash
ip -4 a
```

Після цього підключення:

```bash
ssh student@<IP>
```

---

## 3.6. Користувачі системи

У системі створюються наступні користувачі:

| Користувач | Призначення |
|---|---|
| student | Адміністрування проєкту |
| teacher | Перевірка лабораторної |
| operator | Обмежене керування сервісами |
| app | Системний користувач для запуску застосунку |

---

### Права користувачів

#### student

- sudo/root доступ
- пароль за замовчуванням:

```text
12345678
```

---

#### teacher

- sudo/root доступ
- пароль за замовчуванням:
  
```text
12345678
```

- пароль необхідно змінити при першому вході

---

#### operator

Має право виконувати лише:

```bash
sudo systemctl start mywebapp.service
sudo systemctl stop mywebapp.service
sudo systemctl restart mywebapp.service
sudo systemctl status mywebapp.service
sudo systemctl reload nginx
```

Пароль:
```text
12345678
```

Потрібна зміна пароля при першому вході.

---

#### app

- системний користувач;
- мінімальні права;
- використовується лише для запуску сервісу.

---

## 3.7. Systemd та Socket Activation

Застосунок запускається через:

```text
/etc/systemd/system/mywebapp.service
```

Перед запуском виконується:
- міграція бази даних;
- перевірка конфігурації.

Після реалізації звичайного systemd-unit використовується:

- `mywebapp.socket`
- socket activation

Це дозволяє автоматично запускати застосунок при першому HTTP-запиті.

---

## 3.8. Reverse Proxy (Nginx)

Nginx:

- слухає `0.0.0.0:80`;
- проксіює запити на:
  
```text
127.0.0.1:8000
```

- веде access/error logs;
- не дозволяє зовнішній доступ до:
  - `/health/alive`
  - `/health/ready`

---

## 3.9. Автоматизація розгортання

Автоматизація виконується через Bash-скрипти.

### Запуск:

### 1. Встановити git

```bash
sudo apt update
sudo apt install -y git
```

---

### 2. Клонувати репозиторій

```bash
git clone <repository_url>
```

---

### 3. Перейти до директорії

```bash
cd <repository_name>
```

---

### 4. Надати права на виконання

```bash
chmod +x installer.sh
```

---

### 5. Запустити автоматизацію

```bash
sudo ./installer.sh
```

---

Скрипт автоматично:

- встановлює необхідні пакети;
- створює користувачів;
- створює PostgreSQL базу даних;
- налаштовує Nginx;
- створює systemd units;
- запускає застосунок;
- створює файл:

```text
/home/student/gradebook
```

зі значенням:

```text
23
```

- блокує дефолтного користувача системи.

---

# 4. Інструкція з тестування системи

## 4.1. Перевірка роботи API

```bash
curl http://localhost/items
```

---

## 4.2. Створення нового предмета

```bash
curl -X POST \
-H "Content-Type: application/json" \
-d '{"name":"Laptop","quantity":5}' \
http://localhost/items
```

---

## 4.3. Перевірка конкретного предмета

```bash
curl http://localhost/items/1
```

---

## 4.4. Перевірка healthchecks

### Локально

```bash
curl http://127.0.0.1:8000/health/alive
curl http://127.0.0.1:8000/health/ready
```

Очікується:
- OK

---

### Через Nginx

```bash
curl http://localhost/health/alive
curl http://127.0.0.1:8000/health/ready
```

Очікується:
- HTTP `404`

---

## 4.5. Перевірка Socket Activation

```bash
sudo systemctl status mywebapp.socket
```

Очікується:

```text
active (listening)
```

---

## 4.6. Перевірка gradebook

```bash
cat /home/student/gradebook
```

Очікується:

```text
23
```

---

## 4.7. Перевірка прав operator

Перехід:

```bash
su - operator
```

---

### Дозволені команди

```bash
sudo systemctl restart mywebapp.service
sudo systemctl status mywebapp.service
sudo systemctl reload nginx
```

---

### Заборонені команди

```bash
sudo systemctl stop nginx
sudo systemctl restart postgresql
sudo apt update
sudo cat /etc/shadow
```

Очікується:
- Permission denied

---

## 4.8. Перевірка роботи PostgreSQL

```bash
sudo systemctl status postgresql
```

Очікується:

```text
active (running)
```