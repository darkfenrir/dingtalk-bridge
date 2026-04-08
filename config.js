/**
 * 配置文件
 */
require('dotenv').config();

module.exports = {
  // 钉钉配置
  dingtalk: {
    appKey: process.env.DINGTALK_APP_KEY || '',
    appSecret: process.env.DINGTALK_APP_SECRET || '',
    agentId: process.env.DINGTALK_AGENT_ID || '',
    socketUrl: process.env.DINGTALK_SOCKET_URL || 'wss://api.dingtalk.com',
    eventSubscription: process.env.DINGTALK_EVENT_SUBSCRIPTION || 'IM_MESSAGE',
    // 钉钉 API 基础 URL
    apiBaseUrl: 'https://oapi.dingtalk.com',
    // 获取 access_token 的 URL
    tokenUrl: 'https://oapi.dingtalk.com/gettoken',
    // 发送消息的 URL
    messageUrl: 'https://oapi.dingtalk.com/topapi/message/send',
  },

  // OpenClaw 配置
  openclaw: {
    apiUrl: process.env.OPENCLAW_API_URL || 'http://localhost:3000',
    apiKey: process.env.OPENCLAW_API_KEY || '',
  },

  // 服务配置
  server: {
    port: parseInt(process.env.PORT) || 3001,
    bindAddress: process.env.BIND_ADDRESS || '0.0.0.0',
  },

  // 日志配置
  log: {
    level: process.env.LOG_LEVEL || 'info',
  },

  // 会话映射（钉钉用户 ID -> OpenClaw 会话）
  sessionMap: new Map(),
};
