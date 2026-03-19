#!/usr/bin/env bash
# Запуск Traefik (reverse-proxy) на сервере с Ubuntu + Docker.
# Корень проекта (ROOT) — каталог, в котором лежат reverse-proxy/, templates/, …
# Типичный путь на сервере: /opt/<имя-репо> (например /opt/webserver).
# Каталог sites/ создаётся для удобства; файлы сайтов задаются в SITE_ROOT в .env (часто тоже под /opt).
#
# Переопределить email Let's Encrypt:
#   ACME_EMAIL=другой@mail.ru ./scripts/start-hosting.sh
#
set -euo pipefail

DEFAULT_ACME_EMAIL="idpro13@gmail.com"
ACME_EMAIL="${ACME_EMAIL:-$DEFAULT_ACME_EMAIL}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RP="$ROOT/reverse-proxy"

if ! command -v docker >/dev/null 2>&1; then
  echo "Ошибка: не найден docker. Установите Docker Engine." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Ошибка: не найден «docker compose». Нужен Docker Compose v2." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Ошибка: демон Docker недоступен (запустите сервис или добавьте пользователя в группу docker)." >&2
  exit 1
fi

echo "→ Сеть docker «web»"
if docker network inspect web >/dev/null 2>&1; then
  echo "   уже существует"
else
  docker network create web
  echo "   создана"
fi

echo "→ Каталог sites/ (необязательно; SITE_ROOT в шаблонах может указывать куда угодно): $ROOT/sites"
mkdir -p "$ROOT/sites"

DATA="$ROOT/traefikdata"
echo "→ Данные Traefik (Let's Encrypt и т.д.): $DATA"
mkdir -p "$DATA/letsencrypt"
if [[ ! -f "$DATA/letsencrypt/acme.json" ]]; then
  install -m 600 /dev/null "$DATA/letsencrypt/acme.json"
  echo "   создан letsencrypt/acme.json (600)"
else
  chmod 600 "$DATA/letsencrypt/acme.json" 2>/dev/null || true
  echo "   acme.json уже есть"
fi
# Старый путь (до переноса): напоминание при наличии
if [[ -f "$RP/letsencrypt/acme.json" ]]; then
  echo "   ⚠ есть $RP/letsencrypt/acme.json — перенесите в $DATA/letsencrypt/ и удалите старую папку (см. README)."
fi

echo "→ Пароль для панели Traefik (HTTPS): $DATA/dashboard-users"
if [[ ! -s "$DATA/dashboard-users" ]]; then
  if [[ -d "$DATA/dashboard-users" ]]; then
    echo "   Ошибка: $DATA/dashboard-users — это каталог. Удалите его и запустите скрипт снова." >&2
    exit 1
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    echo "   Ошибка: нужен openssl (например apt install openssl)." >&2
    exit 1
  fi
  DPASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
  docker run --rm httpd:2.4-alpine htpasswd -nbB admin "$DPASS" >"$DATA/dashboard-users"
  chmod 600 "$DATA/dashboard-users"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Панель Traefik по HTTPS: логин admin, пароль (скопируйте сейчас):"
  echo "  $DPASS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
else
  chmod 600 "$DATA/dashboard-users" 2>/dev/null || true
  echo "   файл уже есть (пароль не менялся)"
fi

echo "→ $RP/.env"
if [[ ! -f "$RP/.env" ]]; then
  {
    printf 'ACME_EMAIL=%s\n' "$ACME_EMAIL"
    printf '%s\n' 'TRAEFIK_DASHBOARD_HOST=traefik.example.com'
  } >"$RP/.env"
  echo "   создан: ACME_EMAIL, TRAEFIK_DASHBOARD_HOST=traefik.example.com"
  echo "   ⚠ замените TRAEFIK_DASHBOARD_HOST на свой поддомен (A-запись → IP сервера)"
else
  echo "   уже существует (не перезаписываю)."
  grep -E '^ACME_EMAIL=' "$RP/.env" || echo "   ⚠ нет ACME_EMAIL"
  if grep -q '^TRAEFIK_DASHBOARD_HOST=' "$RP/.env"; then
    grep -E '^TRAEFIK_DASHBOARD_HOST=' "$RP/.env"
  else
    printf '%s\n' 'TRAEFIK_DASHBOARD_HOST=traefik.example.com' >>"$RP/.env"
    echo "   ⚠ добавлена строка TRAEFIK_DASHBOARD_HOST=traefik.example.com — замените на свой поддомен"
  fi
fi

echo "→ Traefik (docker compose up)"
cd "$RP"
docker compose pull
docker compose up -d

echo ""
echo "Готово."
echo "  • HTTP/HTTPS: порты 80 и 443 на этом сервере"
DASH_HOST=$(grep '^TRAEFIK_DASHBOARD_HOST=' "$RP/.env" | cut -d= -f2- | tr -d '\r')
echo "  • Панель Traefik (HTTPS, Basic Auth): https://${DASH_HOST}"
echo "  • Только с сервера, без пароля: http://127.0.0.1:8080"
echo "  • Шаблоны сайтов: $ROOT/templates/"
echo "  • Каталог для сайтов: $ROOT/sites/"
echo ""
echo "Новый сайт: скопируйте templates/php-site (или static-site) в sites/имя, настройте .env, docker compose up -d"
