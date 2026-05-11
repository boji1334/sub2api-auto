[CmdletBinding()]
param(
    [ValidateSet("local", "server")]
    [string]$Mode = "local",

    [string]$Dir = "",
    [int]$Port = 8080,
    [string]$Domain = "",
    [string]$Email = "admin@sub2api.local",
    [string]$Password = "",
    [string]$Image = "weishaw/sub2api:latest",
    [string]$Timezone = "Asia/Shanghai",
    [string]$RunMode = "standard",
    [switch]$NoStart,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
    @'
Sub2API Auto one-click installer for Windows PowerShell

Usage:
  powershell -ExecutionPolicy Bypass -File .\install.ps1
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Mode local -Port 8080
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Mode server -Domain api.example.com

Options:
  -Mode local|server    local binds to 127.0.0.1, server opens to the network.
  -Dir PATH             Install directory. Default: %USERPROFILE%\sub2api-local.
  -Port PORT            Host port for Sub2API. Default: 8080.
  -Domain DOMAIN        Enable Caddy HTTPS reverse proxy for this domain.
  -Email EMAIL          Admin email. Default: admin@sub2api.local.
  -Password PASSWORD    Admin password. Default: auto-generated.
  -Image IMAGE          Docker image. Default: weishaw/sub2api:latest.
  -Timezone TZ          Timezone. Default: Asia/Shanghai.
  -RunMode MODE         Sub2API run mode. Default: standard.
  -NoStart              Write files but do not start containers.
  -Help                 Show this help.

Docker Desktop must be installed and running before using this script.
'@
}

if ($Help) {
    Show-Help
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($Domain)) {
    $Mode = "server"
}

if ([string]::IsNullOrWhiteSpace($Dir)) {
    if ($Mode -eq "server") {
        $Dir = Join-Path $env:USERPROFILE "sub2api-server"
    }
    else {
        $Dir = Join-Path $env:USERPROFILE "sub2api-local"
    }
}

$UseCaddy = -not [string]::IsNullOrWhiteSpace($Domain)
if ($Mode -eq "local" -or $UseCaddy) {
    $BindHost = "127.0.0.1"
}
else {
    $BindHost = "0.0.0.0"
}

function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function New-HexSecret([int]$Bytes) {
    $buffer = New-Object byte[] $Bytes
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $rng.GetBytes($buffer)
    }
    finally {
        $rng.Dispose()
    }
    return (($buffer | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Get-DotEnvValue([string]$Path, [string]$Key) {
    if (-not (Test-Path $Path)) {
        return ""
    }
    $escaped = [regex]::Escape($Key)
    foreach ($line in Get-Content -Path $Path) {
        if ($line -match "^$escaped=(.*)$") {
            return $Matches[1]
        }
    }
    return ""
}

function Set-DotEnvValue([string]$Path, [string]$Key, [string]$Value) {
    $lines = @()
    if (Test-Path $Path) {
        $lines = @(Get-Content -Path $Path)
    }

    $escaped = [regex]::Escape($Key)
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^$escaped=") {
            $lines[$i] = "$Key=$Value"
            $found = $true
        }
    }

    if (-not $found) {
        $lines += "$Key=$Value"
    }

    Set-Content -Path $Path -Value $lines -Encoding ascii
}

function Test-DockerReady {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker was not found. On Windows/macOS, install and start Docker Desktop first: https://www.docker.com/products/docker-desktop/ . Then rerun this script."
    }

    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker is installed but not running. Start Docker Desktop and wait until it says Docker is running, then rerun this script."
    }

    & docker compose version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose v2 was not found. Update Docker Desktop, then rerun this script."
    }
}

function Invoke-Compose([string[]]$ComposeArgs) {
    $args = @("compose", "-f", "docker-compose.yml")
    if ($script:UseCaddy) {
        $args += @("-f", "docker-compose.caddy.yml")
    }
    $args += $ComposeArgs
    & docker @args
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed: $($ComposeArgs -join ' ')"
    }
}

function Write-ComposeFile {
    $compose = @'
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
'@
    Set-Content -Path "docker-compose.yml" -Value $compose -Encoding ascii
}

function Write-CaddyFiles {
    if (-not $script:UseCaddy) {
        return
    }

    $caddyCompose = @'
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
'@
    Set-Content -Path "docker-compose.caddy.yml" -Value $caddyCompose -Encoding ascii

    $caddyfile = @"
${Domain} {
    encode gzip zstd
    reverse_proxy sub2api:8080
}
"@
    Set-Content -Path "Caddyfile" -Value $caddyfile -Encoding ascii
}

