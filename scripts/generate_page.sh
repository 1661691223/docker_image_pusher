#!/bin/bash
# generate_page.sh - 生成 GitHub Pages HTML 页面
# 用法: ./generate_page.sh
# 环境变量:
#   PAGE_USERS - 用户认证配置，格式: "user1:sha256hash1,user2:sha256hash2"
#   ALIYUN_REGISTRY - 阿里云仓库地址
#   ALIYUN_NAME_SPACE - 阿里云命名空间

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$REPO_DIR/data"
VERSIONS_FILE="$DATA_DIR/versions.json"
OUTPUT_DIR="$REPO_DIR/pages"
OUTPUT_FILE="$OUTPUT_DIR/index.html"

mkdir -p "$OUTPUT_DIR"

# 默认值
REGISTRY="${ALIYUN_REGISTRY:-registry.cn-hangzhou.aliyuncs.com}"
NAMESPACE="${ALIYUN_NAME_SPACE:-}"
USERS_CONFIG="${PAGE_USERS:-}"

# 读取版本数据
if [ ! -f "$VERSIONS_FILE" ]; then
    echo "WARNING: $VERSIONS_FILE not found, creating empty page"
    VERSIONS_JSON='{"images":[],"last_updated":""}'
else
    VERSIONS_JSON=$(cat "$VERSIONS_FILE")
fi

