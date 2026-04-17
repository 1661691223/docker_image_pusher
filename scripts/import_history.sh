#!/bin/bash
# import_history.sh - 导入历史镜像数据到 versions.json
# 用法:
#   ./import_history.sh                    # 从 data/import_data.json 导入
#   ./import_history.sh custom_file.json   # 从指定文件导入
#
# 数据格式 (JSON):
# [
#   {
#     "name": "nginx",
#     "namespace": "library",
#     "tag": "1.25.3",
#     "platform": "linux/amd64",
#     "build_time": "2024-01-15T10:30:00Z",
#     "run_id": "history-import"
#   }
# ]
#
# 或者简化格式 (只需要 name 和 tag):
# [
#   { "name": "nginx", "tag": "1.25.3" },
#   { "name": "alpine", "tag": "3.19" }
# ]
# 其他字段会自动填充默认值

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$REPO_DIR/data"
VERSIONS_FILE="$DATA_DIR/versions.json"
IMPORT_FILE="${1:-$DATA_DIR/import_data.json}"

mkdir -p "$DATA_DIR"

# 初始化 versions.json
if [ ! -f "$VERSIONS_FILE" ]; then
    echo '{"images":[],"last_updated":""}' > "$VERSIONS_FILE"
fi

if [ ! -f "$IMPORT_FILE" ]; then
    echo "ERROR: Import file not found: $IMPORT_FILE"
    echo ""
    echo "Usage: $0 [import_file.json]"
    echo ""
    echo "Create $IMPORT_FILE with your historical data."
    echo ""
    echo "Example format:"
    cat << 'EOF'
[
  {
    "name": "nginx",
    "namespace": "library",
    "tag": "1.25.3",
    "platform": "",
    "build_time": "2024-01-15T10:30:00Z"
  },
  {
    "name": "alpine",
    "tag": "3.19"
  }
]
EOF
    exit 1
fi

echo "Importing from: $IMPORT_FILE"

export IMPORT_FILE VERSIONS_FILE ALIYUN_REGISTRY ALIYUN_NAME_SPACE

python3 << 'PYEOF'
import json
from datetime import datetime
import os

REGISTRY = os.environ.get('ALIYUN_REGISTRY', 'registry.cn-hangzhou.aliyuncs.com')
NAMESPACE = os.environ.get('ALIYUN_NAME_SPACE', '')
IMPORT_FILE = os.environ.get('IMPORT_FILE', '')
VERSIONS_FILE = os.environ.get('VERSIONS_FILE', '')

with open(VERSIONS_FILE, 'r') as f:
    data = json.load(f)

with open(IMPORT_FILE, 'r') as f:
    imported = json.load(f)

# 支持两种格式: 直接数组 或 {"images": [...]}
if isinstance(imported, dict) and 'images' in imported:
    imported = imported['images']

if not isinstance(imported, list):
    print("ERROR: Invalid format. Expected JSON array or {\"images\": [...]}")
    exit(1)

count = 0
for item in imported:
    record = {
        'name': item.get('name', ''),
        'namespace': item.get('namespace', NAMESPACE),
        'tag': item.get('tag', 'latest'),
        'platform': item.get('platform', ''),
        'registry': item.get('registry', REGISTRY),
        'build_time': item.get('build_time', datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')),
        'run_id': item.get('run_id', 'history-import')
    }
    
    if not record['name']:
        print(f"WARNING: Skipping entry with no name: {item}")
        continue
    
    data['images'].append(record)
    count += 1

# 去重: 同名同namespace同tag同platform只保留最新
seen = {}
for img in data['images']:
    key = (img['name'], img.get('namespace', ''), img['tag'], img.get('platform', ''))
    seen[key] = img  # 后面的覆盖前面的

data['images'] = list(seen.values())
data['last_updated'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')

with open(VERSIONS_FILE, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"Imported {count} records")
print(f"Total unique images: {len(data['images'])}")
PYEOF

echo "Done. Versions file: $VERSIONS_FILE"
