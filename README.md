# 钉钉桥接中间件 (DingTalk Bridge)

将钉钉机器人与 OpenClaw 连接，实现通过钉钉与 AI 助手对话。

## 功能

- ✅ 文本消息收发
- ✅ 图片消息收发（自动下载/上传）
- ✅ 文件消息收发（自动下载/上传）
- ✅ 语音消息接收
- ✅ 视频消息接收
- ✅ 会话保持（同一用户持续对话）
- ✅ 临时文件自动清理

## 架构图

```
┌─────────────┐      ┌──────────────────┐      ┌─────────────┐
│   钉钉用户   │ ────→ │  钉钉桥接中间件   │ ────→ │  OpenClaw   │
│  (App/PC)   │ ←──── │  (本服务)        │ ←──── │  (AI 助手)  │
└─────────────┘      └──────────────────┘      └─────────────┘
                            ↓
                    ┌───────────────┐
                    │  temp/ 目录    │
                    │ 临时存储文件   │
                    └───────────────┘
```

## 快速开始

### 1. 安装依赖

```bash
cd dingtalk-bridge
npm install
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 文件，填入你的配置：

```env
# 钉钉机器人配置（从钉钉开放平台获取）
DINGTALK_APP_KEY=your_app_key
DINGTALK_APP_SECRET=your_app_secret
DINGTALK_AGENT_ID=your_agent_id

# OpenClaw 配置
OPENCLAW_API_URL=http://localhost:3000
OPENCLAW_API_KEY=your_openclaw_api_key

# 服务端口
PORT=3001
```

### 3. 启动服务

**推荐方式 - 使用快速启动脚本：**

```bash
# 首次配置（交互式）
./setup.sh

# 启动服务
./quick-start.sh

# 查看状态
./quick-start.sh status

# 查看日志
./quick-start.sh logs

# 停止服务
./quick-start.sh stop
```

**传统方式：**

```bash
# 生产环境
npm start

# 开发环境（自动重启）
npm run dev
```

### 4. 验证服务

```bash
curl http://localhost:3001/health
# 返回：{"status":"ok","timestamp":"...","tempDir":"/path/to/temp"}
```

---

## 钉钉开放平台配置

### 步骤 1：创建企业内部应用

1. 访问 [钉钉开放平台](https://open.dingtalk.com/)
2. 登录企业账号
3. 进入「应用开发」→「企业内部开发」
4. 点击「创建应用」
5. 填写应用名称（如：OpenClaw 助手）

### 步骤 2：获取凭证

在应用详情页获取：
- **AppKey**
- **AppSecret**
- **AgentId**

### 步骤 3：配置权限

进入「权限管理」，确保有以下权限：
- ✅ 机器人消息发送权限
- ✅ 消息读取权限
- ✅ 文件上传下载权限

### 步骤 4：配置回调地址

1. 进入「开发管理」→「事件订阅」
2. 开启「事件订阅」
3. 配置回调地址：`http://你的服务器 IP:3001/dingtalk/callback`
4. 选择订阅事件：**IM 消息**

### 步骤 5：发布应用

1. 进入「版本管理与发布」
2. 创建版本并发布
3. 将应用授权给需要使用的人员/部门

---

## 脚本命令

### setup.sh - 配置向导

交互式配置脚本，首次使用时运行：

```bash
./setup.sh
```

功能：
- ✅ 自动检测 Node.js 环境
- ✅ 交互式配置钉钉和 OpenClaw 参数
- ✅ 自动安装依赖
- ✅ 测试服务启动

### quick-start.sh - 快速启动

日常使用的快速启动脚本：

```bash
./quick-start.sh start    # 启动服务
./quick-start.sh stop     # 停止服务
./quick-start.sh restart  # 重启服务
./quick-start.sh status   # 查看状态
./quick-start.sh logs     # 查看日志
./quick-start.sh dev      # 开发模式
./quick-start.sh setup    # 重新配置
./quick-start.sh help     # 显示帮助
```

---

## API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/dingtalk/callback` | POST | 钉钉 HTTP 回调 |
| `/dingtalk/socket` | POST | 钉钉 Socket 事件 |
| `/test/send` | POST | 测试发送消息 |
| `/test/send-image` | POST | 测试发送图片 |
| `/test/send-file` | POST | 测试发送文件 |

### 测试示例

**发送文本消息：**
```bash
curl -X POST http://localhost:3001/test/send \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "message": "你好，请帮我分析一下今天的股市"
  }'
```

**发送图片消息：**
```bash
curl -X POST http://localhost:3001/test/send-image \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "imagePath": "/path/to/image.jpg",
    "caption": "这是一张测试图片"
  }'
```

**发送文件消息：**
```bash
curl -X POST http://localhost:3001/test/send-file \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "user123",
    "filePath": "/path/to/document.pdf",
    "fileName": "测试文档.pdf"
  }'
```

---

## 消息类型支持

### 接收消息（钉钉 → OpenClaw）

| 类型 | 支持 | 说明 |
|------|------|------|
| 文本 | ✅ | 直接转发文本内容 |
| 图片 | ✅ | 自动下载图片，转发文件路径给 OpenClaw |
| 文件 | ✅ | 自动下载文件，转发文件路径给 OpenClaw |
| 语音 | ✅ | 自动下载语音，转发文件路径给 OpenClaw |
| 视频 | ✅ | 自动下载视频，转发文件路径给 OpenClaw |
| 富文本 | ✅ | 转为 JSON 字符串转发 |

### 发送消息（OpenClaw → 钉钉）