# 生成页面
cat > "$OUTPUT_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Docker Image Registry</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0d1117;
            color: #c9d1d9;
            min-height: 100vh;
        }
        .login-overlay {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.9);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 1000;
        }
        .login-box {
            background: #161b22;
            border: 1px solid #30363d;
            border-radius: 12px;
            padding: 40px;
            width: 360px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.5);
        }
        .login-box h2 {
            text-align: center;
            margin-bottom: 8px;
            color: #f0f6fc;
            font-size: 24px;
        }
        .login-box p {
            text-align: center;
            color: #8b949e;
            margin-bottom: 24px;
            font-size: 14px;
        }
        .login-box input {
            width: 100%;
            padding: 12px 16px;
            margin-bottom: 16px;
            background: #0d1117;
            border: 1px solid #30363d;
            border-radius: 8px;
            color: #c9d1d9;
            font-size: 14px;
            outline: none;
            transition: border-color 0.2s;
        }
        .login-box input:focus { border-color: #58a6ff; }
        .login-box button {
            width: 100%;
            padding: 12px;
            background: #238636;
            border: none;
            border-radius: 8px;
            color: white;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.2s;
        }
        .login-box button:hover { background: #2ea043; }
        .login-error {
            color: #f85149;
            text-align: center;
            margin-top: 12px;
            font-size: 14px;
            display: none;
        }
        .header {
            background: #161b22;
            border-bottom: 1px solid #30363d;
            padding: 16px 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .header h1 {
            font-size: 20px;
            color: #f0f6fc;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .header h1::before {
            content: "🐳";
        }
        .header-right {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        .user-info {
            color: #8b949e;
            font-size: 14px;
        }
        .logout-btn {
            background: transparent;
            border: 1px solid #30363d;
            color: #c9d1d9;
            padding: 6px 12px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 13px;
        }
        .logout-btn:hover { border-color: #f85149; color: #f85149; }
        .stats {
            display: flex;
            gap: 24px;
            padding: 20px 24px;
            background: #161b22;
            border-bottom: 1px solid #30363d;
        }
        .stat-card {
            background: #0d1117;
            border: 1px solid #30363d;
            border-radius: 8px;
            padding: 16px 20px;
            min-width: 160px;
        }
        .stat-card .label { color: #8b949e; font-size: 12px; text-transform: uppercase; }
        .stat-card .value { color: #58a6ff; font-size: 28px; font-weight: 700; margin-top: 4px; }
        .controls {
            padding: 16px 24px;
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
            align-items: center;
        }
        .search-box {
            flex: 1;
            min-width: 250px;
            padding: 10px 16px;
            background: #0d1117;
            border: 1px solid #30363d;
            border-radius: 8px;
            color: #c9d1d9;
            font-size: 14px;
            outline: none;
        }
        .search-box:focus { border-color: #58a6ff; }
        .filter-btn {
            padding: 10px 16px;
            background: #21262d;
            border: 1px solid #30363d;
            border-radius: 8px;
            color: #c9d1d9;
            cursor: pointer;
            font-size: 14px;
            transition: all 0.2s;
        }
        .filter-btn:hover, .filter-btn.active {
            background: #1f6feb;
            border-color: #1f6feb;
            color: white;
        }
        .table-container {
            padding: 0 24px 24px;
            overflow-x: auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: #161b22;
            border: 1px solid #30363d;
            border-radius: 8px;
            overflow: hidden;
        }
        th {
            background: #1c2128;
            padding: 12px 16px;
            text-align: left;
            font-size: 12px;
            text-transform: uppercase;
            color: #8b949e;
            border-bottom: 1px solid #30363d;
            cursor: pointer;
            user-select: none;
            white-space: nowrap;
        }
        th:hover { color: #c9d1d9; }
        th .sort-icon { margin-left: 4px; opacity: 0.5; }
        th.sorted .sort-icon { opacity: 1; color: #58a6ff; }
        td {
            padding: 12px 16px;
            border-bottom: 1px solid #21262d;
            font-size: 14px;
            white-space: nowrap;
        }
        tr:last-child td { border-bottom: none; }
        tr:hover { background: #1c2128; }
        .tag {
            display: inline-block;
            padding: 2px 8px;
            background: #1f6feb22;
            color: #58a6ff;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 500;
        }
        .platform-badge {
            display: inline-block;
            padding: 2px 8px;
            background: #23863622;
            color: #3fb950;
            border-radius: 12px;
            font-size: 11px;
        }
        .pull-cmd {
            background: #0d1117;
            padding: 6px 12px;
            border-radius: 6px;
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 13px;
            color: #79c0ff;
            cursor: pointer;
            border: 1px solid transparent;
            transition: all 0.2s;
            display: inline-block;
            max-width: 400px;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .pull-cmd:hover {
            border-color: #58a6ff;
            background: #1c2128;
        }
        .pull-cmd.copied {
            background: #23863622;
            border-color: #3fb950;
            color: #3fb950;
        }
        .time-col { color: #8b949e; font-size: 13px; }
        .empty-state {
            text-align: center;
            padding: 60px 24px;
            color: #8b949e;
        }
        .empty-state h3 { margin-bottom: 8px; color: #c9d1d9; }
        .hidden { display: none !important; }
        .tooltip {
            position: fixed;
            background: #3fb950;
            color: #0d1117;
            padding: 6px 12px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 600;
            pointer-events: none;
            z-index: 999;
            opacity: 0;
            transition: opacity 0.2s;
        }
        .tooltip.show { opacity: 1; }
        @media (max-width: 768px) {
            .stats { flex-wrap: wrap; }
            .stat-card { min-width: 120px; }
            .pull-cmd { max-width: 200px; }
        }
    </style>
</head>
<body>
    <!-- Login Overlay -->
    <div id="loginOverlay" class="login-overlay">
        <div class="login-box">
            <h2>🐳 Docker Registry</h2>
            <p>Please login to continue</p>
            <input type="text" id="username" placeholder="Username" autocomplete="username">
            <input type="password" id="password" placeholder="Password" autocomplete="current-password">
            <button onclick="doLogin()">Login</button>
            <div id="loginError" class="login-error">Invalid username or password</div>
        </div>
    </div>

    <!-- Main Content -->
    <div id="mainContent" class="hidden">
        <div class="header">
            <h1>Docker Image Registry</h1>
            <div class="header-right">
                <span class="user-info">👤 <span id="currentUser"></span></span>
                <button class="logout-btn" onclick="doLogout()">Logout</button>
            </div>
        </div>

        <div class="stats">
            <div class="stat-card">
                <div class="label">Total Images</div>
                <div class="value" id="statTotal">0</div>
            </div>
            <div class="stat-card">
                <div class="label">Unique Names</div>
                <div class="value" id="statNames">0</div>
            </div>
            <div class="stat-card">
                <div class="label">Last Updated</div>
                <div class="value" id="statUpdated" style="font-size:16px">-</div>
            </div>
        </div>

        <div class="controls">
            <input type="text" class="search-box" id="searchBox" placeholder="🔍 Search images by name, tag, namespace...">
            <button class="filter-btn active" data-filter="all" onclick="setFilter('all')">All</button>
            <button class="filter-btn" data-filter="arm64" onclick="setFilter('arm64')">ARM64</button>
            <button class="filter-btn" data-filter="amd64" onclick="setFilter('amd64')">AMD64</button>
        </div>

        <div class="table-container">
            <table id="imageTable">
                <thead>
                    <tr>
                        <th onclick="sortBy('name')">Name <span class="sort-icon">↕</span></th>
                        <th onclick="sortBy('namespace')">Namespace <span class="sort-icon">↕</span></th>
                        <th onclick="sortBy('tag')">Tag <span class="sort-icon">↕</span></th>
                        <th>Platform</th>
                        <th onclick="sortBy('build_time')">Build Time <span class="sort-icon">↕</span></th>
                        <th>Pull Command (click to copy)</th>
                    </tr>
                </thead>
                <tbody id="imageBody">
                </tbody>
            </table>
            <div id="emptyState" class="empty-state hidden">
                <h3>No images found</h3>
                <p>Try a different search term or filter</p>
            </div>
        </div>
    </div>

    <div id="tooltip" class="tooltip">Copied!</div>

    <script>
        // ============ CONFIGURATION ============
        // Users are injected at build time from GitHub Secrets
        // Format: { "username": "sha256hash", ... }
        const AUTHORIZED_USERS = __USERS_CONFIG__;

        // Registry configuration
        const REGISTRY = "__REGISTRY__";
        const NAMESPACE = "__NAMESPACE__";

        // Version data
        const VERSION_DATA = __VERSIONS_JSON__;

        // ============ AUTH ============
        async function sha256(message) {
            const msgBuffer = new TextEncoder().encode(message);
            const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
            const hashArray = Array.from(new Uint8Array(hashBuffer));
            return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
        }

        async function doLogin() {
            const username = document.getElementById('username').value.trim();
            const password = document.getElementById('password').value;
            
            if (!username || !password) {
                showError('Please enter username and password');
                return;
            }

            // 如果没有配置用户，允许任何登录（开发模式）
            if (Object.keys(AUTHORIZED_USERS).length === 0) {
                loginSuccess(username);
                return;
            }

            const hash = await sha256(password);
            if (AUTHORIZED_USERS[username] && AUTHORIZED_USERS[username] === hash) {
                loginSuccess(username);
            } else {
                showError('Invalid username or password');
            }
        }

        function loginSuccess(username) {
            sessionStorage.setItem('loggedIn', 'true');
            sessionStorage.setItem('username', username);
            document.getElementById('loginOverlay').classList.add('hidden');
            document.getElementById('mainContent').classList.remove('hidden');
            document.getElementById('currentUser').textContent = username;
            renderTable();
        }

        function doLogout() {
            sessionStorage.removeItem('loggedIn');
            sessionStorage.removeItem('username');
            document.getElementById('loginOverlay').classList.remove('hidden');
            document.getElementById('mainContent').classList.add('hidden');
            document.getElementById('username').value = '';
            document.getElementById('password').value = '';
        }

        function showError(msg) {
            const el = document.getElementById('loginError');
            el.textContent = msg;
            el.style.display = 'block';
            setTimeout(() => el.style.display = 'none', 3000);
        }

        // 检查登录状态
        function checkAuth() {
            if (sessionStorage.getItem('loggedIn') === 'true') {
                document.getElementById('loginOverlay').classList.add('hidden');
                document.getElementById('mainContent').classList.remove('hidden');
                document.getElementById('currentUser').textContent = sessionStorage.getItem('username');
            }
        }

        // ============ TABLE ============
        let currentFilter = 'all';
        let currentSort = { key: 'build_time', asc: false };

        function setFilter(filter) {
            currentFilter = filter;
            document.querySelectorAll('.filter-btn').forEach(btn => {
                btn.classList.toggle('active', btn.dataset.filter === filter);
            });
            renderTable();
        }

        function sortBy(key) {
            if (currentSort.key === key) {
                currentSort.asc = !currentSort.asc;
            } else {
                currentSort.key = key;
                currentSort.asc = true;
            }
            renderTable();
        }

        function getFilteredImages() {
            const search = document.getElementById('searchBox').value.toLowerCase();
            let images = VERSION_DATA.images || [];

            // Search filter
            if (search) {
                images = images.filter(img =>
                    img.name.toLowerCase().includes(search) ||
                    img.tag.toLowerCase().includes(search) ||
                    (img.namespace || '').toLowerCase().includes(search) ||
                    (img.platform || '').toLowerCase().includes(search)
                );
            }

            // Platform filter
            if (currentFilter !== 'all') {
                images = images.filter(img =>
                    (img.platform || '').toLowerCase().includes(currentFilter)
                );
            }

            // Sort
            images.sort((a, b) => {
                let va = (a[currentSort.key] || '').toLowerCase();
                let vb = (b[currentSort.key] || '').toLowerCase();
                if (va < vb) return currentSort.asc ? -1 : 1;
                if (va > vb) return currentSort.asc ? 1 : -1;
                return 0;
            });

            return images;
        }

        function buildPullCmd(img) {
            const ns = img.namespace || NAMESPACE;
            const reg = img.registry || REGISTRY;
            let fullName = '';
            if (ns) {
                fullName = `${reg}/${ns}/${img.name}:${img.tag}`;
            } else {
                fullName = `${reg}/${img.name}:${img.tag}`;
            }
            return `docker pull ${fullName}`;
        }

        function renderTable() {
            const images = getFilteredImages();
            const tbody = document.getElementById('imageBody');
            const emptyState = document.getElementById('emptyState');

            // Stats
            document.getElementById('statTotal').textContent = images.length;
            const uniqueNames = new Set(images.map(i => i.name));
            document.getElementById('statNames').textContent = uniqueNames.size;
            document.getElementById('statUpdated').textContent =
                VERSION_DATA.last_updated
                    ? new Date(VERSION_DATA.last_updated).toLocaleString('zh-CN')
                    : '-';

            if (images.length === 0) {
                tbody.innerHTML = '';
                emptyState.classList.remove('hidden');
                return;
            }
            emptyState.classList.add('hidden');

            tbody.innerHTML = images.map(img => {
                const pullCmd = buildPullCmd(img);
                const platform = img.platform || '-';
                const buildTime = img.build_time
                    ? new Date(img.build_time).toLocaleString('zh-CN')
                    : '-';
                return `<tr>
                    <td><strong>${escHtml(img.name)}</strong></td>
                    <td>${escHtml(img.namespace || '-')}</td>
                    <td><span class="tag">${escHtml(img.tag)}</span></td>
                    <td>${platform !== '-' ? `<span class="platform-badge">${escHtml(platform)}</span>` : '-'}</td>
                    <td class="time-col">${buildTime}</td>
                    <td><code class="pull-cmd" onclick="copyCmd(this)">${escHtml(pullCmd)}</code></td>
                </tr>`;
            }).join('');
        }

        function escHtml(str) {
            const div = document.createElement('div');
            div.textContent = str;
            return div.innerHTML;
        }

        function copyCmd(el) {
            const text = el.textContent;
            navigator.clipboard.writeText(text).then(() => {
                el.classList.add('copied');
                const original = el.textContent;
                el.textContent = '✓ Copied!';
                setTimeout(() => {
                    el.textContent = original;
                    el.classList.remove('copied');
                }, 1500);
            });
        }

        // ============ INIT ============
        document.addEventListener('DOMContentLoaded', () => {
            checkAuth();
            renderTable();
            document.getElementById('searchBox').addEventListener('input', renderTable);
            
            // Enter key for login
            document.getElementById('password').addEventListener('keydown', e => {
                if (e.key === 'Enter') doLogin();
            });
            document.getElementById('username').addEventListener('keydown', e => {
                if (e.key === 'Enter') document.getElementById('password').focus();
            });
        });
    </script>
</body>
</html>
HTMLEOF

# 使用 sed 替换占位符
python3 -c "
import json, sys

# 读取版本数据
with open('$VERSIONS_FILE', 'r') as f:
    versions = json.load(f)

# 读取页面
with open('$OUTPUT_FILE', 'r') as f:
    html = f.read()

# 替换版本数据
html = html.replace('__VERSIONS_JSON__', json.dumps(versions, ensure_ascii=False))

# 替换 registry 和 namespace
html = html.replace('__REGISTRY__', '$REGISTRY')
html = html.replace('__NAMESPACE__', '$NAMESPACE')

# 处理用户配置
users_config = '$USERS_CONFIG'
if users_config:
    users_dict = {}
    for pair in users_config.split(','):
        pair = pair.strip()
        if ':' in pair:
            user, pwd_hash = pair.split(':', 1)
            users_dict[user.strip()] = pwd_hash.strip()
    html = html.replace('__USERS_CONFIG__', json.dumps(users_dict))
else:
    html = html.replace('__USERS_CONFIG__', '{}')

with open('$OUTPUT_FILE', 'w') as f:
    f.write(html)
"

echo "Page generated: $OUTPUT_FILE"
echo "Images count: $(cat "$VERSIONS_FILE" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["images"]))')"
