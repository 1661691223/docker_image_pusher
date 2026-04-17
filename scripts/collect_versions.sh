#!/bin/bash
# collect_versions.sh - 收集 Docker 镜像版本信息并更新 versions.json
# 用法: ./collect_versions.sh [--import]
#   无参数: 从 images.txt 读取当前镜像并追加到 versions.json
#   --import: 从 import_data.json 导入历史数据

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$REPO_DIR/data"
VERSIONS_FILE="$DATA_DIR/versions.json"
IMAGES_FILE="$REPO_DIR/images.txt"
IMPORT_FILE="$DATA_DIR/import_data.json"

# 确保 data 目录存在
mkdir -p "$DATA_DIR"

# 初始化 versions.json（如果不存在）
if [ ! -f "$VERSIONS_FILE" ]; then
    echo '{"images":[],"last_updated":""}' > "$VERSIONS_FILE"
fi

# 获取当前时间戳
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# 从镜像行解析信息
# 格式: [--platform=linux/xxx] namespace/image:tag
parse_image_line() {
    local line="$1"
    local platform=""
    local image_full=""
    
    # 提取 platform
    if echo "$line" | grep -q '\-\-platform'; then
        platform=$(echo "$line" | sed -n 's/.*--platform[= ]\([^ ]*\).*/\1/p')
        image_full=$(echo "$line" | awk '{print $NF}')
    else
        image_full="$line"
    fi
    
    # 去掉 @sha256:xxx
    image_full="${image_full%%@*}"
    
    # 解析各部分
    local image_name_tag=$(echo "$image_full" | awk -F'/' '{print $NF}')
    local name_space=$(echo "$image_full" | awk -F'/' '{
        if (NF==3) print $2;
        else if (NF==2) print $1;
        else print ""
    }')
    local registry=$(echo "$image_full" | awk -F'/' '{
        if (NF==3) print $1;
        else print "docker.io"
    }')
    local image_name=$(echo "$image_name_tag" | awk -F':' '{print $1}')
    local tag=$(echo "$image_name_tag" | awk -F':' '{print $2}')
    
    # 默认 tag 为 latest
    [ -z "$tag" ] && tag="latest"
    
    echo "$registry|$name_space|$image_name|$tag|$platform"
}

# 添加一条记录到 versions.json
add_record() {
    local registry="$1"
    local namespace="$2"
    local image_name="$3"
    local tag="$4"
    local platform="$5"
    local build_time="$6"
    local build_run_id="${7:-manual}"
    
    # 使用 jq 更新 JSON
    if command -v jq &>/dev/null; then
        jq --arg reg "$registry" \
           --arg ns "$namespace" \
           --arg name "$image_name" \
           --arg tag "$tag" \
           --arg plat "$platform" \
           --arg time "$build_time" \
           --arg run_id "$build_run_id" \
           '
           # 查找是否已存在相同的镜像
           .images |= (
               map(
                   select(.name == $name and .namespace == $ns) | .
               )
           ) |
           # 添加新版本记录
           .images += [{
               registry: $reg,
               namespace: $ns,
               name: $name,
               tag: $tag,
               platform: $plat,
               build_time: $time,
               run_id: $run_id
           }] |
           # 去重: 同名同tag同platform只保留最新的
           .images = (
               .images | group_by(.name, .namespace, .tag, .platform) |
               map(sort_by(.build_time) | last)
           ) |
           .last_updated = $time
           ' "$VERSIONS_FILE" > "$VERSIONS_FILE.tmp" && mv "$VERSIONS_FILE.tmp" "$VERSIONS_FILE"
    else
        echo "WARNING: jq not found, using python fallback"
        python3 -c "
import json, sys

with open('$VERSIONS_FILE', 'r') as f:
    data = json.load(f)

new_record = {
    'registry': '$registry',
    'namespace': '$namespace',
    'name': '$image_name',
    'tag': '$tag',
    'platform': '$platform',
    'build_time': '$build_time',
    'run_id': '$build_run_id'
}

# 去重: 同名同tag同platform只保留最新的
data['images'] = [img for img in data['images']
    if not (img['name'] == new_record['name'] and
            img['namespace'] == new_record['namespace'] and
            img['tag'] == new_record['tag'] and
            img['platform'] == new_record['platform'])]

data['images'].append(new_record)
data['last_updated'] = '$build_time'

with open('$VERSIONS_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"
    fi
}

# 导入历史数据
import_history() {
    if [ ! -f "$IMPORT_FILE" ]; then
        echo "ERROR: import file not found: $IMPORT_FILE"
        echo "Please create $IMPORT_FILE with your historical data."
        echo "Format: JSON array of image records:"
        echo '[{"name":"nginx","namespace":"","tag":"1.25.3","platform":"","build_time":"2024-01-01T00:00:00Z"}]'
        exit 1
    fi
    
    echo "Importing historical data from $IMPORT_FILE ..."
    
    if command -v jq &>/dev/null; then
        jq -s '.[0] as $existing | .[1] as $import |
              $existing.images = ($existing.images + $import) |
              .[0]' "$VERSIONS_FILE" "$IMPORT_FILE" > "$VERSIONS_FILE.tmp" \
              && mv "$VERSIONS_FILE.tmp" "$VERSIONS_FILE"
    else
        python3 -c "
import json

with open('$VERSIONS_FILE', 'r') as f:
    data = json.load(f)

with open('$IMPORT_FILE', 'r') as f:
    imported = json.load(f)

if isinstance(imported, list):
    data['images'].extend(imported)
elif isinstance(imported, dict) and 'images' in imported:
    data['images'].extend(imported['images'])

# 去重
seen = set()
unique = []
for img in data['images']:
    key = (img.get('name'), img.get('namespace'), img.get('tag'), img.get('platform'))
    if key not in seen:
        seen.add(key)
        unique.append(img)
data['images'] = unique

with open('$VERSIONS_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
"
    fi
    
    echo "Import complete. Total images: $(cat "$VERSIONS_FILE" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["images"]))')"
}

# 主逻辑
if [ "${1:-}" = "--import" ]; then
    import_history
    exit 0
fi

BUILD_TIME=$(get_timestamp)
BUILD_RUN_ID="${GITHUB_RUN_ID:-manual}"

echo "Collecting image versions from $IMAGES_FILE ..."
echo "Build time: $BUILD_TIME"
echo "Run ID: $BUILD_RUN_ID"

# 读取 images.txt 并处理每行
while IFS= read -r line || [ -n "$line" ]; do
    # 忽略空行和注释
    [[ -z "$line" ]] && continue
    echo "$line" | grep -q '^\s*#' && continue
    
    echo "Processing: $line"
    
    parsed=$(parse_image_line "$line")
    IFS='|' read -r registry namespace image_name tag platform <<< "$parsed"
    
    add_record "$registry" "$namespace" "$image_name" "$tag" "$platform" "$BUILD_TIME" "$BUILD_RUN_ID"
    
done < "$IMAGES_FILE"

echo ""
echo "Collection complete. Total images in database: $(cat "$VERSIONS_FILE" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["images"]))')"
echo "Versions file: $VERSIONS_FILE"
