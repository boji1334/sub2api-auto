# Sub2API Auto

一键部署 [Sub2API](https://github.com/Wei-Shaw/sub2api) 的小工具。目标是让新手也能用一条命令把 Sub2API 跑起来，支持本地部署和服务器部署。

This is a tiny one-click deployment helper for [Sub2API](https://github.com/Wei-Shaw/sub2api). It is designed for beginners and supports both local and server deployments.

## 小白只看这里

macOS / Windows 本地电脑先安装并打开 Docker Desktop，然后运行：

```bash
bash install.sh --local
```

Windows 运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Ubuntu 服务器运行：

```bash
sudo bash install.sh --server --install-docker
```

有域名就运行：

```bash
sudo bash install.sh --server --domain api.example.com --install-docker
```

完成后终端会直接显示访问地址、管理员邮箱、管理员密码。

跑完这个命令后，不需要再执行第二条部署命令。你只需要打开终端里显示的地址，用显示的管理员邮箱和密码登录。

但有两件事脚本不能替你在云厂商后台完成：

- 服务器 IP 访问打不开时，去云服务器安全组/防火墙放行端口 `8080`
- 域名访问时，先把域名解析到服务器 IP，并放行 `80` 和 `443`

## Quick Start

On macOS / Windows, install and start Docker Desktop for local use, then run:

```bash
bash install.sh --local
```

On Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

On an Ubuntu server:

```bash
sudo bash install.sh --server --install-docker
```

With a domain:

```bash
sudo bash install.sh --server --domain api.example.com --install-docker
```

The installer prints the URL, admin email, and admin password when it finishes.

After the command finishes, no second deployment command is required. Open the printed URL and log in with the printed admin email and password.

Two things cannot be done inside the script because they belong to your cloud/domain provider:

- If the server IP URL does not open, allow port `8080` in your cloud firewall/security group
- If using a domain, point the domain to your server IP and allow ports `80` and `443`

---

## 中文说明

### 它会做什么

- 自动生成 `docker-compose.yml`
- 自动生成 PostgreSQL、Redis、JWT、TOTP 密钥
- 自动生成管理员账号密码，并保存到 `.credentials`
- 自动创建数据目录：`data/`、`postgres_data/`、`redis_data/`
- 自动拉取并启动 `weishaw/sub2api:latest`
- 服务器模式可选域名，自动生成 Caddy HTTPS 反向代理配置

### 准备工作

本地电脑：

- Windows / macOS：先安装并打开 Docker Desktop
- Linux：安装 Docker，或者使用脚本的 `--install-docker`

服务器：

- 推荐 Ubuntu / Debian / CentOS / Rocky Linux
- 至少 1 核 1G，推荐 2 核 2G 以上
- 如果使用域名，先把域名 A 记录解析到服务器 IP
- 云服务器安全组需要放行端口：
  - 不用域名：放行 `8080`
  - 使用域名 HTTPS：放行 `80` 和 `443`

### 本地部署

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

macOS / Linux：

```bash
bash install.sh --local
```

部署完成后打开：

```text
http://localhost:8080
```

管理员账号和密码会显示在终端里，也会保存到安装目录的 `.credentials`。

### 服务器部署

没有域名，直接用服务器 IP 访问：

```bash
sudo bash install.sh --server --install-docker
```

访问地址：

```text
http://服务器IP:8080
```

有域名，自动启用 HTTPS：

```bash
sudo bash install.sh --server --domain api.example.com --install-docker
```

访问地址：

```text
https://api.example.com
```

把 `api.example.com` 换成你的真实域名。

### 上传到 GitHub 后的一条命令部署

下面命令可以直接从 GitHub 下载脚本并一键部署。

Linux 服务器：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | sudo bash -s -- --server --domain api.example.com --install-docker
```

本地 Linux / macOS：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | bash -s -- --local
```

Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1"
```

### 常用命令

Linux / macOS：

```bash
cd ~/sub2api-local
./sub2apictl status
./sub2apictl logs
./sub2apictl update
./sub2apictl password
./sub2apictl backup
```

服务器默认安装目录是 `/opt/sub2api`，如果不是 root 运行则是 `~/sub2api-server`。

Windows：

```powershell
cd "$env:USERPROFILE\sub2api-local"
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 status
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 logs
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 update
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 password
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 backup
```

### 自定义端口、账号、目录

```bash
bash install.sh --local --port 9000 --email admin@example.com --password "change-me"
```

```bash
sudo bash install.sh --server --dir /opt/my-sub2api --port 8088
```

### 数据在哪里

安装目录里会有这些文件和目录：

```text
.env                 配置和密钥
.credentials         登录地址、管理员账号、管理员密码
docker-compose.yml   Docker Compose 配置
data/                Sub2API 应用数据
postgres_data/       PostgreSQL 数据
redis_data/          Redis 数据
```

迁移服务器时，先停止服务，再打包整个安装目录即可。

### 更新 Sub2API

```bash
cd /opt/sub2api
./sub2apictl update
```

Windows：

```powershell
cd "$env:USERPROFILE\sub2api-local"
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 update
```

### 常见问题

打不开页面：

- 本地部署先确认 Docker Desktop 正在运行
- 服务器部署确认安全组/防火墙放行了端口
- 使用域名时确认 DNS 已解析到服务器 IP
- 使用 HTTPS 时确认服务器放行 `80` 和 `443`

忘记密码：

- 查看安装目录里的 `.credentials`
- 或运行 `./sub2apictl password`

想换端口：

- 重新运行安装脚本并加 `--port 新端口`
- 或编辑 `.env` 里的 `SERVER_PORT`，然后重启服务

---

## English

### What This Does

- Generates `docker-compose.yml`
- Generates PostgreSQL, Redis, JWT, and TOTP secrets
- Generates an admin account password and stores it in `.credentials`
- Creates persistent data folders: `data/`, `postgres_data/`, `redis_data/`
- Pulls and starts `weishaw/sub2api:latest`
- Optionally creates a Caddy HTTPS reverse proxy when a domain is provided

### Requirements

Local machine:

- Windows / macOS: install and start Docker Desktop first
- Linux: install Docker, or use `--install-docker`

Server:

- Ubuntu / Debian / CentOS / Rocky Linux recommended
- 1 CPU / 1 GB RAM minimum, 2 CPU / 2 GB RAM recommended
- If using a domain, point its A record to your server IP first
- Open firewall/security group ports:
  - No domain: `8080`
  - Domain with HTTPS: `80` and `443`

### Local Deployment

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

macOS / Linux:

```bash
bash install.sh --local
```

Open:

```text
http://localhost:8080
```

The admin login will be printed in the terminal and saved to `.credentials`.

### Server Deployment

Without a domain:

```bash
sudo bash install.sh --server --install-docker
```

Open:

```text
http://SERVER_IP:8080
```

With a domain and automatic HTTPS:

```bash
sudo bash install.sh --server --domain api.example.com --install-docker
```

Open:

```text
https://api.example.com
```

Replace `api.example.com` with your real domain.

### One-Line Install After Publishing to GitHub

Use these commands to download and run the installer directly from GitHub.

Linux server:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | sudo bash -s -- --server --domain api.example.com --install-docker
```

Local Linux / macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | bash -s -- --local
```

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1"
```

### Useful Commands

Linux / macOS:

```bash
cd ~/sub2api-local
./sub2apictl status
./sub2apictl logs
./sub2apictl update
./sub2apictl password
./sub2apictl backup
```

The default server install directory is `/opt/sub2api`. If not running as root, it uses `~/sub2api-server`.

Windows:

```powershell
cd "$env:USERPROFILE\sub2api-local"
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 status
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 logs
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 update
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 password
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 backup
```

### Custom Port, Admin, and Directory

```bash
bash install.sh --local --port 9000 --email admin@example.com --password "change-me"
```

```bash
sudo bash install.sh --server --dir /opt/my-sub2api --port 8088
```

### Data Location

The install directory contains:

```text
.env                 Config and secrets
.credentials         URL, admin email, admin password
docker-compose.yml   Docker Compose config
data/                Sub2API app data
postgres_data/       PostgreSQL data
redis_data/          Redis data
```

To migrate to another server, stop the service and copy the whole install directory.

### Update Sub2API

```bash
cd /opt/sub2api
./sub2apictl update
```

Windows:

```powershell
cd "$env:USERPROFILE\sub2api-local"
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 update
```

### Troubleshooting

Page does not open:

- For local deployment, make sure Docker Desktop is running
- For server deployment, check firewall/security group ports
- For domain deployment, make sure DNS points to the server IP
- For HTTPS, make sure ports `80` and `443` are open

Forgot password:

- Check `.credentials` in the install directory
- Or run `./sub2apictl password`

Change port:

- Rerun the installer with `--port NEW_PORT`
- Or edit `SERVER_PORT` in `.env`, then restart the service

---

Sub2API itself is maintained by [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api). This repository only provides a beginner-friendly deployment wrapper.
