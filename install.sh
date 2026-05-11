#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="Sub2API Auto"
MODE="local"
APP_DIR=""
SERVER_PORT="${SERVER_PORT:-8080}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sub2api.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
DOMAIN="${DOMAIN:-}"
SUB2API_IMAGE="${SUB2API_IMAGE:-weishaw/sub2api:latest}"
TIMEZONE="${TZ:-Asia/Shanghai}"
RUN_MODE="${RUN_MODE:-standard}"
INSTALL_DOCKER="0"
START_SERVICES="1"

usage() {
  cat <<'EOF'
Sub2API Auto one-click installer

Usage:
  bash install.sh --mode local
  sudo bash install.sh --mode server --port 8080
  sudo bash install.sh --mode server --domain api.example.com --install-docker

Options:
  --mode local|server   Deployment mode. local binds to 127.0.0.1, server opens to the network.
  --local               Same as --mode local.
  --server              Same as --mode server.
  --dir PATH            Install directory. Default: ~/sub2api-local or /opt/sub2api.
  --port PORT           Host port for Sub2API. Default: 8080.
  --domain DOMAIN       Enable Caddy HTTPS reverse proxy for this domain.
  --email EMAIL         Admin email. Default: admin@sub2api.local.
  --password PASSWORD   Admin password. Default: auto-generated.
  --image IMAGE         Docker image. Default: weishaw/sub2api:latest.
  --timezone TZ         Timezone. Default: Asia/Shanghai.
  --run-mode MODE       Sub2API run mode. Default: standard.
  --install-docker      Install Docker automatically on Linux if it is missing.
  --no-start            Write files but do not start containers.
  -h, --help            Show this help.

Examples:
  bash install.sh --local
  sudo bash install.sh --server
  sudo bash install.sh --server --domain api.example.com --install-docker
EOF
}

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --local)
      MODE="local"
      shift
      ;;
    --server)
      MODE="server"
      shift
      ;;
    --dir)
      APP_DIR="${2:-}"
      shift 2
      ;;
    --port)
      SERVER_PORT="${2:-}"
      shift 2
      ;;
    --domain)
      DOMAIN="${2:-}"
      MODE="server"
      shift 2
      ;;
    --email)
      ADMIN_EMAIL="${2:-}"
      shift 2
      ;;
    --password)
      ADMIN_PASSWORD="${2:-}"
      shift 2
      ;;
    --image)
      SUB2API_IMAGE="${2:-}"
      shift 2
      ;;
    --timezone)
      TIMEZONE="${2:-}"
      shift 2
      ;;
    --run-mode)
      RUN_MODE="${2:-}"
      shift 2
      ;;
    --install-docker)
      INSTALL_DOCKER="1"
      shift
      ;;
    --no-start)
      START_SERVICES="0"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[ "$MODE" = "local" ] || [ "$MODE" = "server" ] || die "--mode must be local or server"
case "$SERVER_PORT" in
  ''|*[!0-9]*) die "--port must be a number" ;;
esac

if [ -z "$APP_DIR" ]; then
  if [ "$MODE" = "server" ]; then
    if [ "$(id -u)" -eq 0 ]; then
      APP_DIR="/opt/sub2api"
    else
      APP_DIR="$HOME/sub2api-server"
    fi
  else
    APP_DIR="$HOME/sub2api-local"
  fi
fi

USE_CADDY="0"
if [ -n "$DOMAIN" ]; then
  USE_CADDY="1"
fi

if [ "$MODE" = "local" ] || [ "$USE_CADDY" = "1" ]; then
  BIND_HOST="127.0.0.1"
else
  BIND_HOST="0.0.0.0"
fi

install_docker_if_needed() {
  if command -v docker >/dev/null 2>&1; then
    if ! docker info >/dev/null 2>&1 && [ "$INSTALL_DOCKER" = "1" ] && [ "$(uname -s)" = "Linux" ] && [ "$(id -u)" -eq 0 ]; then
      log "Docker is installed but not running, trying to start it"
      start_docker_service
    fi
    return 0
  fi

  [ "$INSTALL_DOCKER" = "1" ] || die "Docker is not installed. Install Docker first, or rerun with --install-docker on Linux."
  [ "$(uname -s)" = "Linux" ] || die "--install-docker only supports Linux. Install Docker Desktop manually on this system."
  [ "$(id -u)" -eq 0 ] || die "--install-docker needs root. Rerun with sudo."
  ensure_curl

  log "Installing Docker using Docker's official convenience script"
  curl -fsSL https://get.docker.com | sh
  start_docker_service
}

