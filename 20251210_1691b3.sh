#!/bin/bash

# 定义变量
NGINX_HTML_DIR="/home/yw/nginx-1.28.0/html"
LOG_FILE="/home/yw/$(date +%Y%m%d)_check.log"

echo "=== Nginx前端分包检查脚本 ==="
echo "检查时间: $(date)"
echo "检查目录: $NGINX_HTML_DIR"
echo "日志文件: $LOG_FILE"
echo "=================================" | tee "$LOG_FILE"

# 步骤1: 检查_vue文件夹个数并输出到日志
echo "步骤1: 检查_vue文件夹个数" | tee -a "$LOG_FILE"
vue_folders=($(find "$NGINX_HTML_DIR" -maxdepth 1 -type d -name "*_vue"))
vue_folders_count=${#vue_folders[@]}

echo "发现的_vue文件夹数量: $vue_folders_count" | tee -a "$LOG_FILE"

if [ "$vue_folders_count" -eq 0 ]; then
    echo "警告: 未发现任何_vue文件夹!" | tee -a "$LOG_FILE"
    exit 1
else
    echo "发现的_vue文件夹列表:" | tee -a "$LOG_FILE"
    for folder in "${vue_folders[@]}"; do
        echo "  - $(basename "$folder")" | tee -a "$LOG_FILE"
    done
fi

echo "" | tee -a "$LOG_FILE"

# 步骤2: 检查每个_vue文件夹中index.html的创建时间
echo "步骤2: 检查index.html创建时间" | tee -a "$LOG_FILE"
for vue_folder in "${vue_folders[@]}"; do
    index_file="$vue_folder/index.html"
    folder_name=$(basename "$vue_folder")
    
    if [ -f "$index_file" ]; then
        # 获取创建时间（不同系统可能不同，这里使用修改时间作为参考）
        if command -v stat >/dev/null 2>&1; then
            create_time=$(stat -c %y "$index_file" 2>/dev/null || echo "未知时间")
        else
            create_time=$(ls -la "$index_file" | awk '{print $6, $7, $8}')
        fi
        echo "文件夹: $folder_name -> index.html修改时间: $create_time" | tee -a "$LOG_FILE"
    else
        echo "警告: 文件夹 $folder_name 中未找到index.html文件" | tee -a "$LOG_FILE"
    fi
done

echo "" | tee -a "$LOG_FILE"

# 步骤3: 使用curl访问每个_vue文件夹的index.html
echo "步骤3: curl访问检查" | tee -a "$LOG_FILE"
success_count=0
fail_count=0

for vue_folder in "${vue_folders[@]}"; do
    folder_name=$(basename "$vue_folder")
    url_path="http://127.0.0.1/$folder_name/index.html"
    
    echo "测试访问: $url_path" | tee -a "$LOG_FILE"
    
    # 使用curl进行访问测试
    response=$(curl -s -w "HTTP状态码: %{http_code}\n总时间: %{time_total}秒\n大小: %{size_download}字节" -o /dev/null "$url_path" 2>&1)
    curl_exit_code=$?
    
    # 检查curl是否成功执行
    if [ $curl_exit_code -eq 0 ]; then
        echo "$response" | while IFS= read -r line; do
            echo "  $line" | tee -a "$LOG_FILE"
        done
        
        # 提取HTTP状态码进行判断
        http_code=$(echo "$response" | grep "HTTP状态码" | awk '{print $2}')
        if [ "$http_code" -eq 200 ]; then
            echo "  ✅ 访问成功" | tee -a "$LOG_FILE"
            ((success_count++))
        else
            echo "  ⚠️ 访问异常 (HTTP $http_code)" | tee -a "$LOG_FILE"
            ((fail_count++))
        fi
    else
        echo "  ❌ curl执行失败 (退出码: $curl_exit_code)" | tee -a "$LOG_FILE"
        echo "  错误信息: $response" | tee -a "$LOG_FILE"
        ((fail_count++))
    fi
    
    echo "" | tee -a "$LOG_FILE"
done

# 总结报告
echo "=================================" | tee -a "$LOG_FILE"
echo "检查完成总结:" | tee -a "$LOG_FILE"
echo "- 发现_vue文件夹: $vue_folders_count 个" | tee -a "$LOG_FILE"
echo "- 成功访问数量: $success_count 个" | tee -a "$LOG_FILE"
echo "- 失败访问数量: $fail_count 个" | tee -a "$LOG_FILE"

if [ $fail_count -eq 0 ]; then
    echo "✅ 所有检查项均正常" | tee -a "$LOG_FILE"
else
    echo "❌ 存在访问异常的情况，请查看上述详细日志" | tee -a "$LOG_FILE"
fi

echo "详细日志已保存至: $LOG_FILE"