| 类型 | 支持 | 说明 |
|------|------|------|
| 文本 | ✅ | 直接发送文本 |
| 图片 | ✅ | OpenClaw 返回图片路径，自动上传并发送 |
| 文件 | ✅ | OpenClaw 返回文件路径，自动上传并发送 |

---

## OpenClaw 响应格式

OpenClaw 需要返回以下格式的消息：

```json
{
  "reply": "文本回复内容",
  "attachments": [
    {
      "type": "image",
      "path": "/path/to/image.jpg",
      "fileName": "图片.jpg"
    },
    {
      "type": "file",
      "path": "/path/to/document.pdf",
      "fileName": "文档.pdf"
    }
  ]
}
```

### OpenClaw 请求格式

中间件会发送以下请求到 OpenClaw：

```json
{
  "message": "[图片] 用户发送了一张图片，文件路径：/path/to/temp/123456.jpg",
  "sessionId": "dingtalk_user123",
  "attachments": [
    {
      "type": "image",
      "path": "/path/to/temp/123456.jpg",
      "fileName": "123456.jpg",
      "url": "https://..."
    }
  ]
}
```

---

## 临时文件管理

### 存储位置

临时文件存储在 `temp/` 目录下：
```
dingtalk-bridge/
└── temp/
    ├── 1710576000000_mediaId123.jpg
    ├── 1710576000001_mediaId456.pdf
    └── ...
```

### 自动清理

- 每小时自动清理一次
- 清理超过 1 小时的临时文件
- 可通过 `cleanupTempFiles()` 手动清理

### 手动清理

```bash
# 删除所有临时文件
rm -rf temp/*
```

---

## 部署

### Docker 部署

创建 `Dockerfile`：

```dockerfile
FROM node:20-alpine

WORKDIR /app
COPY package*.json ./
RUN npm install --production

COPY . .

# 创建临时目录
RUN mkdir -p /app/temp

EXPOSE 3001

CMD ["npm", "start"]
```

构建和运行：

```bash
docker build -t dingtalk-bridge .
docker run -d \
  --name dingtalk-bridge \
  -p 3001:3001 \
  -v $(pwd)/.env:/app/.env \
  -v $(pwd)/temp:/app/temp \
  dingtalk-bridge
```

### PM2 部署

```bash
# 安装 PM2
npm install -g pm2

# 启动服务
pm2 start index.js --name dingtalk-bridge

# 查看状态
pm2 status

# 查看日志
pm2 logs dingtalk-bridge

# 开机自启
pm2 startup
pm2 save
```

---

## 安全建议

1. **使用 HTTPS** — 生产环境务必使用 HTTPS，可通过 Nginx 反向代理
2. **验证签名** — 已实现钉钉回调签名验证
3. **IP 白名单** — 配置钉钉服务器 IP 白名单
4. **API Key 保护** — 不要将 `.env` 文件提交到 Git
5. **文件类型限制** — 可添加文件类型检查，防止恶意文件上传

### Nginx 配置示例

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

---

## 故障排查

### 问题 1：获取 access_token 失败

```
错误：invalid appkey or appsecret
```

**解决：** 检查 `.env` 中的 `DINGTALK_APP_KEY` 和 `DINGTALK_APP_SECRET` 是否正确。

### 问题 2：消息发送失败

```
错误：invalid agentid
```

**解决：** 检查 `DINGTALK_AGENT_ID` 是否正确，确保应用已发布。

### 问题 3：文件下载失败

```
错误：mediaId 无效
```

**解决：** 
1. 检查媒体文件是否已过期（钉钉媒体文件有效期 3 天）
2. 检查应用是否有文件读取权限

### 问题 4：回调收不到消息

**解决：**
1. 检查回调地址是否可公网访问
2. 检查事件订阅是否开启
3. 查看钉钉开放平台的事件推送日志
4. 检查签名验证是否通过

### 问题 5：临时目录权限错误

```
错误：EACCES: permission denied
```

**解决：**
```bash
chmod 755 temp/
chown -R $(whoami) temp/
```

---

## 扩展功能

### 添加消息类型支持

在 `index.js` 的回调处理中添加：

```javascript
case 'location':
  // 位置消息
  const { latitude, longitude } = msg.location;
  messageContent = `[位置] 纬度：${latitude}, 经度：${longitude}`;
  break;

case 'link':
  // 链接消息
  const { title, url } = msg.link;
  messageContent = `[链接] ${title}: ${url}`;
  break;
```

### 添加文件类型限制

在 `downloadDingTalkMedia` 函数后添加检查：

```javascript
const allowedTypes = ['image/jpeg', 'image/png', 'application/pdf', 'application/msword'];
if (!allowedTypes.includes(fileType)) {
  log.warn(`不支持的文件类型：${fileType}`);
  return null;
}
```

---

## 性能优化

### 1. 使用缓存

对于频繁访问的媒体文件，可以添加缓存机制：

```javascript
const mediaCache = new Map();

async function downloadDingTalkMedia(mediaId) {
  // 检查缓存
  if (mediaCache.has(mediaId)) {
    return mediaCache.get(mediaId);
  }
  // ... 下载逻辑
  mediaCache.set(mediaId, result);
  return result;
}
```

### 2. 并发限制

限制同时下载的文件数量：

```javascript
const pLimit = require('p-limit');
const limit = pLimit(5); // 最多 5 个并发

// 使用时
await limit(() => downloadDingTalkMedia(mediaId));
```

---

## 许可证

MIT License

---

## 反馈与支持

如有问题，请提交 Issue 或联系开发者。
