#!/bin/bash
# generate_page.sh - 生成 GitHub Pages HTML 页面（全数据 AES-256-GCM 加密）
# 用法: ./generate_page.sh
# 环境变量:
#   PAGE_MASTER_PASSWORD - 主密码（加密所有数据）
#   PAGE_USERS - 用户配置，格式: "user1:password1,user2:password2"
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

REGISTRY="${ALIYUN_REGISTRY:-registry.cn-hangzhou.aliyuncs.com}"
NAMESPACE="${ALIYUN_NAME_SPACE:-}"
MASTER_PASSWORD="${PAGE_MASTER_PASSWORD:-}"
USERS_CONFIG="${PAGE_USERS:-}"

if [ ! -f "$VERSIONS_FILE" ]; then
    echo "WARNING: $VERSIONS_FILE not found, creating empty page"
    VERSIONS_JSON='{"images":[],"last_updated":""}'
else
    VERSIONS_JSON=$(cat "$VERSIONS_FILE")
fi

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
            background: #0d1117;
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
        .login-box button:disabled {
            background: #21262d;
            color: #484f58;
            cursor: not-allowed;
        }
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
        .header h1::before { content: "🐳"; }
        .header-right {
            display: flex;
            align-items: center;
            gap: 16px;
        }
        .user-info { color: #8b949e; font-size: 14px; }
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
        @media (max-width: 768px) {
            .stats { flex-wrap: wrap; }
            .stat-card { min-width: 120px; }
            .pull-cmd { max-width: 200px; }
        }
    </style>
</head>
<body>
    <!-- Login -->
    <div id="loginOverlay" class="login-overlay">
        <div class="login-box">
            <h2>🐳 Docker Registry</h2>
            <p>Enter password to unlock</p>
            <input type="text" id="username" placeholder="Username" autocomplete="username">
            <input type="password" id="password" placeholder="Password" autocomplete="current-password">
            <button id="loginBtn" onclick="doLogin()">Login</button>
            <div id="loginError" class="login-error"></div>
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

    <script>
        // ============ ENCRYPTED DATA ============
        const ENCRYPTED = {
            salt: "__SALT_B64__",
            iv: "__IV_B64__",
            data: "__DATA_B64__"
        };

        // ============ CRYPTO ============
        let appData = null;

        function b64ToBuf(b64) {
            const bin = atob(b64);
            const buf = new Uint8Array(bin.length);
            for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
            return buf.buffer;
        }

        async function deriveKey(password, salt) {
            const enc = new TextEncoder();
            const km = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveKey']);
            return crypto.subtle.deriveKey(
                { name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
                km, { name: 'AES-GCM', length: 256 }, false, ['decrypt']
            );
        }

        async function sha256(msg) {
            const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(msg));
            return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
        }

        async function decrypt(password) {
            try {
                const salt = b64ToBuf(ENCRYPTED.salt);
                const iv = b64ToBuf(ENCRYPTED.iv);
                const data = b64ToBuf(ENCRYPTED.data);
                const key = await deriveKey(password, salt);
                const dec = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, data);
                return JSON.parse(new TextDecoder().decode(dec));
            } catch { return null; }
        }

        // ============ AUTH ============
        async function doLogin() {
            const btn = document.getElementById('loginBtn');
            const username = document.getElementById('username').value.trim();
            const password = document.getElementById('password').value;
            const errorEl = document.getElementById('loginError');

            if (!username || !password) { showError('Please enter username and password'); return; }

            btn.textContent = 'Verifying...';
            btn.disabled = true;

            // Try to decrypt with the entered password as master password
            appData = await decrypt(password);

            btn.textContent = 'Login';
            btn.disabled = false;

            if (!appData || !appData.users) {
                showError('Invalid password');
                return;
            }

            // Verify user credentials
            const pwdHash = await sha256(password);
            if (!appData.users[username]) {
                showError('Invalid username or password');
                appData = null;
                return;
            }

            // Check if stored password is a hash or plaintext
            const stored = appData.users[username];
            let valid = false;
            if (stored.length === 64 && /^[a-f0-9]+$/i.test(stored)) {
                // It's a SHA-256 hash
                valid = (pwdHash === stored);
            } else {
                // It's plaintext, compute hash
                const storedHash = await sha256(stored);
                valid = (pwdHash === storedHash);
            }

            if (!valid) {
                showError('Invalid username or password');
                appData = null;
                return;
            }

            loginSuccess(username);
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
            appData = null;
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

        function checkAuth() {
            if (sessionStorage.getItem('loggedIn') === 'true' && appData) {
                document.getElementById('loginOverlay').classList.add('hidden');
                document.getElementById('mainContent').classList.remove('hidden');
                document.getElementById('currentUser').textContent = sessionStorage.getItem('username');
            }
        }

        // ============ TABLE ============
        let currentFilter = 'all';
        let currentSort = { key: 'build_time', asc: false };

        function setFilter(f) {
            currentFilter = f;
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.toggle('active', b.dataset.filter === f));
            renderTable();
        }

        function sortBy(key) {
            if (currentSort.key === key) currentSort.asc = !currentSort.asc;
            else { currentSort.key = key; currentSort.asc = true; }
            renderTable();
        }

        function getImages() {
            if (!appData) return [];
            const search = document.getElementById('searchBox').value.toLowerCase();
            let images = appData.images || [];

            if (search) images = images.filter(i =>
                i.name.toLowerCase().includes(search) ||
                i.tag.toLowerCase().includes(search) ||
                (i.namespace||'').toLowerCase().includes(search) ||
                (i.platform||'').toLowerCase().includes(search)
            );

            if (currentFilter !== 'all') images = images.filter(i =>
                (i.platform||'').toLowerCase().includes(currentFilter)
            );

            images.sort((a, b) => {
                let va = (a[currentSort.key]||'').toLowerCase();
                let vb = (b[currentSort.key]||'').toLowerCase();
                return va < vb ? (currentSort.asc ? -1 : 1) : va > vb ? (currentSort.asc ? 1 : -1) : 0;
            });
            return images;
        }

        function pullCmd(img) {
            let pp = img.platform ? img.platform.replace(/\//g,'_')+'_' : '';
            let np = '';
            const all = appData.images || [];
            const same = all.filter(i => i.name === img.name);
            const ns = [...new Set(same.map(i => i.namespace||''))];
            if (ns.length > 1 && img.namespace) np = img.namespace + '_';
            return `docker pull ${appData.registry}/${appData.namespace}/${pp}${np}${img.name}:${img.tag}`;
        }

        function renderTable() {
            const images = getImages();
            const tbody = document.getElementById('imageBody');
            const empty = document.getElementById('emptyState');

            document.getElementById('statTotal').textContent = images.length;
            document.getElementById('statNames').textContent = new Set(images.map(i=>i.name)).size;
            document.getElementById('statUpdated').textContent = appData?.last_updated
                ? new Date(appData.last_updated).toLocaleString('zh-CN') : '-';

            if (!images.length) { tbody.innerHTML = ''; empty.classList.remove('hidden'); return; }
            empty.classList.add('hidden');

            tbody.innerHTML = images.map(i => {
                const cmd = pullCmd(i);
                const plat = i.platform || '-';
                const time = i.build_time ? new Date(i.build_time).toLocaleString('zh-CN') : '-';
                return `<tr>
                    <td><strong>${esc(i.name)}</strong></td>
                    <td>${esc(i.namespace||'-')}</td>
                    <td><span class="tag">${esc(i.tag)}</span></td>
                    <td>${plat!=='-'?`<span class="platform-badge">${esc(plat)}</span>`:'-'}</td>
                    <td class="time-col">${time}</td>
                    <td><code class="pull-cmd" onclick="copy(this)">${esc(cmd)}</code></td>
                </tr>`;
            }).join('');
        }

        function esc(s) { const d=document.createElement('div'); d.textContent=s; return d.innerHTML; }

        function copy(el) {
            navigator.clipboard.writeText(el.textContent).then(() => {
                el.classList.add('copied');
                const o = el.textContent;
                el.textContent = '✓ Copied!';
                setTimeout(() => { el.textContent = o; el.classList.remove('copied'); }, 1500);
            });
        }

        // ============ INIT ============
        document.addEventListener('DOMContentLoaded', () => {
            document.getElementById('searchBox').addEventListener('input', renderTable);
            document.getElementById('password').addEventListener('keydown', e => { if(e.key==='Enter') doLogin(); });
            document.getElementById('username').addEventListener('keydown', e => { if(e.key==='Enter') document.getElementById('password').focus(); });
        });
    </script>
</body>
</html>
HTMLEOF

python3 << PYEOF
import json, os, secrets, hashlib, base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes

VERSIONS_FILE = "$VERSIONS_FILE"
OUTPUT_FILE = "$OUTPUT_FILE"
REGISTRY = "$REGISTRY"
NAMESPACE = "$NAMESPACE"
MASTER_PASSWORD = "$MASTER_PASSWORD"
USERS_CONFIG = "$USERS_CONFIG"

with open(VERSIONS_FILE, 'r') as f:
    versions = json.load(f)

with open(OUTPUT_FILE, 'r') as f:
    html = f.read()

# Build users dict with SHA-256 hashed passwords
users_dict = {}
if USERS_CONFIG:
    for pair in USERS_CONFIG.split(','):
        pair = pair.strip()
        if ':' in pair:
            user, pwd = pair.split(':', 1)
            pwd_hash = hashlib.sha256(pwd.strip().encode()).hexdigest()
            users_dict[user.strip()] = pwd_hash

# Build combined data
app_data = {
    "users": users_dict,
    "images": versions.get("images", []),
    "last_updated": versions.get("last_updated", ""),
    "registry": REGISTRY,
    "namespace": NAMESPACE
}

# Encrypt everything
if MASTER_PASSWORD:
    salt = secrets.token_bytes(16)
    iv = secrets.token_bytes(12)
    kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=salt, iterations=100000)
    key = kdf.derive(MASTER_PASSWORD.encode())
    aesgcm = AESGCM(key)
    plaintext = json.dumps(app_data, ensure_ascii=False).encode('utf-8')
    ciphertext = aesgcm.encrypt(iv, plaintext, None)

    html = html.replace('__SALT_B64__', base64.b64encode(salt).decode())
    html = html.replace('__IV_B64__', base64.b64encode(iv).decode())
    html = html.replace('__DATA_B64__', base64.b64encode(ciphertext).decode())
    print("All data encrypted with AES-256-GCM")
    print(f"  Users: {list(users_dict.keys())}")
    print(f"  Images: {len(app_data['images'])}")
else:
    # No encryption - for development only
    html = html.replace('__SALT_B64__', '')
    html = html.replace('__IV_B64__', '')
    html = html.replace('__DATA_B64__', '')
    print("WARNING: No PAGE_MASTER_PASSWORD - encryption disabled")

with open(OUTPUT_FILE, 'w') as f:
    f.write(html)
PYEOF

echo "Page generated: $OUTPUT_FILE"
