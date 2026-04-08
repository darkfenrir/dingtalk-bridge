/**
 * 钉钉机器人桥接 OpenClaw 中间件
 * 
 * 功能：
 * 1. 接收钉钉机器人消息（文本/图片/文件/语音）
 * 2. 转发到 OpenClaw 处理
 * 3. 将 OpenClaw 回复发送回钉钉
 */

const express = require('express');
const axios = require('axios');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const FormData = require('form-data');
const config = require('./config');

// 日志工具
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  warn: (msg) => console.warn(`[WARN] ${new Date().toISOString()} - ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  debug: (msg) => config.log.level === 'debug' && console.log(`[DEBUG] ${new Date().toISOString()} - ${msg}`),
};

// 临时文件存储目录
const TEMP_DIR = path.join(__dirname, 'temp');
if (!fs.existsSync(TEMP_DIR)) {
  fs.mkdirSync(TEMP_DIR, { recursive: true });
  log.info(`创建临时目录：${TEMP_DIR}`);
}

/**
 * 获取钉钉 Access Token
 */
async function getDingTalkAccessToken() {
  try {
    const response = await axios.get(config.dingtalk.tokenUrl, {
      params: {
        appkey: config.dingtalk.appKey,
        appsecret: config.dingtalk.appSecret,
      },
    });

    if (response.data.errcode === 0) {
      log.debug('获取钉钉 access_token 成功');
      return response.data.access_token;
    } else {
      log.error(`获取钉钉 access_token 失败：${response.data.errmsg}`);
      throw new Error(response.data.errmsg);
    }
  } catch (error) {
    log.error(`获取钉钉 access_token 异常：${error.message}`);
    throw error;
  }
}

/**
 * 从钉钉下载媒体文件
 */
async function downloadDingTalkMedia(mediaId) {
  try {
    const accessToken = await getDingTalkAccessToken();
    
    // 获取媒体文件详情
    const detailResponse = await axios.get(
      `${config.dingtalk.apiBaseUrl}/v1.0/robot/messageFiles/${mediaId}`,
      {
        headers: {
          'x-acs-dingtalk-access-token': accessToken,
        },
      }
    );

    if (detailResponse.data) {
      const fileUrl = detailResponse.data.downloadUrl;
      
      // 下载文件
      const fileResponse = await axios.get(fileUrl, {
        responseType: 'arraybuffer',
      });

      // 保存临时文件
      const fileName = `${Date.now()}_${mediaId}`;
      const filePath = path.join(TEMP_DIR, fileName);
      
      fs.writeFileSync(filePath, fileResponse.data);
      log.info(`媒体文件已下载：${filePath}`);
      
      return {
        filePath,
        fileName,
        fileSize: fileResponse.data.length,
        url: fileUrl,
      };
    } else {
      log.error(`获取媒体文件详情失败：${JSON.stringify(detailResponse.data)}`);
      return null;
    }
  } catch (error) {
    log.error(`下载媒体文件异常：${error.message}`);
    return null;
  }
}

/**
 * 上传文件到钉钉（用于发送文件消息）
 */
async function uploadToDingTalk(filePath, fileName) {
  try {
    const accessToken = await getDingTalkAccessToken();
    
    // 读取文件
    const fileContent = fs.readFileSync(filePath);
    
    // 创建 FormData
    const formData = new FormData();
    formData.append('media', fileContent, {
      filename: fileName,
    });

    // 上传媒体文件
    const uploadResponse = await axios.post(
      `${config.dingtalk.apiBaseUrl}/v1.0/robot/messageFiles/upload`,
      formData,
      {
        headers: {
          ...formData.getHeaders(),
          'x-acs-dingtalk-access-token': accessToken,
        },
      }
    );

    if (uploadResponse.data) {
      log.info(`文件已上传到钉钉：${uploadResponse.data.mediaId}`);
      return uploadResponse.data.mediaId;
    } else {
      log.error(`上传文件失败：${JSON.stringify(uploadResponse.data)}`);
      return null;
    }
  } catch (error) {
    log.error(`上传文件异常：${error.message}`);
    return null;
  }
}

/**
 * 发送文本消息到钉钉
 */
async function sendTextToDingTalk(userId, content) {
  try {
    const accessToken = await getDingTalkAccessToken();
    
    const response = await axios.post(
      `${config.dingtalk.apiBaseUrl}/v1.0/robot/oToMessages/send`,
      {
        agentId: config.dingtalk.agentId,
        userIds: [userId],
        msgtype: 'text',
        text: {
          content: content,
        },
      },
      {
        headers: {
          'x-acs-dingtalk-access-token': accessToken,
        },
      }
    );

    if (response.data) {
      log.info(`文本消息已发送到钉钉用户：${userId}`);
      return true;
    } else {
      log.error(`发送文本消息失败：${JSON.stringify(response.data)}`);
      return false;
    }
  } catch (error) {
    log.error(`发送文本消息异常：${error.message}`);
    return false;
  }
}

/**
 * 发送图片消息到钉钉
 */
async function sendImageToDingTalk(userId, imagePath, caption = '') {
  try {
    // 先上传图片获取 mediaId
    const mediaId = await uploadToDingTalk(imagePath, path.basename(imagePath));
    
    if (!mediaId) {
      return false;
    }

    const accessToken = await getDingTalkAccessToken();
    
    const response = await axios.post(
      `${config.dingtalk.apiBaseUrl}/v1.0/robot/oToMessages/send`,
      {
        agentId: config.dingtalk.agentId,
        userIds: [userId],
        msgtype: 'image',
        image: {
          mediaId: mediaId,
        },
      },
      {
        headers: {
          'x-acs-dingtalk-access-token': accessToken,
        },
      }
    );

    if (response.data) {
      log.info(`图片消息已发送到钉钉用户：${userId}`);
      return true;
    } else {
      log.error(`发送图片消息失败：${JSON.stringify(response.data)}`);
      return false;
    }
  } catch (error) {
    log.error(`发送图片消息异常：${error.message}`);
    return false;
  }
}

/**
 * 发送文件消息到钉钉
 */
async function sendFileToDingTalk(userId, filePath, fileName) {
  try {
    // 先上传文件获取 mediaId
    const mediaId = await uploadToDingTalk(filePath, fileName);
    
    if (!mediaId) {
      return false;
    }

    const accessToken = await getDingTalkAccessToken();
    
    const response = await axios.post(
      `${config.dingtalk.apiBaseUrl}/v1.0/robot/oToMessages/send`,
      {
        agentId: config.dingtalk.agentId,
        userIds: [userId],
        msgtype: 'file',
        file: {
          mediaId: mediaId,
          fileName: fileName,
        },
      },
      {
        headers: {
          'x-acs-dingtalk-access-token': accessToken,
        },
      }
    );

    if (response.data) {
      log.info(`文件消息已发送到钉钉用户：${userId}`);
      return true;
    } else {
      log.error(`发送文件消息失败：${JSON.stringify(response.data)}`);
      return false;
    }
  } catch (error) {
    log.error(`发送文件消息异常：${error.message}`);
    return false;
  }
}

/**
 * 发送消息到钉钉（统一入口）
 */
async function sendToDingTalk(userId, content, options = {}) {
  const { type = 'text', filePath, fileName, imagePath } = options;

  switch (type) {
    case 'text':
      return await sendTextToDingTalk(userId, content);
    case 'image':
      return await sendImageToDingTalk(userId, imagePath || filePath, content);
    case 'file':
      return await sendFileToDingTalk(userId, filePath, fileName || 'file');
    default:
      log.warn(`不支持的消息类型：${type}，将以文本发送`);
      return await sendTextToDingTalk(userId, content);
  }
}

/**
 * 发送消息到 OpenClaw
 */
async function sendToOpenClaw(message, sessionId, attachments = []) {
  try {
    const payload = {
      message: message,
      sessionId: sessionId,
    };

    // 如果有附件，添加到请求中
    if (attachments.length > 0) {
      payload.attachments = attachments;
    }

    const response = await axios.post(
      `${config.openclaw.apiUrl}/api/message`,
      payload,
      {
        headers: {
          'Authorization': `Bearer ${config.openclaw.apiKey}`,
          'Content-Type': 'application/json',
        },
      }
    );

    log.debug(`OpenClaw 响应：${JSON.stringify(response.data)}`);
    return {
      reply: response.data.reply || response.data.message || '处理完成',
      attachments: response.data.attachments || [],
    };
  } catch (error) {
    log.error(`发送消息到 OpenClaw 异常：${error.message}`);
    throw error;
  }
}

/**
 * 验证钉钉回调签名
 */
function verifyDingTalkSignature(timestamp, nonce, signature) {
  const sortedParams = [timestamp, nonce, config.dingtalk.appSecret].sort();
  const stringToSign = sortedParams.join('');
  const calculatedSignature = crypto
    .createHash('sha256')
    .update(stringToSign)
    .digest('hex');
  
  return calculatedSignature === signature;
}

/**
 * 清理临时文件（超过 1 小时的文件）
 */
function cleanupTempFiles() {
  try {
    const files = fs.readdirSync(TEMP_DIR);
    const now = Date.now();
    const oneHour = 60 * 60 * 1000;

    files.forEach(file => {
      const filePath = path.join(TEMP_DIR, file);
      const stats = fs.statSync(filePath);
      
      if (now - stats.mtimeMs > oneHour) {
        fs.unlinkSync(filePath);
        log.debug(`清理临时文件：${filePath}`);
      }
    });
  } catch (error) {
    log.error(`清理临时文件异常：${error.message}`);
  }
}

// 每小时清理一次临时文件
setInterval(cleanupTempFiles, 60 * 60 * 1000);

/**
 * Express 应用
 */
const app = express();
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// 健康检查端点
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    tempDir: TEMP_DIR,
  });
});

// 钉钉回调端点（HTTP 模式）
app.post('/dingtalk/callback', async (req, res) => {
  try {
    const { timestamp, nonce, signature, encrypt, msg } = req.body;

    // 验证签名
    if (!verifyDingTalkSignature(timestamp, nonce, signature)) {
      log.warn('钉钉回调签名验证失败');
      return res.status(401).json({ error: 'Invalid signature' });
    }

    log.info(`收到钉钉消息：${JSON.stringify(msg)}`);

    // 解析消息内容
    const messageType = msg.messageType;
    const senderId = msg.senderId;
    const conversationId = msg.conversationId;

    // 生成或获取会话 ID
    let sessionId = config.sessionMap.get(senderId);
    if (!sessionId) {
      sessionId = `dingtalk_${senderId}`;
      config.sessionMap.set(senderId, sessionId);
      log.info(`创建新会话：${sessionId} for user ${senderId}`);
    }

    // 提取消息内容和附件
    let messageContent = '';
    let attachments = [];

    switch (messageType) {
      case 'text':
        messageContent = msg.text?.content || '';
        break;

      case 'richText':
        // 富文本消息处理
        messageContent = JSON.stringify(msg.richTextContent || {});
        break;

      case 'image':
        // 图片消息
        const imageMediaId = msg.image?.mediaId || msg.mediaId;
        messageContent = '[图片消息]';
        
        if (imageMediaId) {
          const imageData = await downloadDingTalkMedia(imageMediaId);
          if (imageData) {
            attachments.push({
              type: 'image',
              path: imageData.filePath,
              fileName: imageData.fileName,
              url: imageData.url,
            });
            messageContent = `[图片] 用户发送了一张图片，文件路径：${imageData.filePath}`;
          }
        }
        break;

      case 'file':
        // 文件消息
        const fileMediaId = msg.file?.mediaId || msg.mediaId;
        const fileTitle = msg.file?.fileName || msg.title || '未知文件';
        messageContent = `[文件消息] ${fileTitle}`;
        
        if (fileMediaId) {
          const fileData = await downloadDingTalkMedia(fileMediaId);
          if (fileData) {
            attachments.push({
              type: 'file',
              path: fileData.filePath,
              fileName: fileData.fileName || fileTitle,
              url: fileData.url,
            });
            messageContent = `[文件] 用户发送了一个文件：${fileData.fileName}，文件路径：${fileData.filePath}`;
          }
        }
        break;

      case 'voice':
        // 语音消息
        const voiceMediaId = msg.voice?.mediaId || msg.mediaId;
        const duration = msg.voice?.duration || 0;
        messageContent = `[语音消息] 时长：${duration}秒`;
        
        if (voiceMediaId) {
          const voiceData = await downloadDingTalkMedia(voiceMediaId);
          if (voiceData) {
            attachments.push({
              type: 'voice',
              path: voiceData.filePath,
              fileName: voiceData.fileName,
              url: voiceData.url,
              duration: duration,
            });
          }
        }
        break;

      case 'video':
        // 视频消息
        const videoMediaId = msg.video?.mediaId || msg.mediaId;
        const videoDuration = msg.video?.duration || 0;
        messageContent = `[视频消息] 时长：${videoDuration}秒`;
        
        if (videoMediaId) {
          const videoData = await downloadDingTalkMedia(videoMediaId);
          if (videoData) {
            attachments.push({
              type: 'video',
              path: videoData.filePath,
              fileName: videoData.fileName,
              url: videoData.url,
              duration: videoDuration,
            });
          }
        }
        break;

      default:
        messageContent = `[${messageType} 消息] 暂不支持此消息类型`;
        log.warn(`收到不支持的消息类型：${messageType}`);
    }

    // 发送到 OpenClaw 处理
    const result = await sendToOpenClaw(messageContent, sessionId, attachments);

    // 发送回复到钉钉
    if (result.attachments && result.attachments.length > 0) {
      // 如果有附件回复，先发送文本
      await sendTextToDingTalk(senderId, result.reply);
      
      // 然后发送每个附件
      for (const attachment of result.attachments) {
        if (attachment.type === 'image' && attachment.path) {
          await sendImageToDingTalk(senderId, attachment.path);
        } else if (attachment.type === 'file' && attachment.path) {
          await sendFileToDingTalk(senderId, attachment.path, attachment.fileName);
        }
      }
    } else {
      // 只发送文本回复
      await sendTextToDingTalk(senderId, result.reply);
    }

    res.json({ success: true });
  } catch (error) {
    log.error(`处理钉钉回调异常：${error.message}`);
    res.status(500).json({ error: error.message });
  }
});

// 钉钉回调端点（Socket 模式）
app.post('/dingtalk/socket', async (req, res) => {
  try {
    const { eventType, data } = req.body;

    log.info(`收到钉钉 Socket 事件：${eventType}`);

    if (eventType === 'IM_MESSAGE') {
      const { messageId, senderId, conversationId, text, image, file, voice } = data;
      
      // 生成或获取会话 ID
      let sessionId = config.sessionMap.get(senderId);
      if (!sessionId) {
        sessionId = `dingtalk_${senderId}`;
        config.sessionMap.set(senderId, sessionId);
      }

      let messageContent = '';
      let attachments = [];

      // 处理不同类型的消息
      if (text) {
        messageContent = text.content || '';
      } else if (image) {
        messageContent = '[图片消息]';
        const imageData = await downloadDingTalkMedia(image.mediaId);
        if (imageData) {
          attachments.push({
            type: 'image',
            path: imageData.filePath,
            fileName: imageData.fileName,
          });
        }
      } else if (file) {
        messageContent = `[文件消息] ${file.fileName || '未知文件'}`;
        const fileData = await downloadDingTalkMedia(file.mediaId);
        if (fileData) {
          attachments.push({
            type: 'file',
            path: fileData.filePath,
            fileName: fileData.fileName || 'file',
          });
        }
      } else if (voice) {
        messageContent = `[语音消息] 时长：${voice.duration || 0}秒`;
        const voiceData = await downloadDingTalkMedia(voice.mediaId);
        if (voiceData) {
          attachments.push({
            type: 'voice',
            path: voiceData.filePath,
            fileName: voiceData.fileName,
          });
        }
      }

      // 发送到 OpenClaw
      const result = await sendToOpenClaw(messageContent, sessionId, attachments);

      // 发送回复
      await sendTextToDingTalk(senderId, result.reply);

      // 发送附件回复
      if (result.attachments && result.attachments.length > 0) {
        for (const attachment of result.attachments) {
          if (attachment.type === 'image' && attachment.path) {
            await sendImageToDingTalk(senderId, attachment.path);
          } else if (attachment.type === 'file' && attachment.path) {
            await sendFileToDingTalk(senderId, attachment.path, attachment.fileName);
          }
        }
      }
    }

    res.json({ success: true });
  } catch (error) {
    log.error(`处理钉钉 Socket 事件异常：${error.message}`);
    res.status(500).json({ error: error.message });
  }
});

// 测试端点 - 手动发送消息
app.post('/test/send', async (req, res) => {
  try {
    const { userId, message, type, filePath, fileName } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const reply = await sendToOpenClaw(message || '测试消息', `test_${userId}`);
    
    let sent = false;
    if (type === 'image' || type === 'file') {
      if (!filePath) {
        return res.status(400).json({ error: 'filePath is required for image/file type' });
      }
      sent = await sendToDingTalk(userId, reply.reply, {
        type: type,
        filePath: filePath,
        fileName: fileName,
      });
    } else {
      sent = await sendTextToDingTalk(userId, reply.reply);
    }

    res.json({ success: sent, reply: reply.reply });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 测试端点 - 发送图片
app.post('/test/send-image', async (req, res) => {
  try {
    const { userId, imagePath, caption } = req.body;
    
    if (!userId || !imagePath) {
      return res.status(400).json({ error: 'userId and imagePath are required' });
    }

    const sent = await sendImageToDingTalk(userId, imagePath, caption || '');
    res.json({ success: sent });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 测试端点 - 发送文件
app.post('/test/send-file', async (req, res) => {
  try {
    const { userId, filePath, fileName } = req.body;
    
    if (!userId || !filePath) {
      return res.status(400).json({ error: 'userId and filePath are required' });
    }

    const sent = await sendFileToDingTalk(userId, filePath, fileName || path.basename(filePath));
    res.json({ success: sent });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 启动服务器
const PORT = config.server.port;
app.listen(PORT, config.server.bindAddress, () => {
  log.info(`钉钉桥接服务已启动，监听端口：${PORT}`);
  log.info(`健康检查：http://localhost:${PORT}/health`);
  log.info(`钉钉回调：http://localhost:${PORT}/dingtalk/callback`);
  log.info(`测试端点：http://localhost:${PORT}/test/send`);
  log.info(`临时目录：${TEMP_DIR}`);
});
