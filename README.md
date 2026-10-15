# 家庭生活 OS

家庭生活 OS 的 P0 实现工程。当前首个可运行增量包含：服务端基础设施、数据库迁移、健康检查、开发登录、家庭创建、邀请码加入、成员列表和基于家庭角色的权限校验。

## 工程结构

```text
family-os/
├── server/       Node.js + TypeScript API
├── mobile/       Flutter 移动端
├── deploy/       NAS 部署配置
└── docs/         工程文档
```

## 本地启动服务端

1. 将 `.env.example` 复制为 `.env` 并更换所有密钥。
2. 启动 PostgreSQL 和 Redis；有 Docker 时可运行 `docker compose up -d postgres redis`。
3. 在 `server` 中安装依赖并执行数据库迁移。
4. 启动开发服务。

```powershell
cd server
npm install
npm run db:migrate
npm run dev
```

服务默认监听 `http://localhost:8080`，健康检查为 `GET /health`。

开发登录接口 `POST /api/v1/auth/dev-login` 只在 `ALLOW_DEV_LOGIN=true` 时开放，不得在 NAS 正式环境开启。

## 安全原则

- 所有家庭数据查询必须携带家庭上下文并通过成员权限校验。
- PostgreSQL、Redis 和 NAS 管理端不得暴露到公网。
- 正式环境只通过 HTTPS 反向代理访问 API。
- 健康档案、账目及附件访问需要服务端权限校验，不能只依赖客户端隐藏入口。