function Write-HelperScript {
    $helper = @'
param(
    [string]$Command = "help",
    [string]$Service = "sub2api"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Get-DotEnvValue([string]$Path, [string]$Key) {
    if (-not (Test-Path $Path)) {
        return ""
    }
    $escaped = [regex]::Escape($Key)
    foreach ($line in Get-Content -Path $Path) {
        if ($line -match "^$escaped=(.*)$") {
            return $Matches[1]
        }
    }
    return ""
}

$Domain = Get-DotEnvValue ".env" "DOMAIN"
$Mode = Get-DotEnvValue ".env" "MODE"
$Port = Get-DotEnvValue ".env" "SERVER_PORT"
$UseCaddy = -not [string]::IsNullOrWhiteSpace($Domain) -and (Test-Path "docker-compose.caddy.yml")

function Invoke-Compose([string[]]$ComposeArgs) {
    $args = @("compose", "-f", "docker-compose.yml")
    if ($script:UseCaddy) {
        $args += @("-f", "docker-compose.caddy.yml")
    }
    $args += $ComposeArgs
    & docker @args
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed: $($ComposeArgs -join ' ')"
    }
}

function Show-Help {
    @"
Usage: .\sub2apictl.ps1 COMMAND

Commands:
  start       Start Sub2API
  stop        Stop Sub2API
  restart     Restart Sub2API
  status      Show container status
  logs        Follow Sub2API logs
  update      Pull latest image and restart
  url         Print access URL
  password    Print admin login info
  backup      Create a zip backup in the current directory
  help        Show this help
"@
}

switch ($Command.ToLowerInvariant()) {
    "start" {
        Invoke-Compose @("up", "-d")
    }
    "stop" {
        Invoke-Compose @("down")
    }
    "restart" {
        Invoke-Compose @("restart")
    }
    "status" {
        Invoke-Compose @("ps")
    }
    "logs" {
        Invoke-Compose @("logs", "-f", $Service)
    }
    "update" {
        Invoke-Compose @("pull")
        Invoke-Compose @("up", "-d")
    }
    "url" {
        if (-not [string]::IsNullOrWhiteSpace($Domain)) {
            Write-Host "https://$Domain"
        }
        elseif ($Mode -eq "local") {
            Write-Host "http://localhost:$Port"
        }
        else {
            Write-Host "http://SERVER_IP:$Port"
        }
    }
    "password" {
        if (Test-Path ".credentials") {
            Get-Content ".credentials"
        }
        else {
            Write-Host "Open .env and check ADMIN_EMAIL / ADMIN_PASSWORD."
        }
    }
    "backup" {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backup = "sub2api-backup-$stamp.zip"
        $paths = @(".env", ".credentials", "docker-compose.yml", "docker-compose.caddy.yml", "Caddyfile", "data", "postgres_data", "redis_data") | Where-Object { Test-Path $_ }
        Compress-Archive -Path $paths -DestinationPath $backup -Force
        Write-Host "Backup created: $backup"
    }
    "help" {
        Show-Help
    }
    default {
        Write-Host "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
'@
    Set-Content -Path "sub2apictl.ps1" -Value $helper -Encoding ascii
}

Test-DockerReady

Write-Step "Preparing Sub2API Auto in $Dir"
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Set-Location $Dir
New-Item -ItemType Directory -Force -Path "data", "postgres_data", "redis_data" | Out-Null
if ($UseCaddy) {
    New-Item -ItemType Directory -Force -Path "caddy_data", "caddy_config" | Out-Null
}

if (Test-Path ".env") {
    $backup = ".env.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item ".env" $backup
    Write-Step "Existing .env found, backup saved as $backup"
}
else {
    Set-Content -Path ".env" -Value @("# Generated by Sub2API Auto.", "# You can edit this file and rerun .\sub2apictl.ps1 restart.") -Encoding ascii
}

$PostgresPassword = Get-DotEnvValue ".env" "POSTGRES_PASSWORD"
$RedisPassword = Get-DotEnvValue ".env" "REDIS_PASSWORD"
$JwtSecret = Get-DotEnvValue ".env" "JWT_SECRET"
$TotpKey = Get-DotEnvValue ".env" "TOTP_ENCRYPTION_KEY"
$ExistingAdminPassword = Get-DotEnvValue ".env" "ADMIN_PASSWORD"

if ([string]::IsNullOrWhiteSpace($PostgresPassword)) { $PostgresPassword = New-HexSecret 24 }
if ([string]::IsNullOrWhiteSpace($RedisPassword)) { $RedisPassword = New-HexSecret 24 }
if ([string]::IsNullOrWhiteSpace($JwtSecret)) { $JwtSecret = New-HexSecret 32 }
if ([string]::IsNullOrWhiteSpace($TotpKey)) { $TotpKey = New-HexSecret 32 }
if ([string]::IsNullOrWhiteSpace($Password)) { $Password = $ExistingAdminPassword }
if ([string]::IsNullOrWhiteSpace($Password)) { $Password = New-HexSecret 12 }

Set-DotEnvValue ".env" "MODE" $Mode
Set-DotEnvValue ".env" "SUB2API_IMAGE" $Image
Set-DotEnvValue ".env" "BIND_HOST" $BindHost
Set-DotEnvValue ".env" "SERVER_PORT" "$Port"
Set-DotEnvValue ".env" "SERVER_MODE" "release"
Set-DotEnvValue ".env" "RUN_MODE" $RunMode
Set-DotEnvValue ".env" "DOMAIN" $Domain
Set-DotEnvValue ".env" "TZ" $Timezone
Set-DotEnvValue ".env" "POSTGRES_USER" "sub2api"
Set-DotEnvValue ".env" "POSTGRES_PASSWORD" $PostgresPassword
Set-DotEnvValue ".env" "POSTGRES_DB" "sub2api"
Set-DotEnvValue ".env" "POSTGRES_MAX_CONNECTIONS" "300"
Set-DotEnvValue ".env" "REDIS_PASSWORD" $RedisPassword
Set-DotEnvValue ".env" "REDIS_DB" "0"
Set-DotEnvValue ".env" "ADMIN_EMAIL" $Email
Set-DotEnvValue ".env" "ADMIN_PASSWORD" $Password
Set-DotEnvValue ".env" "JWT_SECRET" $JwtSecret
Set-DotEnvValue ".env" "JWT_EXPIRE_HOUR" "24"
Set-DotEnvValue ".env" "TOTP_ENCRYPTION_KEY" $TotpKey
Set-DotEnvValue ".env" "SECURITY_URL_ALLOWLIST_ENABLED" "false"
Set-DotEnvValue ".env" "SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP" "false"
Set-DotEnvValue ".env" "SECURITY_URL_ALLOWLIST_ALLOW_PRIVATE_HOSTS" "false"

Write-ComposeFile
Write-CaddyFiles
Write-HelperScript

if ($UseCaddy) {
    $AccessUrl = "https://$Domain"
}
elseif ($Mode -eq "local") {
    $AccessUrl = "http://localhost:$Port"
}
else {
    $AccessUrl = "http://SERVER_IP:$Port"
}

$credentials = @(
    "SUB2API_URL=$AccessUrl",
    "ADMIN_EMAIL=$Email",
    "ADMIN_PASSWORD=$Password",
    "INSTALL_DIR=$Dir"
)
Set-Content -Path ".credentials" -Value $credentials -Encoding ascii

if (-not $NoStart) {
    Write-Step "Pulling Docker images"
    Invoke-Compose @("pull")
    Write-Step "Starting Sub2API"
    Invoke-Compose @("up", "-d")
    Write-Step "Container status"
    Invoke-Compose @("ps")
}
else {
    Write-Host "Files written, containers not started because -NoStart was used." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Sub2API is ready." -ForegroundColor Green
Write-Host ""
Write-Host "URL:            $AccessUrl"
Write-Host "Admin email:    $Email"
Write-Host "Admin password: $Password"
Write-Host "Install dir:    $Dir"
Write-Host ""
Write-Host "Next step:"
Write-Host "  Open the URL above in your browser and log in."
Write-Host "  No extra deployment command is needed."
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  cd `"$Dir`""
Write-Host "  powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 status"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 logs"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 update"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 password"
Write-Host ""
Write-Host "Credentials were saved to:"
Write-Host "  $Dir\.credentials"

if ($Mode -eq "server" -and -not $UseCaddy) {
    Write-Host ""
    Write-Host "Server note: if the page is not reachable, open TCP port $Port in your firewall/security group." -ForegroundColor Yellow
}

if ($UseCaddy) {
    Write-Host ""
    Write-Host "Domain note: make sure $Domain points to this server, and open TCP ports 80 and 443." -ForegroundColor Yellow
    Write-Host "These DNS/firewall steps are done in your domain/cloud provider panel, not inside this script." -ForegroundColor Yellow
}
