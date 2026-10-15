# NAS 部署与恢复

## 最低条件

- x86-64 或 ARM64 NAS；
- Docker Compose v2；
- 8GB 内存；
- 独立的应用数据共享目录；
- UPS 和至少一份异地加密备份。

## 首次部署

1. 将项目复制到 NAS 的应用目录。
2. 将 `.env.example` 复制为 `.env`。
3. 设置强随机 `POSTGRES_PASSWORD`、`JWT_SECRET` 和正式 `APP_DOMAIN`。
4. 正式环境必须设置 `ALLOW_DEV_LOGIN=false`。
5. 如需跨设备推送，填写 Firebase 服务账号的项目 ID、客户端邮箱和私钥；不填写时本地手机提醒仍可工作，Worker 不发送云推送。
6. 启动生产组合：

```sh
docker compose -f compose.yaml -f compose.production.yaml up -d --build
```

API 容器启动前会自动执行按文件名排序的数据库迁移。PostgreSQL 和 Redis 不映射公网端口，外部只能通过 Caddy 的 HTTPS 入口访问。

可以在 Windows 管理机先执行 `deploy/preflight.ps1` 检查密钥、正式登录配置和 Compose 语法。

## 升级

```sh
docker compose -f compose.yaml -f compose.production.yaml build api
docker compose -f compose.yaml -f compose.production.yaml up -d --no-deps api
```

升级前必须生成数据库和媒体备份。包含破坏性数据库变更时，应先在复制的测试数据上演练。

## 备份

`backup.sh` 同时生成 PostgreSQL 自定义格式备份、媒体归档和 SHA-256 校验文件。备份目录不能是唯一副本，应同步到外接硬盘或异地加密存储。

推荐使用内置维护服务：

```sh
docker compose --profile maintenance run --rm backup
```

恢复只应在隔离测试环境或明确停机维护后执行：

```sh
docker compose --profile maintenance run --rm restore /backups/<时间戳>
```

## 恢复验收

恢复不能只看脚本退出码。恢复后必须核对：家庭数量、成员与角色、最近日程、账目合计、记录附件数量、健康档案授权、执行中的用药计划，并随机打开至少三张原图或报告。

## 外网访问

- 家庭内测优先使用 Tailscale；
- 正式域名可以由 Caddy直接提供 HTTPS，或使用云端入口经私有隧道连接 NAS；
- 禁止直接公开 PostgreSQL、Redis、NAS 管理端和 Docker API；
- 数据库密码、JWT 密钥和推送凭证不得提交到代码仓库。
