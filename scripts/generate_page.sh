#!/bin/bash
# generate_page.sh - 生成 GitHub Pages HTML 页面
# 安全特性：
# - 密码哈希: PBKDF2(password, user_hash_salt, 100000)
# - 数据加密: AES-256-GCM with PBKDF2-derived key
# - 每用户独立 salt，无哈希可比对

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
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0d1117;color:#c9d1d9;min-height:100vh}
        .overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:#0d1117;display:flex;justify-content:center;align-items:center;z-index:1000}
        .box{background:#161b22;border:1px solid #30363d;border-radius:12px;padding:40px;width:360px;box-shadow:0 8px 32px rgba(0,0,0,.5)}
        .box h2{text-align:center;margin-bottom:8px;color:#f0f6fc;font-size:24px}
        .box p{text-align:center;color:#8b949e;margin-bottom:24px;font-size:14px}
        .box input{width:100%;padding:12px 16px;margin-bottom:16px;background:#0d1117;border:1px solid #30363d;border-radius:8px;color:#c9d1d9;font-size:14px;outline:none}
        .box input:focus{border-color:#58a6ff}
        .box button{width:100%;padding:12px;background:#238636;border:none;border-radius:8px;color:#fff;font-size:16px;font-weight:600;cursor:pointer}
        .box button:hover{background:#2ea043}
        .box button:disabled{background:#21262d;color:#484f58;cursor:not-allowed}
        .err{color:#f85149;text-align:center;margin-top:12px;font-size:14px;display:none}
        .hdr{background:#161b22;border-bottom:1px solid #30363d;padding:16px 24px;display:flex;justify-content:space-between;align-items:center}
        .hdr h1{font-size:20px;color:#f0f6fc}
        .hdr h1::before{content:"🐳 "}
        .hdr-r{display:flex;align-items:center;gap:16px}
        .uinfo{color:#8b949e;font-size:14px}
        .lbtn{background:0;border:1px solid #30363d;color:#c9d1d9;padding:6px 12px;border-radius:6px;cursor:pointer;font-size:13px}
        .lbtn:hover{border-color:#f85149;color:#f85149}
        .stats{display:flex;gap:24px;padding:20px 24px;background:#161b22;border-bottom:1px solid #30363d}
        .sc{background:#0d1117;border:1px solid #30363d;border-radius:8px;padding:16px 20px;min-width:160px}
        .sc .lb{color:#8b949e;font-size:12px;text-transform:uppercase}
        .sc .vl{color:#58a6ff;font-size:28px;font-weight:700;margin-top:4px}
        .ctrl{padding:16px 24px;display:flex;gap:12px;flex-wrap:wrap;align-items:center}
        .sb{flex:1;min-width:250px;padding:10px 16px;background:#0d1117;border:1px solid #30363d;border-radius:8px;color:#c9d1d9;font-size:14px;outline:none}
        .sb:focus{border-color:#58a6ff}
        .fb{padding:10px 16px;background:#21262d;border:1px solid #30363d;border-radius:8px;color:#c9d1d9;cursor:pointer;font-size:14px}
        .fb:hover,.fb.active{background:#1f6feb;border-color:#1f6feb;color:#fff}
        .tc{padding:0 24px 24px;overflow-x:auto}
        table{width:100%;border-collapse:collapse;background:#161b22;border:1px solid #30363d;border-radius:8px;overflow:hidden}
        th{background:#1c2128;padding:12px 16px;text-align:left;font-size:12px;text-transform:uppercase;color:#8b949e;border-bottom:1px solid #30363d;cursor:pointer;user-select:none;white-space:nowrap}
        th:hover{color:#c9d1d9}
        td{padding:12px 16px;border-bottom:1px solid #21262d;font-size:14px;white-space:nowrap}
        tr:last-child td{border-bottom:none}
        tr:hover{background:#1c2128}
        .tag{display:inline-block;padding:2px 8px;background:#1f6feb22;color:#58a6ff;border-radius:12px;font-size:12px;font-weight:500}
        .pb{display:inline-block;padding:2px 8px;background:#23863622;color:#3fb950;border-radius:12px;font-size:11px}
        .pc{background:#0d1117;padding:6px 12px;border-radius:6px;font-family:Monaco,Menlo,monospace;font-size:13px;color:#79c0ff;cursor:pointer;border:1px solid transparent;display:inline-block;max-width:400px;overflow:hidden;text-overflow:ellipsis}
        .pc:hover{border-color:#58a6ff;background:#1c2128}
        .pc.ok{background:#23863622;border-color:#3fb950;color:#3fb950}
        .tc2{color:#8b949e;font-size:13px}
        .empty{text-align:center;padding:60px 24px;color:#8b949e}
        .empty h3{margin-bottom:8px;color:#c9d1d9}
        .hidden{display:none!important}
        @media(max-width:768px){.stats{flex-wrap:wrap}.sc{min-width:120px}.pc{max-width:200px}}
    </style>
</head>
<body>
    <div id="overlay" class="overlay">
        <div class="box">
            <h2>🐳 Docker Registry</h2>
            <p>Sign in to continue</p>
            <input type="text" id="user" placeholder="Username" autocomplete="username">
            <input type="password" id="pass" placeholder="Password" autocomplete="current-password">
            <button id="btn" onclick="login()">Login</button>
            <div id="err" class="err"></div>
        </div>
    </div>
    <div id="main" class="hidden">
        <div class="hdr">
            <h1>Docker Image Registry</h1>
            <div class="hdr-r">
                <span class="uinfo">👤 <span id="cur"></span></span>
                <button class="lbtn" onclick="logout()">Logout</button>
            </div>
        </div>
        <div class="stats">
            <div class="sc"><div class="lb">Total Images</div><div class="vl" id="s1">0</div></div>
            <div class="sc"><div class="lb">Unique Names</div><div class="vl" id="s2">0</div></div>
            <div class="sc"><div class="lb">Last Updated</div><div class="vl" id="s3" style="font-size:16px">-</div></div>
        </div>
        <div class="ctrl">
            <input type="text" class="sb" id="q" placeholder="🔍 Search images...">
            <button class="fb active" data-f="all" onclick="filt('all')">All</button>
            <button class="fb" data-f="arm64" onclick="filt('arm64')">ARM64</button>
            <button class="fb" data-f="amd64" onclick="filt('amd64')">AMD64</button>
        </div>
        <div class="tc">
            <table><thead><tr>
                <th onclick="sort('name')">Name <span>↕</span></th>
                <th onclick="sort('namespace')">Namespace <span>↕</span></th>
                <th onclick="sort('tag')">Tag <span>↕</span></th>
                <th>Platform</th>
                <th onclick="sort('build_time')">Build Time <span>↕</span></th>
                <th>Pull Command (click to copy)</th>
            </tr></thead><tbody id="tb"></tbody></table>
            <div id="emp" class="empty hidden"><h3>No images found</h3><p>Try a different search term</p></div>
        </div>
    </div>
    <script>
        const CFG = __ENCRYPTED_JSON__;
        let D = null;

        // Base64 helpers
        function b64(s){return Uint8Array.from(atob(s),c=>c.charCodeAt(0))}
        function hex(buf){return Array.from(new Uint8Array(buf)).map(b=>b.toString(16).padStart(2,'0')).join('')}

        // PBKDF2 key derivation
        async function pbkdf2(pw, salt, usage){
            const km = await crypto.subtle.importKey('raw', new TextEncoder().encode(pw), 'PBKDF2', false, ['deriveBits']);
            const bits = await crypto.subtle.deriveBits(
                {name:'PBKDF2', salt:b64(salt), iterations:100000, hash:'SHA-256'},
                km, 256
            );
            if(usage === 'hash') return hex(bits);
            // For encryption, convert to CryptoKey
            return crypto.subtle.importKey('raw', bits, 'AES-GCM', false, ['decrypt']);
        }

        // AES-GCM decryption
        async function aesDecrypt(key, iv, ct){
            try {
                const dec = await crypto.subtle.decrypt({name:'AES-GCM', iv:b64(iv)}, key, b64(ct));
                return new TextDecoder().decode(dec);
            } catch { return null; }
        }

        async function login(){
            const u = document.getElementById('user').value.trim();
            const p = document.getElementById('pass').value;
            const btn = document.getElementById('btn');
            if(!u || !p){ show('Please enter username and password'); return; }

            const udata = CFG.users[u];
            if(!udata){ show('Invalid username or password'); return; }

            btn.textContent = 'Verifying...';
            btn.disabled = true;

            // Step 1: Verify password hash (PBKDF2 with hash_salt)
            const hash = await pbkdf2(p, udata.hash_salt, 'hash');
            if(hash !== udata.hash){
                btn.textContent = 'Login';
                btn.disabled = false;
                show('Invalid username or password');
                return;
            }

            // Step 2: Decrypt master key (PBKDF2 with enc_salt)
            const encKey = await pbkdf2(p, udata.enc_salt, 'decrypt');
            const mk = await aesDecrypt(encKey, udata.iv, udata.mk);
            if(!mk){
                btn.textContent = 'Login';
                btn.disabled = false;
                show('Decryption error');
                return;
            }

            // Step 3: Decrypt data with master key
            const mkKey = await pbkdf2(mk, CFG.salt, 'decrypt');
            const raw = await aesDecrypt(mkKey, CFG.iv, CFG.data);
            if(!raw){
                btn.textContent = 'Login';
                btn.disabled = false;
                show('Data error');
                return;
            }

            D = JSON.parse(raw);
            btn.textContent = 'Login';
            btn.disabled = false;
            ok(u);
        }

        function ok(u){sessionStorage.setItem('s','1');sessionStorage.setItem('u',u);document.getElementById('overlay').classList.add('hidden');document.getElementById('main').classList.remove('hidden');document.getElementById('cur').textContent=u;render()}
        function logout(){sessionStorage.clear();D=null;document.getElementById('overlay').classList.remove('hidden');document.getElementById('main').classList.add('hidden');document.getElementById('user').value='';document.getElementById('pass').value=''}
        function show(m){const e=document.getElementById('err');e.textContent=m;e.style.display='block';setTimeout(()=>e.style.display='none',3000)}

        let cf='all',cs={k:'build_time',a:false};
        function filt(f){cf=f;document.querySelectorAll('.fb').forEach(b=>b.classList.toggle('active',b.dataset.f===f));render()}
        function sort(k){if(cs.k===k)cs.a=!cs.a;else{cs.k=k;cs.a=true}render()}
        function imgs(){
            if(!D)return[];
            const q=document.getElementById('q').value.toLowerCase();
            let i=D.images||[];
            if(q)i=i.filter(x=>x.name.toLowerCase().includes(q)||x.tag.toLowerCase().includes(q)||(x.namespace||'').toLowerCase().includes(q)||(x.platform||'').toLowerCase().includes(q));
            if(cf!=='all')i=i.filter(x=>(x.platform||'').toLowerCase().includes(cf));
            i.sort((a,b)=>{let va=(a[cs.k]||'').toLowerCase(),vb=(b[cs.k]||'').toLowerCase();return va<vb?(cs.a?-1:1):va>vb?(cs.a?1:-1):0});
            return i;
        }
        function cmd(i){let pp=i.platform?i.platform.replace(/\//g,'_')+'_':'';let np='';const all=D.images||[];const s=all.filter(x=>x.name===i.name);const ns=[...new Set(s.map(x=>x.namespace||''))];if(ns.length>1&&i.namespace)np=i.namespace+'_';return`docker pull ${D.registry}/${D.namespace}/${pp}${np}${i.name}:${i.tag}`}
        function render(){
            const i=imgs();const tb=document.getElementById('tb');const em=document.getElementById('emp');
            document.getElementById('s1').textContent=i.length;
            document.getElementById('s2').textContent=new Set(i.map(x=>x.name)).size;
            document.getElementById('s3').textContent=D?.last_updated?new Date(D.last_updated).toLocaleString('zh-CN'):'-';
            if(!i.length){tb.innerHTML='';em.classList.remove('hidden');return}em.classList.add('hidden');
            tb.innerHTML=i.map(x=>{const c=cmd(x);const pl=x.platform||'-';const t=x.build_time?new Date(x.build_time).toLocaleString('zh-CN'):'-';return`<tr><td><strong>${e(x.name)}</strong></td><td>${e(x.namespace||'-')}</td><td><span class="tag">${e(x.tag)}</span></td><td>${pl!=='-'?`<span class="pb">${e(pl)}</span>`:'-'}</td><td class="tc2">${t}</td><td><code class="pc" onclick="cp(this)">${e(c)}</code></td></tr>`}).join('');
        }
        function e(s){const d=document.createElement('div');d.textContent=s;return d.innerHTML}
        function cp(el){navigator.clipboard.writeText(el.textContent).then(()=>{el.classList.add('ok');const o=el.textContent;el.textContent='✓ Copied!';setTimeout(()=>{el.textContent=o;el.classList.remove('ok')},1500)})}
        document.addEventListener('DOMContentLoaded',()=>{document.getElementById('q').addEventListener('input',render);document.getElementById('pass').addEventListener('keydown',e=>{if(e.key==='Enter')login()});document.getElementById('user').addEventListener('keydown',e=>{if(e.key==='Enter')document.getElementById('pass').focus()})});
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

# Master data to encrypt
master_data = {
    "images": versions.get("images", []),
    "last_updated": versions.get("last_updated", ""),
    "registry": REGISTRY,
    "namespace": NAMESPACE
}

# Generate master encryption key
master_salt = secrets.token_bytes(16)
master_iv = secrets.token_bytes(12)
master_kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=master_salt, iterations=100000)
master_key = master_kdf.derive(MASTER_PASSWORD.encode())

# Encrypt master data
data_aes = AESGCM(master_key)
data_ct = data_aes.encrypt(master_iv, json.dumps(master_data, ensure_ascii=False).encode(), None)

# Build users with separate salts for hash and encryption
users_out = {}
if USERS_CONFIG:
    for pair in USERS_CONFIG.split(','):
        pair = pair.strip()
        if ':' not in pair:
            continue
        uname, pwd = pair.split(':', 1)
        uname, pwd = uname.strip(), pwd.strip()

        # 1. Generate hash: PBKDF2(password, hash_salt, 100000) -> hex
        hash_salt = secrets.token_bytes(16)
        hash_kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=hash_salt, iterations=100000)
        pwd_hash = hash_kdf.derive(pwd.encode())
        pwd_hash_hex = pwd_hash.hex()

        # 2. Encrypt master key with user's password (separate salt!)
        enc_salt = secrets.token_bytes(16)
        enc_iv = secrets.token_bytes(12)
        enc_kdf = PBKDF2HMAC(algorithm=hashes.SHA256(), length=32, salt=enc_salt, iterations=100000)
        enc_key = enc_kdf.derive(pwd.encode())
        enc_aes = AESGCM(enc_key)
        mk_ct = enc_aes.encrypt(enc_iv, MASTER_PASSWORD.encode(), None)

        users_out[uname] = {
            "hash_salt": base64.b64encode(hash_salt).decode(),
            "hash": pwd_hash_hex,
            "enc_salt": base64.b64encode(enc_salt).decode(),
            "iv": base64.b64encode(enc_iv).decode(),
            "mk": base64.b64encode(mk_ct).decode()
        }

# Final encrypted config
encrypted = {
    "salt": base64.b64encode(master_salt).decode(),
    "iv": base64.b64encode(master_iv).decode(),
    "data": base64.b64encode(data_ct).decode(),
    "users": users_out
}

html = html.replace('__ENCRYPTED_JSON__', json.dumps(encrypted))

with open(OUTPUT_FILE, 'w') as f:
    f.write(html)

print("Done!")
print(f"  Users: {list(users_out.keys())}")
print(f"  Images: {len(master_data['images'])}")
print(f"  Hash: PBKDF2-SHA256-100k with per-user salt")
print(f"  Encryption: AES-256-GCM with PBKDF2-derived key")
PYEOF

echo "Page generated: $OUTPUT_FILE"
