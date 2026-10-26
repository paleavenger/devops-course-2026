#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
REPO_DIR="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_DIR}/site/"

# 1. Разбор аргумента
DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN="--dry-run"
elif [ -n "${1:-}" ]; then
    echo "Неизвестный аргумент: $1" >&2
    echo "Использование: scripts/deploy.sh [--dry-run]" >&2
    exit 1
fi

# 2. Проверки перед доставкой
if [ ! -f "${LOCAL_DIR}index.html" ]; then
    echo "Ошибка: нет файла site/index.html, доставка отменена" >&2
    exit 1
fi

if [ -n "$(git -C "${REPO_DIR}" status --porcelain)" ]; then
    echo "Ошибка: есть незафиксированные изменения, доставка отменена" >&2
    exit 1
fi

# 3. Синхронизация
if ! rsync -avz --delete --chmod=D755,F644 ${DRY_RUN} \
        -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
        "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"; then
    echo "Ошибка: rsync завершился с ошибкой" >&2
    exit 1
fi

# 4. При пробном запуске проверка доступности не нужна
if [ -n "${DRY_RUN}" ]; then
    echo "Пробный запуск завершён, сервер не изменён"
    exit 0
fi

# 5. Проверка доступности ресурса с проверкой сертификата
if ! curl -fsS --max-time 10 --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: ${SITE_URL} недоступен после доставки" >&2
    exit 1
fi

echo "Готово, доставлен коммит $(git -C "${REPO_DIR}" rev-parse --short HEAD)"
exit 0