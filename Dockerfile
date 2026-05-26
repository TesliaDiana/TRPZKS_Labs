FROM node:20-slim

WORKDIR /app

# Копіюємо залежності та встановлюємо їх
COPY package*.json ./
RUN npm install --production

# Копіюємо весь інший код
COPY . .

# Відкриваємо порт застосунку
EXPOSE 8000

# Запускаємо сервер
CMD ["node", "src/server.js"]