# Sub2API Auto Deployer

[English](#english) | [中文](#中文)

One-command local and server deployment helper for [Sub2API](https://github.com/Wei-Shaw/sub2api).

It generates configuration, secrets, persistent data folders, starts Docker containers, and prints the login URL and admin password when finished.

---

## English

### What It Does

- Deploys Sub2API with one command.
- Supports local deployment on macOS, Windows, and Linux.
- Supports server deployment on Ubuntu and other common Linux distributions.
- Automatically generates PostgreSQL, Redis, JWT, and TOTP secrets.
- Automatically creates an admin account password.
- Automatically starts Sub2API, PostgreSQL, and Redis with Docker Compose.
- Optionally enables HTTPS with Caddy when a domain is provided.
- Saves login information to `.credentials`.

### Quick Start

#### macOS Local

For macOS, install and start Docker Desktop first:

[Download Docker Desktop](https://www.docker.com/products/docker-desktop/)

Then run:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | bash -s -- --local
```

#### Linux Local

Install and start Docker first, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | bash -s -- --local
```

#### Windows Local

Install and start Docker Desktop first:

[Download Docker Desktop](https://www.docker.com/products/docker-desktop/)

Important: on Windows, Docker Desktop must already be installed and running. After that, the command below deploys Sub2API in one step. A completely fresh Windows machine may still need the Docker Desktop installer, first launch, WSL2 setup, or a reboot.

Then run PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1"
```

#### Ubuntu Server

No manual Docker installation is needed. This command installs Docker automatically:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | sudo bash -s -- --server --install-docker
```

#### Ubuntu Server With Domain And HTTPS

Replace `api.example.com` with your real domain:

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | sudo bash -s -- --server --domain api.example.com --install-docker
```

### After Installation

No second deployment command is required.

When the command finishes, open the printed URL and log in with the printed admin email and password.

Example output:

```text
URL:            http://localhost:8080
Admin email:    admin@sub2api.local
Admin password: generated-password
```

### Requirements

Local computer:

- macOS / Windows needs Docker Desktop. Install it once, open it, then run the one-command installer.
- Docker Desktop download: [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
- The script does not install Docker Desktop on macOS / Windows because Docker Desktop is a GUI app.
- Windows one-command deployment means: after Docker Desktop is installed and running, one PowerShell command deploys Sub2API.

Ubuntu server:

- You do not need to install Docker manually.
- Use the command with `--install-docker`; the script will install and start Docker automatically.
- If using server IP access, allow TCP port `8080` in your cloud firewall/security group.
- If using a domain, point the domain to your server IP and allow TCP ports `80` and `443`.

### Common Commands

Linux / macOS:

```bash
cd ~/sub2api-local
./sub2apictl status
./sub2apictl logs
./sub2apictl update
./sub2apictl password
./sub2apictl backup
```

Server default directory:

```bash
cd /opt/sub2api
```

Windows:

```powershell
cd "$env:USERPROFILE\sub2api-local"
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 status
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 logs
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 update
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 password
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 backup
```

### Custom Options

Custom port:

```bash
bash install.sh --local --port 9000
```

Custom admin account:

```bash
bash install.sh --local --email admin@example.com --password "change-me"
```

Custom server directory:

```bash
sudo bash install.sh --server --dir /opt/my-sub2api --install-docker
```

### Data Location

The install directory contains:

```text
.env                 Configuration and secrets
.credentials         URL, admin email, admin password
docker-compose.yml   Docker Compose configuration
data/                Sub2API application data
postgres_data/       PostgreSQL data
redis_data/          Redis data
```

To migrate to another server, stop the service and copy the whole install directory.

### Troubleshooting

Page does not open:

- Make sure Docker is running.
- Check firewall/security group rules.
- If using a domain, make sure DNS points to your server.
- If using HTTPS, make sure ports `80` and `443` are open.

Forgot password:

```bash
./sub2apictl password
```

Update Sub2API:

```bash
./sub2apictl update
```

---

## 中文

### 这个项目是做什么的

这是一个 [Sub2API](https://github.com/Wei-Shaw/sub2api) 一键部署工具。

目标是让新手也能用一条命令完成部署，不需要手动写 Docker Compose，不需要手动生成密钥，不需要手动配置数据库和 Redis。

### 功能

- 一条命令部署 Sub2API。
- 支持 macOS、Windows、Linux 本地部署。
- 支持 Ubuntu 等常见 Linux 服务器部署。
- 自动生成 PostgreSQL、Redis、JWT、TOTP 密钥。
- 自动生成管理员密码。
- 自动启动 Sub2API、PostgreSQL、Redis。
- 有域名时可自动启用 Caddy HTTPS。
- 登录地址、管理员邮箱、管理员密码会保存到 `.credentials`。

### 小白快速开始

#### macOS 本地部署

macOS 本地电脑需要先安装并打开 Docker Desktop：

[下载 Docker Desktop](https://www.docker.com/products/docker-desktop/)

然后运行：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | bash -s -- --local
```

#### Linux 本地部署

先安装并启动 Docker，然后运行：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | bash -s -- --local
```

#### Windows 本地部署

先安装并打开 Docker Desktop：

[下载 Docker Desktop](https://www.docker.com/products/docker-desktop/)

注意：Windows 必须先安装并运行 Docker Desktop。完成这一步后，下面这条命令才是“一条命令部署 Sub2API”。如果是一台全新的 Windows 电脑，可能还需要先安装 Docker Desktop、首次启动、配置 WSL2，或者重启一次。

然后运行 PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -Command "iwr -UseBasicParsing https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.ps1 -OutFile install.ps1; .\install.ps1"
```

#### Ubuntu 服务器部署

不需要手动安装 Docker。下面这条命令会自动安装 Docker 并部署：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | sudo bash -s -- --server --install-docker
```

#### Ubuntu 服务器 + 域名 HTTPS

把 `api.example.com` 换成你的真实域名：

```bash
curl -fsSL https://raw.githubusercontent.com/boji1334/sub2api-auto/main/install.sh | sudo bash -s -- --server --domain api.example.com --install-docker
```

### 命令跑完后还要做什么

不需要再执行第二条部署命令。

命令结束后，终端会显示访问地址、管理员邮箱、管理员密码。你只需要打开显示的地址登录。

示例：

```text
URL:            http://localhost:8080
Admin email:    admin@sub2api.local
Admin password: 自动生成的密码
```

### 前提条件

本地电脑：

- macOS / Windows 需要 Docker Desktop。只需要安装一次，打开它，然后运行一键部署命令。
- Docker Desktop 下载地址：[https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
- 脚本不会自动安装 macOS / Windows 的 Docker Desktop，因为它是图形界面软件。
- Windows 的“一键部署”意思是：Docker Desktop 已经安装并正在运行后，一条 PowerShell 命令完成 Sub2API 部署。

Ubuntu 服务器：

- 不需要你手动安装 Docker。
- 使用带 `--install-docker` 的命令，脚本会自动安装并启动 Docker。
- 用服务器 IP 访问时，需要在云服务器安全组/防火墙放行 `8080`。
- 用域名 HTTPS 时，需要先把域名解析到服务器 IP，并放行 `80` 和 `443`。

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

服务器默认目录：

```bash
cd /opt/sub2api
```

Windows：

```powershell
cd "$env:USERPROFILE\sub2api-local"
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 status
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 logs
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 update
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 password
powershell -ExecutionPolicy Bypass -File .\sub2apictl.ps1 backup
```

### 自定义参数

自定义端口：

```bash
bash install.sh --local --port 9000
```

自定义管理员账号：

```bash
bash install.sh --local --email admin@example.com --password "change-me"
```

自定义服务器目录：

```bash
sudo bash install.sh --server --dir /opt/my-sub2api --install-docker
```

### 数据目录

安装目录里会有这些文件：

```text
.env                 配置和密钥
.credentials         访问地址、管理员邮箱、管理员密码
docker-compose.yml   Docker Compose 配置
data/                Sub2API 应用数据
postgres_data/       PostgreSQL 数据
redis_data/          Redis 数据
```

迁移服务器时，先停止服务，再复制整个安装目录即可。

### 常见问题

打不开页面：

- 确认 Docker 正在运行。
- 检查云服务器安全组/防火墙。
- 使用域名时，确认 DNS 已解析到服务器 IP。
- 使用 HTTPS 时，确认 `80` 和 `443` 已放行。

忘记密码：

```bash
./sub2apictl password
```

更新 Sub2API：

```bash
./sub2apictl update
```

---

Sub2API itself is maintained by [Wei-Shaw/sub2api](https://github.com/Wei-Shaw/sub2api). This repository only provides a beginner-friendly deployment wrapper.