ensure_curl() {
  if command -v curl >/dev/null 2>&1; then
    return 0
  fi

  log "Installing curl"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y ca-certificates curl
  elif command -v yum >/dev/null 2>&1; then
    yum install -y ca-certificates curl
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache ca-certificates curl
  else
    die "curl is required to install Docker automatically, and this Linux distribution is not recognized. Install curl first."
  fi
}

start_docker_service() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable --now docker >/dev/null 2>&1 || true
  else
    service docker start >/dev/null 2>&1 || true
  fi
}

check_docker() {
  install_docker_if_needed
  command -v docker >/dev/null 2>&1 || die "Docker is not installed."
  if ! docker info >/dev/null 2>&1; then
    die "Docker is installed but not running. Start Docker, then rerun this script."
  fi
  if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
    die "Docker Compose is missing. Install Docker Compose v2, then rerun this script."
  fi
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    if [ "$USE_CADDY" = "1" ]; then
      docker compose -f docker-compose.yml -f docker-compose.caddy.yml "$@"
    else
      docker compose -f docker-compose.yml "$@"
    fi
  else
    if [ "$USE_CADDY" = "1" ]; then
      docker-compose -f docker-compose.yml -f docker-compose.caddy.yml "$@"
    else
      docker-compose -f docker-compose.yml "$@"
    fi
  fi
}

random_hex() {
  local bytes="$1"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  else
    od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
    printf '\n'
  fi
}

get_env_value() {
  local key="$1"
  if [ -f .env ]; then
    awk -v k="$key" '
      index($0, k "=") == 1 {
        sub("^[^=]*=", "")
        print
        exit
      }
    ' .env
  fi
}

set_env_value() {
  local key="$1"
  local value="$2"
  local file=".env"
  local tmp=".env.tmp"

  if [ -f "$file" ] && grep -q "^${key}=" "$file"; then
    awk -v k="$key" -v v="$value" '
      index($0, k "=") == 1 { print k "=" v; next }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    printf '%s=%s\n' "$key" "$value" >> "$file"
  fi
}

