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
echo "  • Панель Traefik: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'IP_СЕРВЕРА'):8080 (из сети; без пароля — см. README)"
echo "  • Шаблоны сайтов: $ROOT/templates/"
echo "  • Каталог для сайтов: $ROOT/sites/"
echo ""
echo "Новый сайт: скопируйте templates/php-site (или static-site) в sites/имя, настройте .env, docker compose up -d"
