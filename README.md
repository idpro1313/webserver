# Мультисайт на Docker (Traefik + отдельные контейнеры)

**Traefik** слушает 80/443, по **labels** на контейнерах сам строит маршруты и выпускает сертификаты Let’s Encrypt. Новый сайт = копия шаблона + правка `.env`, **без** общего конфига прокси.

Стек бэкенда как в [dandangers](https://github.com/idpro1313/dandangers): **nginx** ± **PHP-FPM** в отдельном `docker-compose` на сайт.

### Имя папки на сервере и где лежат сайты

- **Корень репозитория** — каталог клона; на сервере обычно **`/opt/webserver`** (или `/opt/<имя-репо>`).
- **`traefikdata/`** создаётся **внутри этого корня**, рядом с `reverse-proxy/` (см. раздел ниже).
- **Общий префикс на сервере — `/opt`:** репозиторий удобно класть в **`/opt/<имя-репо>`** (например `/opt/webserver`), файлы сайтов — в **`/opt/<сайт>/...`** или рядом. В `.env` в **`SITE_ROOT`** укажите абсолютный путь (может быть и вне `/opt`, если нужно). Папка **`sites/`** внутри репозитория — только удобное место для compose из шаблонов; её можно не использовать.
- **Node:** обычно код лежит в той же папке, что и `docker-compose.yml` шаблона; при желании можно вынести код и подключать через контекст сборки / тома (настраивается отдельно).

## На сервере (Ubuntu + Docker)

### Быстрый запуск (скрипт)

Склонируйте репозиторий под **`/opt`** (имя папки — как у репозитория, чаще всего `webserver`):

```bash
cd /opt/webserver   # корень репозитория
chmod +x scripts/start-hosting.sh
./scripts/start-hosting.sh
```

Скрипт создаст сеть `web`, каталоги `sites/`, **`traefikdata/letsencrypt/acme.json`**, файл **`traefikdata/dashboard-users`** (пароль для HTTPS-панели; случайный пароль выводится в консоль), при первом запуске — `reverse-proxy/.env` с **ACME_EMAIL** и заготовкой **TRAEFIK_DASHBOARD_HOST** (замените на свой поддомен). Чтобы указать другой email:

```bash
ACME_EMAIL=you@example.com ./scripts/start-hosting.sh
```

Повторный запуск обновит образ Traefik и перезапустит контейнер; существующий `.env` **не перезаписывается**.

### Вручную (без скрипта)

```bash
docker network create web
cd /opt/webserver   # корень репозитория на сервере
mkdir -p traefikdata/letsencrypt
touch traefikdata/letsencrypt/acme.json
chmod 600 traefikdata/letsencrypt/acme.json
cd reverse-proxy
cp env.example .env
# пропишите ACME_EMAIL и TRAEFIK_DASHBOARD_HOST (поддомен панели, A → IP сервера)
cd ..
docker run --rm httpd:2.4-alpine htpasswd -nbB admin 'ВАШ_ПАРОЛЬ' > traefikdata/dashboard-users
chmod 600 traefikdata/dashboard-users
cd reverse-proxy
docker compose up -d
```

### Панель Traefik (админка)

- **С интернета — с паролем:** `https://<TRAEFIK_DASHBOARD_HOST>` (тот же Let’s Encrypt, что и у сайтов). Логин/пароль задаются в **`traefikdata/dashboard-users`** (формат htpasswd). Скрипт `start-hosting.sh` при первом запуске создаёт этот файл и один раз печатает случайный пароль (логин **`admin`**).
- **С самого сервера — без пароля:** `http://127.0.0.1:8080` (порт привязан только к localhost, снаружи недоступен).

Поддомен из **`TRAEFIK_DASHBOARD_HOST`** в `reverse-proxy/.env` должен иметь **A-запись** на IP сервера. Смена пароля: см. `reverse-proxy/dashboard-users.README.txt`.

### 3. DNS

Для каждого домена и для **поддомена панели** (`TRAEFIK_DASHBOARD_HOST`) — A-запись на IP сервера (например `31.15.19.102`). Порты **80** и **443** должны быть доступны с интернета.

### 4. Новый сайт

Пример: compose-файлы внутри репозитория, **код сайта** — в любом каталоге на сервере.

```bash
cd /opt/webserver   # корень репозитория
cp -r templates/php-site sites/mysite
cd sites/mysite
cp env.example .env
```

В `.env` задайте:

- `SITE_CONTAINER_NAME` — уникальное имя контейнера nginx;
- `SITE_ROOT` — **абсолютный** путь к файлам сайта на хосте (часто под `/opt`, например `/opt/dandangers/html`; может быть и внутри репо: `/opt/webserver/sites/mysite/html`);
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
cd /opt/webserver
cp -r templates/node-site sites/myapp
cd sites/myapp
cp env.example .env
```

В `.env`: `SITE_CONTAINER_NAME`, `NODE_IMAGE_NAME`, **`APP_PORT`** (порт процесса Node внутри контейнера, по умолчанию `3000`), `TRAEFIK_ROUTER`, `TRAEFIK_RULE`.

Подставьте свой код в эту папку (рядом с `Dockerfile` и `docker-compose.yml`): отредактируйте **`package.json`**, **`server.js`** или укажите в `scripts.start` свой entrypoint (например после `tsc` — `node dist/index.js`). Затем:

```bash
docker compose build --no-cache
docker compose up -d
```

Образ собирается через **Dockerfile** (`npm install --omit=dev` при сборке). Если добавите **`package-lock.json`**, имеет смысл в Dockerfile заменить установку зависимостей на `npm ci --omit=dev` (см. комментарий в `Dockerfile`).

## Где Traefik хранит данные

В контейнер монтируется каталог **`traefikdata/`** (на уровень выше `reverse-proxy/`):

- **`letsencrypt/acme.json`** — сертификаты Let’s Encrypt;
- **`dashboard-users`** — логин/пароль Basic Auth для панели по HTTPS.

При пересборке образа Traefik эти файлы на хосте **сохраняются**.

Раньше использовался `reverse-proxy/letsencrypt/` — если там уже есть `acme.json`, перенесите:

```bash
mkdir -p traefikdata/letsencrypt
mv reverse-proxy/letsencrypt/acme.json traefikdata/letsencrypt/
rmdir reverse-proxy/letsencrypt 2>/dev/null || true
```

При необходимости позже можно добавить в `traefikdata/` другие тома (логи, динамический конфиг) и подключить их в `reverse-proxy/docker-compose.yml`.

## Структура

```
scripts/
  start-hosting.sh # первичный запуск Traefik на сервере
traefikdata/       # постоянные данные Traefik (на хосте); в git не коммитится
  letsencrypt/     # acme.json — сертификаты LE
  dashboard-users    # htpasswd для панели по HTTPS
reverse-proxy/     # Traefik: 80, 443; панель HTTPS с паролем + 127.0.0.1:8080 без пароля
sites/             # опционально; шаблоны можно копировать куда угодно. SITE_ROOT — любой путь на диске (PHP/статика)
templates/
  php-site/
  static-site/
  node-site/      # Node + npm, Traefik → порт APP_PORT
```

## Важно

- Имя Docker-контейнера Traefik: **`traefik_proxy`**. Если у вас ещё запущен старый **`hosting_traefik`**, остановите и удалите его перед `docker compose up`, иначе будет конфликт портов.
- У каждого сайта **свой** `TRAEFIK_ROUTER` и **свой** `SITE_CONTAINER_NAME`.
- Если несколько сетей у контейнера, label `traefik.docker.network=web` задаёт сеть до бэкенда (уже в шаблонах).
- Сертификаты: resolver с именем `le` в Traefik; в labels указано `tls.certresolver=le`.