write_compose_file() {
  cat > docker-compose.yml <<'YAML'
services:
  sub2api:
    image: "${SUB2API_IMAGE:-weishaw/sub2api:latest}"
    container_name: sub2api
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    ports:
      - "${BIND_HOST:-127.0.0.1}:${SERVER_PORT:-8080}:8080"
    volumes:
      - ./data:/app/data
    environment:
      AUTO_SETUP: "true"
      SERVER_HOST: "0.0.0.0"
      SERVER_PORT: "8080"
      SERVER_MODE: "${SERVER_MODE:-release}"
      RUN_MODE: "${RUN_MODE:-standard}"
      DATABASE_HOST: "postgres"
      DATABASE_PORT: "5432"
      DATABASE_USER: "${POSTGRES_USER:-sub2api}"
      DATABASE_PASSWORD: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
      DATABASE_DBNAME: "${POSTGRES_DB:-sub2api}"
      DATABASE_SSLMODE: "disable"
      DATABASE_MAX_OPEN_CONNS: "${DATABASE_MAX_OPEN_CONNS:-50}"
      DATABASE_MAX_IDLE_CONNS: "${DATABASE_MAX_IDLE_CONNS:-10}"
      DATABASE_CONN_MAX_LIFETIME_MINUTES: "${DATABASE_CONN_MAX_LIFETIME_MINUTES:-30}"
      DATABASE_CONN_MAX_IDLE_TIME_MINUTES: "${DATABASE_CONN_MAX_IDLE_TIME_MINUTES:-5}"
      REDIS_HOST: "redis"
      REDIS_PORT: "6379"
      REDIS_PASSWORD: "${REDIS_PASSWORD:-}"
      REDIS_DB: "${REDIS_DB:-0}"
      REDIS_POOL_SIZE: "${REDIS_POOL_SIZE:-1024}"
      REDIS_MIN_IDLE_CONNS: "${REDIS_MIN_IDLE_CONNS:-10}"
      REDIS_ENABLE_TLS: "${REDIS_ENABLE_TLS:-false}"
      ADMIN_EMAIL: "${ADMIN_EMAIL:-admin@sub2api.local}"
      ADMIN_PASSWORD: "${ADMIN_PASSWORD:-}"
      JWT_SECRET: "${JWT_SECRET:?JWT_SECRET is required}"
      JWT_EXPIRE_HOUR: "${JWT_EXPIRE_HOUR:-24}"
      TOTP_ENCRYPTION_KEY: "${TOTP_ENCRYPTION_KEY:?TOTP_ENCRYPTION_KEY is required}"
      TZ: "${TZ:-Asia/Shanghai}"
      GEMINI_OAUTH_CLIENT_ID: "${GEMINI_OAUTH_CLIENT_ID:-}"
      GEMINI_OAUTH_CLIENT_SECRET: "${GEMINI_OAUTH_CLIENT_SECRET:-}"
      GEMINI_OAUTH_SCOPES: "${GEMINI_OAUTH_SCOPES:-}"
      GEMINI_QUOTA_POLICY: "${GEMINI_QUOTA_POLICY:-}"
      GEMINI_CLI_OAUTH_CLIENT_SECRET: "${GEMINI_CLI_OAUTH_CLIENT_SECRET:-}"
      ANTIGRAVITY_OAUTH_CLIENT_SECRET: "${ANTIGRAVITY_OAUTH_CLIENT_SECRET:-}"
      SECURITY_URL_ALLOWLIST_ENABLED: "${SECURITY_URL_ALLOWLIST_ENABLED:-false}"
      SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP: "${SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP:-false}"
      SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS: "${SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS:-false}"
      SECURITY_URL_ALLOWLIST_UPSTREAM_HOSTS: "${SECURITY_URL_ALLOWLIST_UPSTREAM_HOSTS:-}"
      UPDATE_PROXY_URL: "${UPDATE_PROXY_URL:-}"
      GATEWAY_IMAGE_STREAM_DATA_INTERVAL_TIMEOUT: "${GATEWAY_IMAGE_STREAM_DATA_INTERVAL_TIMEOUT:-900}"
      GATEWAY_IMAGE_STREAM_KEEPALIVE_INTERVAL: "${GATEWAY_IMAGE_STREAM_KEEPALIVE_INTERVAL:-10}"
      GATEWAY_IMAGE_CONCURRENCY_ENABLED: "${GATEWAY_IMAGE_CONCURRENCY_ENABLED:-false}"
      GATEWAY_IMAGE_CONCURRENCY_MAX_CONCURRENT_REQUESTS: "${GATEWAY_IMAGE_CONCURRENCY_MAX_CONCURRENT_REQUESTS:-0}"
      GATEWAY_IMAGE_CONCURRENCY_OVERFLOW_MODE: "${GATEWAY_IMAGE_CONCURRENCY_OVERFLOW_MODE:-reject}"
      GATEWAY_IMAGE_CONCURRENCY_WAIT_TIMEOUT_SECONDS: "${GATEWAY_IMAGE_CONCURRENCY_WAIT_TIMEOUT_SECONDS:-30}"
      GATEWAY_IMAGE_CONCURRENCY_MAX_WAITING_REQUESTS: "${GATEWAY_IMAGE_CONCURRENCY_MAX_WAITING_REQUESTS:-100}"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - sub2api-network
    healthcheck:
      test: ["CMD", "wget", "-q", "-T", "5", "-O", "/dev/null", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  postgres:
    image: postgres:18-alpine
    container_name: sub2api-postgres
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    command: ["postgres", "-c", "max_connections=${POSTGRES_MAX_CONNECTIONS:-300}"]
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: "${POSTGRES_USER:-sub2api}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
      POSTGRES_DB: "${POSTGRES_DB:-sub2api}"
      PGDATA: "/var/lib/postgresql/data"
      TZ: "${TZ:-Asia/Shanghai}"
    networks:
      - sub2api-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-sub2api} -d ${POSTGRES_DB:-sub2api}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  redis:
    image: redis:8-alpine
    container_name: sub2api-redis
    restart: unless-stopped
    ulimits:
      nofile:
        soft: 100000
        hard: 100000
    volumes:
      - ./redis_data:/data
    command: >
      sh -c 'redis-server
      --save 60 1
      --appendonly yes
      --appendfsync everysec
      $${REDIS_PASSWORD:+--requirepass "$$REDIS_PASSWORD"}'
    environment:
      TZ: "${TZ:-Asia/Shanghai}"
      REDIS_PASSWORD: "${REDIS_PASSWORD:-}"
      REDISCLI_AUTH: "${REDIS_PASSWORD:-}"
    networks:
      - sub2api-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s

networks:
  sub2api-network:
    driver: bridge
YAML
}

write_caddy_files() {
  if [ "$USE_CADDY" != "1" ]; then
    return 0
  fi

  cat > docker-compose.caddy.yml <<'YAML'
services:
  caddy:
    image: caddy:2-alpine
    container_name: sub2api-caddy
    restart: unless-stopped
    depends_on:
      - sub2api
    ports:
      - "${HTTP_PORT:-80}:80"
      - "${HTTPS_PORT:-443}:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy_data:/data
      - ./caddy_config:/config
    networks:
      - sub2api-network
YAML

  cat > Caddyfile <<EOF
${DOMAIN} {
    encode gzip zstd
    reverse_proxy sub2api:8080
}
EOF
}

