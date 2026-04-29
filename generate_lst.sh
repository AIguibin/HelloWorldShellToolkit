#!/bin/bash

# 生成 update-当前年月日时分.lst 文件的脚本
# 扫描当前文件夹中的文件，按照指定格式生成 .lst 文件

# 获取当前时间，格式为年月日时分
current_time=$(date +"%Y%m%d%H%M")
output_file="update-${current_time}.lst"

# 检查当前目录下是否有文件
if [ $(ls -1 | wc -l) -eq 0 ]; then
    echo "当前目录为空，没有找到任何文件。"
    exit 1
fi

# 清空或创建输出文件
> "$output_file"

# 遍历当前目录下的所有文件
for file in *; do
    # 跳过目录和脚本本身
    if [ -d "$file" ] || [ "$file" = "$0" ] || [ "$file" = "$output_file" ]; then
        continue
    fi
    
    # 提取文件名（不带路径）
    filename=$(basename "$file")
    
    # 提取项目名（假设文件名格式为 "项目名_vue.zip"）
    # 这里我们去掉 "_vue.zip" 后缀来获取项目名
    project_name="${filename%_vue.zip}"
    
    # 如果文件名不符合预期格式，使用文件名作为项目名（去掉扩展名）
    if [ "$project_name" = "$filename" ]; then
        project_name="${filename%.*}"
    fi
    
    # 生成并写入符合格式的行
    echo "/home/yw/deploy-web/#${filename}#/home/yw/nginx-1.28.0/html/${project_name}#${filename}#dist#" >> "$output_file"
done

echo "已生成文件: $output_file"
echo "共处理了 $(grep -c "" "$output_file") 个文件"

# 显示生成的文件内容
echo -e "\n生成的文件内容预览:"
cat "$output_file"