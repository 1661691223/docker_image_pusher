# Docker Image Registry Pages

GitHub Pages 展示所有 Docker 镜像的当前和历史版本，支持用户认证。

## 功能特性

-   自动收集每次 build 后的镜像版本信息
-   支持导入历史版本数据
-   用户认证（通过 GitHub Secrets 配置多个用户）
-   搜索和过滤镜像
-   一键复制 pull 命令
-   响应式设计，支持移动端

## 快速开始

### 1. 配置 GitHub Secrets

进入仓库 Settings → Secrets and variables → Actions，添加以下 Secrets：

| Secret 名称 | 说明 | 示例 |
|---|---|---|
| `ALIYUN_REGISTRY` | 阿里云仓库地址 | `registry.cn-hangzhou.aliyuncs.com` |
| `ALIYUN_NAME_SPACE` | 阿里云命名空间 | `my-images` |
| `PAGE_USERS` | 用户认证配置 | `user1:hash1,user2:hash2` |

### 2. 配置用户认证

`PAGE_USERS` 的格式为 `用户名:密码哈希,用户名2:密码哈希2`。

密码使用 SHA-256 哈希。生成方式：

```bash
# 方式1: 使用 echo + sha256sum
echo -n "your_password" | sha256sum | awk '{print $1}'

# 方式2: 使用 python
python3 -c "import hashlib; print(hashlib.sha256('your_password'.encode()).hexdigest())"

# 方式3: 使用 openssl
echo -n "your_password" | openssl dgst -sha256 | awk '{print $2}'
```

示例：为 user1 设置密码 `mypassword123`：
```bash
echo -n "mypassword123" | sha256sum
# 输出: a1b2c3d4e5f6...

# PAGE_USERS 值:
# user1:a1b2c3d4e5f6...
```

多个用户：
```bash
# PAGE_USERS 值:
# admin:abc123...,viewer:def456...,user:ghi789...
```

### 3. 启用 GitHub Pages

1. 进入仓库 Settings → Pages
2. Source 选择 "GitHub Actions"
3. 保存

### 4. 触发构建

- 自动触发：每次 Docker workflow 完成后自动构建
- 手动触发：进入 Actions → Docker Pages → Run workflow
- 代码触发：修改 images.txt 或 pages 相关文件后自动构建

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
│   ├── docker.yaml          # 原有的 Docker 构建 workflow
│   └── pages.yml            # Pages 部署 workflow
├── scripts/
│   ├── collect_versions.sh  # 收集版本数据脚本
│   ├── generate_page.sh     # 生成 HTML 页面脚本
│   └── import_history.sh    # 导入历史数据脚本
├── data/
│   ├── versions.json        # 版本数据（自动生成，需提交）
│   └── import_data.json     # 历史数据导入模板
├── pages/
│   └── index.html           # 生成的页面（自动生成）
└── images.txt               # 镜像列表
```

## 工作流程

```
images.txt 修改 → Docker workflow 运行 → 镜像推送到阿里云
                                          ↓
                                   Pages workflow 触发
                                          ↓
                                   收集版本数据 → 更新 versions.json
                                          ↓
                                   生成 index.html → 部署到 GitHub Pages
```

## 本地测试

```bash
# 1. 收集版本数据
bash scripts/collect_versions.sh

# 2. 生成页面
export ALIYUN_REGISTRY="registry.cn-hangzhou.aliyuncs.com"
export ALIYUN_NAME_SPACE="my-namespace"
export PAGE_USERS="admin:$(echo -n 'admin123' | sha256sum | awk '{print $1}')"
bash scripts/generate_page.sh

# 3. 打开页面
open pages/index.html
# 或用 python 启动本地服务
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
A: 密码使用 SHA-256 哈希存储在构建时注入到 HTML 中。页面是静态的，密码验证在浏览器端完成。适合内部使用，不适合高安全要求场景。
