#!/usr/bin/env bash
# Запуск Traefik (reverse-proxy) на сервере с Ubuntu + Docker.
# Запускать из корня репозитория или откуда угодно: скрипт сам найдёт каталог проекта.
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

echo "→ Каталог сайтов: $ROOT/sites"
mkdir -p "$ROOT/sites"

echo "→ Let's Encrypt storage: $RP/letsencrypt"
mkdir -p "$RP/letsencrypt"
if [[ ! -f "$RP/letsencrypt/acme.json" ]]; then
  install -m 600 /dev/null "$RP/letsencrypt/acme.json"
  echo "   создан acme.json (600)"
else
  chmod 600 "$RP/letsencrypt/acme.json" 2>/dev/null || true
  echo "   acme.json уже есть"
fi

echo "→ $RP/.env"
if [[ ! -f "$RP/.env" ]]; then
  printf 'ACME_EMAIL=%s\n' "$ACME_EMAIL" >"$RP/.env"
  echo "   создан, ACME_EMAIL=$ACME_EMAIL"
else
  echo "   уже существует (не перезаписываю). Текущий ACME_EMAIL:"
  grep -E '^ACME_EMAIL=' "$RP/.env" || echo "   (строка ACME_EMAIL не найдена — проверьте файл вручную)"
fi

echo "→ Traefik (docker compose up)"
cd "$RP"
docker compose pull
docker compose up -d

echo ""
echo "Готово."
echo "  • HTTP/HTTPS: порты 80 и 443 на этом сервере"
echo "  • Панель Traefik (только локально): http://127.0.0.1:8080"
echo "  • Шаблоны сайтов: $ROOT/templates/"
echo "  • Каталог для сайтов: $ROOT/sites/"
echo ""
echo "Новый сайт: скопируйте templates/php-site (или static-site) в sites/имя, настройте .env, docker compose up -d"
