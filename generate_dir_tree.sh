#!/bin/bash

# 目录树生成脚本 - 按层级生成Markdown格式的目录结构
# 支持递归遍历和自定义注释格式

# 主函数
main() {
    # 检查参数
    if [ $# -eq 0 ]; then
        echo "使用方法: $0 <目录路径> [输出文件名]"
        echo "示例: $0 \"E:\\path\\to\\directory\""
        echo "示例: $0 \"E:\\path\\to\\directory\" \"目录结构.md\""
        exit 1
    fi
    
    local target_dir="$1"
    local output_file=""
    
    # 处理输出文件名参数
    if [ $# -ge 2 ]; then
        output_file="$2"
    else
        local dir_name=$(basename "$target_dir" 2>/dev/null || echo "目录结构")
        dir_name=$(echo "$dir_name" | sed 's/[<>:"\\/|?*]//g')
        output_file="${dir_name}_结构_$(date +%Y%m%d_%H%M%S).md"
    fi
    
    # 转换Windows路径（Git Bash/MINGW环境）
    if [[ "$target_dir" =~ ^[A-Za-z]: ]]; then
        # 转换 E:\path 为 /e/path
        local drive_letter=$(echo "$target_dir" | cut -c1 | tr '[:upper:]' '[:lower:]')
        local rest_path=$(echo "$target_dir" | cut -c3- | sed 's/\\/\//g')
        target_dir="/$drive_letter$rest_path"
    fi
    
    # 检查目录是否存在
    if [ ! -d "$target_dir" ]; then
        echo "错误: 目录 '$target_dir' 不存在"
        exit 1
    fi
    
    echo "正在扫描目录: $target_dir"
    echo "输出文件: $output_file"
    echo ""
    
    # 生成目录结构
    generate_tree "$target_dir" "$output_file"
    
    echo "完成! 已保存到: $output_file"
}

# 生成树形结构的函数
generate_tree() {
    local dir="$1"
    local output_file="$2"
    
    # 开始写入Markdown文件
    {
        echo "# $(basename "$dir")/"
        echo ""
        
        # 递归生成树形结构
        generate_tree_recursive "$dir" "" "true"
        
        echo ""
        echo "---"
        echo "*自动生成于 $(date '+%Y-%m-%d %H:%M:%S')*"
    } > "$output_file"
}

# 递归生成树形结构
generate_tree_recursive() {
    local dir="$1"
    local prefix="$2"
    local is_last="$3"
    
    # 获取当前目录下的所有项（排除隐藏文件和特定目录）
    local items=()
    while IFS= read -r item; do
        # 跳过.git和node_modules等目录
        local item_name=$(basename "$item")
        case "$item_name" in
            .git|.DS_Store|.idea|.vscode|__pycache__|node_modules|target|build|dist|out)
                continue
                ;;
        esac
        items+=("$item")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 ! -name ".*" | sort)
    
    if [ ${#items[@]} -eq 0 ]; then
        return
    fi
    
    # 分离目录和文件
    local dirs=()
    local files=()
    for item in "${items[@]}"; do
        if [ -d "$item" ]; then
            dirs+=("$item")
        else
            files+=("$item")
        fi
    done
    
    # 合并目录和文件
    local sorted_items=("${dirs[@]}" "${files[@]}")
    local total=${#sorted_items[@]}
    local count=0
    
    for item in "${sorted_items[@]}"; do
        count=$((count + 1))
        local is_last_item=$([ $count -eq $total ] && echo "true" || echo "false")
        local item_name=$(basename "$item")
        
        # 构建前缀
        if [ -n "$prefix" ]; then
            if [ "$is_last" = "true" ]; then
                local current_prefix="${prefix}    "
                echo -n "${prefix}└── "
            else
                local current_prefix="${prefix}│   "
                echo -n "${prefix}├── "
            fi
        else
            # 根目录的特殊处理
            if [ "$count" -eq 1 ]; then
                echo -n "├── "
            else
                echo -n "│   ├── "
            fi
        fi
        
        # 输出项目
        if [ -d "$item" ]; then
            echo -n "$item_name/"
            # 计算对齐空格，确保#号垂直对齐
            local name_length=${#item_name}
            local padding_length=$((50 - name_length))
            if [ $padding_length -lt 1 ]; then
                padding_length=1
            fi
            printf "%${padding_length}s# $item_name 目录\n" " "
            
            # 递归处理子目录
            generate_tree_recursive "$item" "$current_prefix" "$is_last_item"
        else
            echo -n "$item_name"
            
            # 计算对齐空格，确保#号垂直对齐
            local name_length=${#item_name}
            local padding_length=$((50 - name_length))
            if [ $padding_length -lt 1 ]; then
                padding_length=1
            fi
            
            # 根据文件扩展名添加注释
            local extension="${item_name##*.}"
            case "$extension" in
                java)
                    printf "%${padding_length}s# Java文件\n" " "
                    ;;
                py)
                    printf "%${padding_length}s# Python文件\n" " "
                    ;;
                js|ts)
                    printf "%${padding_length}s# JavaScript/TypeScript文件\n" " "
                    ;;
                html|htm)
                    printf "%${padding_length}s# HTML文件\n" " "
                    ;;
                css)
                    printf "%${padding_length}s# CSS文件\n" " "
                    ;;
                md|txt)
                    printf "%${padding_length}s# 文档文件\n" " "
                    ;;
                json|yml|yaml|xml)
                    printf "%${padding_length}s# 配置文件\n" " "
                    ;;
                jpg|jpeg|png|gif|svg)
                    printf "%${padding_length}s# 图片文件\n" " "
                    ;;
                pdf|doc|docx|xls|xlsx|ppt|pptx)
                    printf "%${padding_length}s# 办公文档\n" " "
                    ;;
                sh|bat|cmd)
                    printf "%${padding_length}s# 脚本文件\n" " "
                    ;;
                *)
                    if [ "$extension" = "$item_name" ]; then
                        printf "%${padding_length}s# 文件\n" " "
                    else
                        printf "%${padding_length}s# $extension 文件\n" " "
                    fi
                    ;;
            esac
        fi
    done
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi