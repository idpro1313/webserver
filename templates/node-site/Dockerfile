# Образ с npm. Добавьте зависимости в package.json.
# Если есть package-lock.json — замените RUN на: COPY package.json package-lock.json ./ && npm ci --omit=dev
FROM node:22-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

COPY . .

ENV NODE_ENV=production

EXPOSE 3000

CMD ["npm", "start"]
