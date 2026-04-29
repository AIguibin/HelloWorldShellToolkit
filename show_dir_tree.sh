#!/bin/bash

# 改进版目录树生成脚本（修复树形符号）

main() {
    if [ $# -eq 0 ]; then
        echo "使用方法: $0 <目录路径> [输出文件名]"
        echo "示例: $0 \"E:\\path\\to\\directory\""
        exit 1
    fi

    local target_dir="$1"
    local output_file=""

    if [ $# -ge 2 ]; then
        output_file="$2"
    else
        local dir_name=$(basename "$target_dir" 2>/dev/null || echo "目录结构")
        dir_name=$(echo "$dir_name" | sed 's/[<>:"/\\|?*]//g')
        output_file="${dir_name}_结构_$(date +%Y%m%d_%H%M%S).md"
    fi

    # 转换 Windows 路径（Git Bash 环境）
    if [[ "$target_dir" =~ ^[A-Za-z]: ]]; then
        local drive_letter=$(echo "$target_dir" | cut -c1 | tr '[:upper:]' '[:lower:]')
        local rest_path=$(echo "$target_dir" | cut -c3- | sed 's/\\/\//g')
        target_dir="/$drive_letter$rest_path"
    fi

    if [ ! -d "$target_dir" ]; then
        echo "错误: 目录 '$target_dir' 不存在"
        exit 1
    fi

    echo "正在扫描目录: $target_dir"
    echo "输出文件: $output_file"
    echo ""

    generate_tree "$target_dir" "$output_file"

    echo "完成! 已保存到: $output_file"
}

generate_tree() {
    local dir="$1"
    local output_file="$2"

    {
        echo "# $(basename "$dir") 目录结构"
        echo ""
        echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "目录路径: \`$dir\`"
        echo ""
        echo "## 目录树"
        echo ""
        echo "\`\`\`"
        echo "$(basename "$dir")/"

        generate_tree_recursive "$dir" "" "true"

        echo "\`\`\`"
        echo ""
        echo "## 统计信息"
        echo ""

        # 统计时排除指定目录
        local dir_count=$(find "$dir" -type d \
            -not -path "*/.git/*" \
            -not -path "*/node_modules/*" \
            -not -path "*/.couser/*" \
            -not -path "*/.trae/*" \
            -not -path "*/.kimi/*" \
            -not -path "*/.vscode/*" \
            2>/dev/null | wc -l)
        local file_count=$(find "$dir" -type f \
            -not -path "*/.git/*" \
            -not -path "*/node_modules/*" \
            -not -path "*/.couser/*" \
            -not -path "*/.trae/*" \
            -not -path "*/.kimi/*" \
            -not -path "*/.vscode/*" \
            2>/dev/null | wc -l)
        dir_count=$((dir_count - 1))

        echo "- 目录数: $dir_count"
        echo "- 文件数: $file_count"
        echo "- 总计: $((dir_count + file_count)) 个项目"
        echo ""
        echo "---"
        echo "*自动生成*"
    } > "$output_file"
}

generate_tree_recursive() {
    local dir="$1"
    local prefix="$2"
    local is_last="$3"

    # 获取当前目录下的项（排除隐藏文件及指定目录）
    local items=()
    while IFS= read -r item; do
        local item_name=$(basename "$item")
        case "$item_name" in
            .git|.DS_Store|.idea|.vscode|__pycache__|node_modules|target|build|dist|out|.couser|.trae|.kimi)
                continue
                ;;
        esac
        items+=("$item")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 ! -name ".*" | sort)

    [ ${#items[@]} -eq 0 ] && return

    # 分离目录和文件（目录优先）
    local dirs=() files=()
    for item in "${items[@]}"; do
        if [ -d "$item" ]; then
            dirs+=("$item")
        else
            files+=("$item")
        fi
    done
    local sorted_items=("${dirs[@]}" "${files[@]}")
    local total=${#sorted_items[@]}
    local count=0

    for item in "${sorted_items[@]}"; do
        count=$((count + 1))
        local is_last_item=$([ $count -eq $total ] && echo "true" || echo "false")
        local item_name=$(basename "$item")

        # 根据当前项是否为最后一个决定符号
        if [ "$is_last_item" = "true" ]; then
            echo -n "${prefix}└── "
            local current_prefix="${prefix}    "
        else
            echo -n "${prefix}├── "
            local current_prefix="${prefix}│   "
        fi

        # 输出项目名（目录加斜杠）
        if [ -d "$item" ]; then
            echo -n "$item_name/"
            echo "  # $item_name 目录"
            generate_tree_recursive "$item" "$current_prefix" "$is_last_item"
        else
            echo -n "$item_name"
            # 根据扩展名添加注释
            local extension="${item_name##*.}"
            case "$extension" in
                java)        echo "  # Java文件" ;;
                py)          echo "  # Python文件" ;;
                js|ts)       echo "  # JavaScript/TypeScript文件" ;;
                html|htm)    echo "  # HTML文件" ;;
                css)         echo "  # CSS文件" ;;
                md|txt)      echo "  # 文档文件" ;;
                json|yml|yaml|xml) echo "  # 配置文件" ;;
                jpg|jpeg|png|gif|svg) echo "  # 图片文件" ;;
                pdf|doc|docx|xls|xlsx|ppt|pptx) echo "  # 办公文档" ;;
                sh|bat|cmd)  echo "  # 脚本文件" ;;
                *) 
                    if [ "$extension" = "$item_name" ]; then
                        echo "  # 文件"
                    else
                        echo "  # $extension 文件"
                    fi
                    ;;
            esac
        fi
    done
}

main "$@"