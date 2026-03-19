# Мультисайт на Docker (Traefik + отдельные контейнеры)

**Traefik** слушает 80/443, по **labels** на контейнерах сам строит маршруты и выпускает сертификаты Let’s Encrypt. Новый сайт = копия шаблона + правка `.env`, **без** общего конфига прокси.

Стек бэкенда как в [dandangers](https://github.com/idpro1313/dandangers): **nginx** ± **PHP-FPM** в отдельном `docker-compose` на сайт.

## На сервере (Ubuntu + Docker)

### Быстрый запуск (скрипт)

Склонируйте репозиторий на сервер (например в `/opt/hosting`), затем:

```bash
cd /opt/hosting   # корень этого проекта
chmod +x scripts/start-hosting.sh
./scripts/start-hosting.sh
```

Скрипт создаст сеть `web`, каталоги `sites/` и `reverse-proxy/letsencrypt/acme.json`, при первом запуске — `reverse-proxy/.env` с **ACME_EMAIL** для Let’s Encrypt (по умолчанию `idpro13@gmail.com`). Чтобы указать другой email:

```bash
ACME_EMAIL=you@example.com ./scripts/start-hosting.sh
```

Повторный запуск обновит образ Traefik и перезапустит контейнер; существующий `.env` **не перезаписывается**.

### Вручную (без скрипта)

```bash
docker network create web
cd reverse-proxy
cp env.example .env
# пропишите ACME_EMAIL в .env
mkdir -p letsencrypt
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json
docker compose up -d
```

- Панель Traefik: `http://127.0.0.1:8080` на самом сервере или через SSH:  
  `ssh -L 8080:127.0.0.1:8080 user@31.15.19.102` → открыть http://localhost:8080

### 3. DNS

Для каждого домена A-запись на IP сервера (например `31.15.19.102`). Порты **80** и **443** должны быть доступны с интернета.

### 4. Новый сайт

```bash
cp -r templates/php-site /opt/hosting/sites/mysite
cd /opt/hosting/sites/mysite
cp env.example .env
```

В `.env` задайте:

- `SITE_CONTAINER_NAME` — уникальное имя контейнера nginx;
- `SITE_ROOT` — путь к файлам сайта на хосте;
- `TRAEFIK_ROUTER` — уникальное имя роутера (латиница, без пробелов);
- `TRAEFIK_RULE` — правило `Host`, например:  
  `Host(\`dandangers.ru\`) || Host(\`www.dandangers.ru\`)`  
  (в файле `.env` обратные кавычки вокруг доменов обязательны.)

```bash
docker compose up -d
```

Traefik подхватит контейнер за несколько секунд; сертификат запросится при первом HTTPS-запросе.

### Статика без PHP

Используйте шаблон `templates/static-site` так же, с теми же переменными Traefik в `.env`.

### Node.js (npm)

```bash
cp -r templates/node-site /opt/hosting/sites/myapp
cd /opt/hosting/sites/myapp
cp env.example .env
```

В `.env`: `SITE_CONTAINER_NAME`, `NODE_IMAGE_NAME`, **`APP_PORT`** (порт процесса Node внутри контейнера, по умолчанию `3000`), `TRAEFIK_ROUTER`, `TRAEFIK_RULE`.

Подставьте свой код в эту папку (рядом с `Dockerfile` и `docker-compose.yml`): отредактируйте **`package.json`**, **`server.js`** или укажите в `scripts.start` свой entrypoint (например после `tsc` — `node dist/index.js`). Затем:

```bash
docker compose build --no-cache
docker compose up -d
```

Образ собирается через **Dockerfile** (`npm install --omit=dev` при сборке). Если добавите **`package-lock.json`**, имеет смысл в Dockerfile заменить установку зависимостей на `npm ci --omit=dev` (см. комментарий в `Dockerfile`).

## Структура

```
scripts/
  start-hosting.sh # первичный запуск Traefik на сервере
reverse-proxy/     # Traefik, порты 80, 443; dashboard на 127.0.0.1:8080
sites/             # создаётся скриптом; сюда копируйте шаблоны сайтов
templates/
  php-site/
  static-site/
  node-site/      # Node + npm, Traefik → порт APP_PORT
```

## Важно

- У каждого сайта **свой** `TRAEFIK_ROUTER` и **свой** `SITE_CONTAINER_NAME`.
- Если несколько сетей у контейнера, label `traefik.docker.network=web` задаёт сеть до бэкенда (уже в шаблонах).
- Сертификаты: resolver с именем `le` в Traefik; в labels указано `tls.certresolver=le`.
