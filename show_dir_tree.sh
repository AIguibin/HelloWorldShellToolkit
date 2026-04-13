#!/bin/bash

# 生成目录树形结构Markdown文档
# 用法: ./generate_tree.sh [目录路径] [输出文件名]

set -e

# 默认参数
TARGET_DIR="${1:-.}"
OUTPUT_FILE="${2:-directory_structure.md}"

# 颜色代码（用于终端输出，不影响markdown文件）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 处理Windows路径格式（将反斜杠转换为正斜杠）
TARGET_DIR=$(echo "$TARGET_DIR" | sed 's/\\/\//g')

echo -e "${GREEN}正在扫描目录: $TARGET_DIR${NC}"
echo -e "${GREEN}输出文件: $OUTPUT_FILE${NC}"

# 检查目录是否存在
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}错误: 目录 '$TARGET_DIR' 不存在${NC}"
    exit 1
fi

# 获取绝对路径
ABS_DIR=$(cd "$TARGET_DIR" && pwd)

# 函数：格式化文件大小
format_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        echo "$(echo "scale=2; $size/1073741824" | bc) GB"
    elif [ $size -ge 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc) MB"
    elif [ $size -ge 1024 ]; then
        echo "$(echo "scale=2; $size/1024" | bc) KB"
    else
        echo "${size} B"
    fi
}

# 函数：获取文件/目录信息
get_item_info() {
    local item="$1"
    local depth="$2"
    
    if [ -L "$item" ]; then
        echo " (符号链接)"
    elif [ -d "$item" ]; then
        local file_count=$(find "$item" -maxdepth 1 -type f 2>/dev/null | wc -l)
        local dir_count=$(find "$item" -maxdepth 1 -type d 2>/dev/null | wc -l)
        echo " [目录: $((dir_count - 1))子目录, ${file_count}文件]"
    elif [ -f "$item" ]; then
        local size=$(stat -f%z "$item" 2>/dev/null || stat -c%s "$item" 2>/dev/null)
        echo " [文件: $(format_size $size)]"
    fi
}

# 函数：递归遍历目录
traverse_directory() {
    local current_dir="$1"
    local prefix="$2"
    local depth="$3"
    
    # 获取目录下的所有条目，按目录优先排序，排除.git目录和.sql文件
    local items=()
    while IFS= read -r item; do
        local item_name=$(basename "$item")
        # 排除.git目录
        if [ "$item_name" = ".git" ] && [ -d "$item" ]; then
            continue
        fi
        # 排除.sql文件
        if [[ "$item_name" == *.sql ]] && [ -f "$item" ]; then
            continue
        fi
        items+=("$item")
    done < <(find "$current_dir" -maxdepth 1 -mindepth 1 \( -type d -o -type f \) | sort | LC_COLLATE=C sort -f)
    
    local total_items=${#items[@]}
    local count=0
    
    for item in "${items[@]}"; do
        count=$((count + 1))
        local item_name=$(basename "$item")
        local is_last=$([ $count -eq $total_items ] && echo "true" || echo "false")
        local new_prefix=""
        
        # 计算对齐空格，确保行号注释垂直对齐
        local name_length=${#item_name}
        local padding_length=$((50 - name_length))
        if [ $padding_length -lt 1 ]; then
            padding_length=1
        fi
        
        # 设置树形结构前缀
        if [ "$depth" -eq 0 ]; then
            if [ "$is_last" = "true" ]; then
                printf "└── %s%${padding_length}s# L%d-%d\n" "$item_name/" " " $((depth + 5)) $((depth + 5)) >> "$OUTPUT_FILE"
                new_prefix="    "
            else
                printf "├── %s%${padding_length}s# L%d-%d\n" "$item_name/" " " $((depth + 5)) $((depth + 5)) >> "$OUTPUT_FILE"
                new_prefix="│   "
            fi
        else
            if [ "$is_last" = "true" ]; then
                printf "%s└── %s%${padding_length}s# L%d-%d\n" "$prefix" "$item_name/" " " $((depth + 5)) $((depth + 5)) >> "$OUTPUT_FILE"
                new_prefix="${prefix}    "
            else
                printf "%s├── %s%${padding_length}s# L%d-%d\n" "$prefix" "$item_name/" " " $((depth + 5)) $((depth + 5)) >> "$OUTPUT_FILE"
                new_prefix="${prefix}│   "
            fi
        fi
        
        # 如果是目录，递归遍历
        if [ -d "$item" ] && [ ! -L "$item" ]; then
            traverse_directory "$item" "$new_prefix" $((depth + 1))
        fi
    done
}

# 生成Markdown文件头
cat > "$OUTPUT_FILE" << EOF
# 目录结构文档

**生成时间:** $(date '+%Y-%m-%d %H:%M:%S')  
**目标目录:** \`$ABS_DIR\`  

## 目录结构

\`\`\`
$(basename "$ABS_DIR")/
EOF

# 开始遍历目录
traverse_directory "$ABS_DIR" "" 0

# 添加文件尾
cat >> "$OUTPUT_FILE" << EOF
\`\`\`

## 统计信息

$(echo "总目录数: $(find "$ABS_DIR" -type d -not -path '*/.*' | wc -l)")
$(echo "总文件数: $(find "$ABS_DIR" -type f -not -name '*.sql' -not -path '*/.*' | wc -l)")
$(echo "总大小: $(du -sh "$ABS_DIR" --exclude='.git' --exclude='*.sql' 2>/dev/null || du -sh "$ABS_DIR" | cut -f1)")

## 文件类型分布

\`\`\`bash
$(find "$ABS_DIR" -type f -not -name '*.sql' -not -path '*/.*' | awk -F . '{print $NF}' | sort | uniq -c | sort -rn | head -20)
\`\`\`

---
*文档由 generate_tree.sh 自动生成*
EOF

echo -e "${GREEN}✓ 文档生成完成: $OUTPUT_FILE${NC}"
echo -e "${YELLOW}已自动添加行号注释 (#Lx-x 格式)${NC}"