write_helper_script() {
  cat > sub2apictl <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")"

get_env_value() {
  key="$1"
  if [ -f .env ]; then
    awk -v k="$key" '
      index($0, k "=") == 1 {
        sub("^[^=]*=", "")
        print
        exit
      }
    ' .env
  fi
}

use_caddy() {
  domain="$(get_env_value DOMAIN)"
  [ -n "$domain" ] && [ -f docker-compose.caddy.yml ]
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    if use_caddy; then
      docker compose -f docker-compose.yml -f docker-compose.caddy.yml "$@"
    else
      docker compose -f docker-compose.yml "$@"
    fi
  else
    if use_caddy; then
      docker-compose -f docker-compose.yml -f docker-compose.caddy.yml "$@"
    else
      docker-compose -f docker-compose.yml "$@"
    fi
  fi
}

show_help() {
  cat <<'HELP'
Usage: ./sub2apictl COMMAND

Commands:
  start       Start Sub2API
  stop        Stop Sub2API
  restart     Restart Sub2API
  status      Show container status
  logs        Follow Sub2API logs
  update      Pull latest image and restart
  url         Print access URL
  password    Print admin login info
  backup      Create a tar.gz backup in the current directory
  help        Show this help
HELP
}

case "${1:-help}" in
  start)
    compose up -d
    ;;
  stop)
    compose down
    ;;
  restart)
    compose restart
    ;;
  status)
    compose ps
    ;;
  logs)
    compose logs -f "${2:-sub2api}"
    ;;
  update)
    compose pull
    compose up -d
    ;;
  url)
    domain="$(get_env_value DOMAIN)"
    mode="$(get_env_value MODE)"
    port="$(get_env_value SERVER_PORT)"
    [ -n "$port" ] || port="8080"
    if [ -n "$domain" ]; then
      printf 'https://%s\n' "$domain"
    elif [ "${mode:-local}" = "local" ]; then
      printf 'http://localhost:%s\n' "$port"
    else
      printf 'http://SERVER_IP:%s\n' "$port"
    fi
    ;;
  password)
    if [ -f .credentials ]; then
      cat .credentials
    else
      admin_email="$(get_env_value ADMIN_EMAIL)"
      admin_password="$(get_env_value ADMIN_PASSWORD)"
      [ -n "$admin_email" ] || admin_email="admin@sub2api.local"
      [ -n "$admin_password" ] || admin_password="check logs"
      printf 'ADMIN_EMAIL=%s\nADMIN_PASSWORD=%s\n' "$admin_email" "$admin_password"
    fi
    ;;
  backup)
    backup_file="sub2api-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    paths=""
    for path in .env .credentials docker-compose.yml docker-compose.caddy.yml Caddyfile data postgres_data redis_data; do
      if [ -e "$path" ]; then
        paths="${paths} ${path}"
      fi
    done
    if [ -z "$paths" ]; then
      printf 'Nothing to backup.\n' >&2
      exit 1
    fi
    # shellcheck disable=SC2086
    tar czf "$backup_file" $paths
    printf 'Backup created: %s\n' "$backup_file"
    ;;
  help|-h|--help)
    show_help
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$1" >&2
    show_help
    exit 1
    ;;
esac
EOF
  chmod +x sub2apictl
}

write_credentials() {
  local url="$1"
  cat > .credentials <<EOF
SUB2API_URL=${url}
ADMIN_EMAIL=${ADMIN_EMAIL}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
INSTALL_DIR=${APP_DIR}
EOF
  chmod 600 .credentials 2>/dev/null || true
}

server_ip_hint() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 4 https://api.ipify.org 2>/dev/null || true
  fi
}

check_docker

log "Preparing ${APP_NAME} in ${APP_DIR}"
mkdir -p "$APP_DIR"
cd "$APP_DIR"
mkdir -p data postgres_data redis_data
if [ "$USE_CADDY" = "1" ]; then
  mkdir -p caddy_data caddy_config
fi

if [ -f .env ]; then
  backup_name=".env.backup.$(date +%Y%m%d%H%M%S)"
  cp .env "$backup_name"
  log "Existing .env found, backup saved as ${backup_name}"
else
  cat > .env <<'EOF'
# Generated by Sub2API Auto.
# You can edit this file and rerun ./sub2apictl restart.
EOF
fi

POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(get_env_value POSTGRES_PASSWORD)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(get_env_value REDIS_PASSWORD)}"
JWT_SECRET="${JWT_SECRET:-$(get_env_value JWT_SECRET)}"
TOTP_ENCRYPTION_KEY="${TOTP_ENCRYPTION_KEY:-$(get_env_value TOTP_ENCRYPTION_KEY)}"
EXISTING_ADMIN_PASSWORD="$(get_env_value ADMIN_PASSWORD || true)"

[ -n "$POSTGRES_PASSWORD" ] || POSTGRES_PASSWORD="$(random_hex 24)"
[ -n "$REDIS_PASSWORD" ] || REDIS_PASSWORD="$(random_hex 24)"
[ -n "$JWT_SECRET" ] || JWT_SECRET="$(random_hex 32)"
[ -n "$TOTP_ENCRYPTION_KEY" ] || TOTP_ENCRYPTION_KEY="$(random_hex 32)"
[ -n "$ADMIN_PASSWORD" ] || ADMIN_PASSWORD="$EXISTING_ADMIN_PASSWORD"
[ -n "$ADMIN_PASSWORD" ] || ADMIN_PASSWORD="$(random_hex 12)"

set_env_value MODE "$MODE"
set_env_value SUB2API_IMAGE "$SUB2API_IMAGE"
set_env_value BIND_HOST "$BIND_HOST"
set_env_value SERVER_PORT "$SERVER_PORT"
set_env_value SERVER_MODE "release"
set_env_value RUN_MODE "$RUN_MODE"
set_env_value DOMAIN "$DOMAIN"
set_env_value TZ "$TIMEZONE"
set_env_value POSTGRES_USER "sub2api"
set_env_value POSTGRES_PASSWORD "$POSTGRES_PASSWORD"
set_env_value POSTGRES_DB "sub2api"
set_env_value POSTGRES_MAX_CONNECTIONS "300"
set_env_value REDIS_PASSWORD "$REDIS_PASSWORD"
set_env_value REDIS_DB "0"
set_env_value ADMIN_EMAIL "$ADMIN_EMAIL"
set_env_value ADMIN_PASSWORD "$ADMIN_PASSWORD"
set_env_value JWT_SECRET "$JWT_SECRET"
set_env_value JWT_EXPIRE_HOUR "24"
set_env_value TOTP_ENCRYPTION_KEY "$TOTP_ENCRYPTION_KEY"
set_env_value SECURITY_URL_ALLOWLIST_ENABLED "false"
set_env_value SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP "false"
set_env_value SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS "false"

write_compose_file
write_caddy_files
write_helper_script

if [ "$USE_CADDY" = "1" ]; then
  ACCESS_URL="https://${DOMAIN}"
elif [ "$MODE" = "local" ]; then
  ACCESS_URL="http://localhost:${SERVER_PORT}"
else
  PUBLIC_IP="$(server_ip_hint)"
  if [ -n "$PUBLIC_IP" ]; then
    ACCESS_URL="http://${PUBLIC_IP}:${SERVER_PORT}"
  else
    ACCESS_URL="http://SERVER_IP:${SERVER_PORT}"
  fi
fi
write_credentials "$ACCESS_URL"

if [ "$START_SERVICES" = "1" ]; then
  log "Pulling Docker images"
  compose pull
  log "Starting Sub2API"
  compose up -d
  log "Container status"
  compose ps
else
  warn "Files written, containers not started because --no-start was used."
fi

cat <<EOF

Sub2API is ready.

URL:            ${ACCESS_URL}
Admin email:    ${ADMIN_EMAIL}
Admin password: ${ADMIN_PASSWORD}
Install dir:    ${APP_DIR}

Next step:
  Open the URL above in your browser and log in.
  No extra deployment command is needed.

Useful commands:
  cd ${APP_DIR}
  ./sub2apictl status
  ./sub2apictl logs
  ./sub2apictl update
  ./sub2apictl password

Credentials were saved to:
  ${APP_DIR}/.credentials
EOF

if [ "$MODE" = "server" ] && [ "$USE_CADDY" != "1" ]; then
  cat <<EOF

Server note:
  If the page is not reachable, open TCP port ${SERVER_PORT} in your cloud firewall/security group.
EOF
fi

if [ "$USE_CADDY" = "1" ]; then
  cat <<EOF

Domain note:
  Make sure ${DOMAIN} points to this server, and open TCP ports 80 and 443.
  These DNS/firewall steps are done in your domain/cloud provider panel, not inside this script.
EOF
fi
