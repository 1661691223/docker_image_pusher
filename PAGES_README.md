# Docker Image Registry Pages

GitHub Pages 展示所有 Docker 镜像的当前和历史版本，支持用户认证。

## 功能特性

-   自动收集每次 build 后的镜像版本信息
-   SGLang/vLLM 定时同步最新标签
-   支持导入历史版本数据
-   用户认证（通过 GitHub Secrets 配置多个用户）
-   搜索和过滤镜像
-   一键复制 pull 命令
-   响应式设计，支持移动端
-   钉钉机器人通知

## 快速开始

### 1. 配置 GitHub Secrets

进入仓库 Settings → Secrets and variables → Actions，添加以下 Secrets：

| Secret 名称 | 说明 | 示例 |
|---|---|---|
| `ALIYUN_REGISTRY` | 阿里云仓库地址 | `registry.cn-hangzhou.aliyuncs.com` |
| `ALIYUN_NAME_SPACE` | 阿里云命名空间 | `my-images` |
| `ALIYUN_REGISTRY_USER` | 阿里云用户名 | `your-username` |
| `ALIYUN_REGISTRY_PASSWORD` | 阿里云密码 | `your-password` |
| `PAGE_MASTER_PASSWORD` | Pages 主加密密钥 | `any-strong-password` |
| `PAGE_USERS` | 用户认证配置 | `admin:admin123,user1:pwd1` |
| `PAGE_SESSION_DAYS` | 会话过期天数（可选） | `3` |
| `WEBHOOK_URL` | 钉钉机器人 Webhook（可选） | `https://oapi.dingtalk.com/robot/send?access_token=xxx` |

### 2. 配置用户认证

`PAGE_USERS` 的格式为 `用户名:密码,用户名2:密码2`（**原始密码**，不是哈希）。

密码在构建时通过 PBKDF2 哈希后嵌入页面，不会明文存储。

多个用户示例：
```
PAGE_USERS 值:
admin:admin_password123,user1:password1,user2:password2
```

### 3. 配置钉钉通知（可选）

1. 在钉钉群中添加「自定义机器人」，选择「加签」或「IP 白名单」
2. 复制 Webhook 地址
3. 填入 `WEBHOOK_URL` Secret

配置后在 Docker 同步和 SGLang/vLLM 同步完成/失败时都会收到 Markdown 格式通知。

### 4. 启用 GitHub Pages

1. 进入仓库 Settings → Pages
2. Source 选择 "GitHub Actions"
3. 保存

### 5. 触发构建

- **Docker 同步**：修改 `images.txt` 并 push，或手动触发 Docker workflow
- **SGLang/vLLM 同步**：UTC 6/14/22 点（北京时间 14/22/06 点）定时运行，也可手动触发
- **Pages 更新**：上述任一 workflow 完成后自动触发，也可手动触发 Docker Pages workflow

## 导入历史数据

1. 编辑 `data/import_data.json`，添加历史镜像信息
2. 提交并 push
3. GitHub Actions 会自动将数据合并到 `data/versions.json`

### 导入数据格式

完整格式：
```json
[
  {
    "name": "nginx",
    "namespace": "library",
    "tag": "1.25.3",
    "platform": "",
    "build_time": "2024-01-15T10:30:00Z",
    "run_id": "history-import",
    "registry": "registry.cn-hangzhou.aliyuncs.com"
  }
]
```

简化格式（只需 name 和 tag）：
```json
[
  { "name": "nginx", "tag": "1.25.3" },
  { "name": "alpine", "tag": "3.19" }
]
```

## 文件结构

```
├── .github/workflows/
│   ├── docker.yaml              # Docker 镜像同步 workflow
│   ├── sglang_vllm.yml          # SGLang/vLLM 标签定时同步
│   └── pages.yml                # Pages 部署 workflow
├── scripts/
│   ├── collect_versions.sh      # 收集版本数据脚本
│   ├── generate_page.sh         # 生成 HTML 页面脚本
│   └── import_history.sh        # 导入历史数据脚本
├── data/
│   ├── versions.json            # 版本数据（自动生成，需提交）
│   ├── sglang_tags.json         # SGLang 同步标签
│   ├── vllm-openai_tags.json    # vLLM 同步标签
│   └── import_data.json         # 历史数据导入模板
├── pages/
│   └── index.html               # 生成的页面（自动生成）
└── images.txt                   # 镜像列表
```

## 工作流程

```
images.txt 修改 → Docker workflow → 镜像推送 ACR → 钉钉通知
                                                        ↓
                                                 Pages workflow 触发
                                                        ↓
                                         收集版本 → 合并标签 → 生成页面 → 部署

SGLang/vLLM 定时 → 同步最新标签 → 钉钉通知
                                   ↓
                            Pages workflow 触发
```

## 本地测试

```bash
# 1. 收集版本数据
bash scripts/collect_versions.sh

# 2. 生成页面（使用原始密码）
export ALIYUN_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
export ALIYUN_NAME_SPACE="my-namespace"
export PAGE_MASTER_PASSWORD="your_master_password"
export PAGE_USERS="admin:admin123"
bash scripts/generate_page.sh

# 3. 启动本地服务
cd pages && python3 -m http.server 8080
```

## 常见问题

**Q: 没有配置 PAGE_USERS 会怎样？**
A: 页面会允许任何用户名密码登录（开发模式）。生产环境请务必配置。

**Q: versions.json 需要手动提交吗？**
A: 不需要，GitHub Actions 会自动提交。但如果本地修改了 images.txt，需要手动运行 collect_versions.sh 并提交。

**Q: 可以删除旧的版本记录吗？**
A: 直接编辑 data/versions.json 删除不需要的条目，然后提交即可。

**Q: 页面密码安全吗？**
A: 密码使用 PBKDF2（100,000 次迭代）哈希后嵌入 HTML。镜像数据使用 AES-256-GCM 加密。页面是静态的，验证在浏览器端完成。适合内部使用，不适合高安全要求场景。

**Q: 配置了 WEBHOOK_URL 但没收到通知？**
A: 检查钉钉机器人的安全设置（加签/关键词/IP 白名单）。当前推送的消息关键词为同步相关标题，通常无需额外配置关键词。
