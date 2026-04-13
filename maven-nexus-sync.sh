#!/usr/bin/env bash
# ======================================================================
#                         Nexus3 Maven 仓库同步工具
# ======================================================================
# 功能说明：
#   将 Nexus3 仓库中的 Maven 构件从一个仓库同步到另一个仓库
#   支持两种运行模式：
#     - 模式1（无参数）：全量同步源仓库所有构件的最新版本到目标仓库
#     - 模式2（有参数）：同步指定的单个构件
#
# 使用方式：
#   ./maven-nexus-sync.sh                                    # 模式1：全量同步
#   ./maven-nexus-sync.sh <groupId> <artifactId> [version]   # 模式2：单构件同步
#
# 前置要求：
#   1. 安装 Maven 并配置到 PATH（用于部署到 Snapshot 仓库）
#   2. 安装 jq 工具（用于解析 JSON 响应）
#   3. 配置认证信息（二选一）：
#      a) 通过脚本变量直接配置（推荐）：
#         修改下方 USERNAME 和 PASSWORD 变量
#      b) 通过 Maven settings.xml 配置：
#         设置 MAVEN_SETTINGS 指向 settings.xml 文件路径
#
# 技术说明：
#   - 使用 Nexus3 REST API v1 进行构件查询和下载
#   - 使用 Maven deploy:deploy-file 命令进行上传（支持 Snapshot 仓库）
#   - 支持断点续传：已存在的构件会跳过（幂等性）
#
# 作者：AI Assistant
# 版本：2.0
# ======================================================================

# ======================================================================
# Bash 严格模式设置
# ======================================================================
# -e: 命令失败时立即退出脚本（防止错误累积）
# -u: 使用未定义变量时报错（防止拼写错误）
# -o pipefail: 管道中任一命令失败则整个管道失败
set -euo pipefail

# IFS 设置为换行和制表符，防止文件名中的空格导致问题
IFS=$'\n\t'

# ======================================================================
#                        变量净化函数
# ======================================================================
# 功能：移除变量中的回车符和首尾空白，防止 Windows 环境下的编码问题
# 参数：$1 - 需要净化的变量值
# 返回：净化后的字符串
clean_var() {
    local var="$1"
    var="${var//[$'\r']/}"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf "%s" "$var"
}

# ======================================================================
#                        核心配置区域（请根据实际情况修改）
# ======================================================================

# Nexus 服务器地址
# 说明：不要以 / 结尾，脚本会自动处理
# 示例：http://192.15.3.99:10390
# 示例：http://192.15.3.51:20390
NEXUS_URL="${NEXUS_URL:-http://192.15.3.99:10390}"
NEXUS_URL="$(clean_var "$NEXUS_URL")"
# 移除末尾可能存在的斜杠
NEXUS_URL="${NEXUS_URL%/}"  

# Nexus 认证信息
# 说明：用于 REST API 调用和 Maven 部署认证
USERNAME="${NEXUS_USER:-ncms-admin}"
USERNAME="$(clean_var "$USERNAME")"
PASSWORD="${NEXUS_PASS:-P@ss2026}"
PASSWORD="$(clean_var "$PASSWORD")"

# 源仓库和目标仓库配置
# SRC_REPO: 从哪个仓库同步构件
# DST_REPO: 同步到哪个仓库
SRC_REPO="maven-credit-snapshots"
DST_REPO="maven-credit-dev-snapshots"

# Maven 部署配置
# MAVEN_REPO_ID: settings.xml 中配置的 server id
# MAVEN_SETTINGS: Maven settings.xml 文件路径（用于认证）
MAVEN_REPO_ID="nexus-snapshots"
MAVEN_SETTINGS="${MAVEN_SETTINGS:-D:\\Maven\\config\\ncms-admin-dev-settings.xml}"
[[ -n "$MAVEN_SETTINGS" ]] && MAVEN_SETTINGS="$(clean_var "$MAVEN_SETTINGS")"

# ======================================================================
#                        同步文件类型配置
# ======================================================================
# 说明：定义需要同步的文件扩展名
# 使用关联数组，key 为扩展名，value 为 1（表示需要同步）
# 校验和文件（.md5, .sha1 等）会自动跳过
declare -A SYNC_EXTS=(
    ["pom"]=1       # Maven POM 文件（必需）
    ["jar"]=1       # Java 归档文件
    ["war"]=1       # Web 应用归档文件
    ["ear"]=1       # 企业应用归档文件
    ["zip"]=1       # ZIP 压缩包
    ["tar.gz"]=1    # Gzip 压缩的 Tar 包
    ["tar.bz2"]=1   # Bzip2 压缩的 Tar 包
    ["aar"]=1       # Android 归档文件
    ["module"]=1    # Java 模块文件
)

# ======================================================================
#                        临时目录配置
# ======================================================================
# 说明：用于存放下载的构件文件
# 使用 $$ 获取当前进程 PID，避免多实例冲突
# 脚本退出时自动清理（通过 trap 命令）
TMP_DIR_BASE="/e/Temp/nexus-sync-$$"
mkdir -p "$TMP_DIR_BASE"
# 注册退出清理函数：脚本正常退出或异常退出时都会执行
trap 'rm -rf "$TMP_DIR_BASE"' EXIT

# ======================================================================
#                        Maven 环境检查函数
# ======================================================================
# 功能：检查 Maven 是否正确安装和配置
# 参数：无
# 返回：无（检查失败时直接退出脚本）
check_maven() {
    # 检查 mvn 命令是否存在
    if ! command -v mvn &> /dev/null; then
        echo "错误: 未找到 Maven 命令，请确保 Maven 已安装并配置到 PATH" >&2
        echo "提示: 可通过 'mvn -version' 验证 Maven 安装" >&2
        exit 1
    fi
    
    # 打印 Maven 版本信息
    echo "[DEBUG] Maven 版本: $(mvn -version 2>&1 | head -1)"
    
    # 如果指定了 settings.xml，检查文件是否存在
    if [[ -n "$MAVEN_SETTINGS" ]]; then
        if [[ ! -f "$MAVEN_SETTINGS" ]]; then
            echo "错误: Maven settings 文件不存在: $MAVEN_SETTINGS" >&2
            exit 1
        fi
        echo "[DEBUG] Maven settings: $MAVEN_SETTINGS"
    fi
}

# ======================================================================
#                        HTTP 请求封装函数
# ======================================================================

# curl_auth: 带 Basic 认证的 HTTP 请求
# 功能：封装 curl 命令，自动添加 Nexus 认证信息
# 参数：curl 的所有参数
# 返回：HTTP 响应内容
# 注意：调试日志输出到 stderr，避免污染 stdout 被变量捕获
curl_auth() {
    local url="$1"
    shift
    echo "[DEBUG] curl_auth 调用: $url" >&2
    curl -sSL --user "$USERNAME:$PASSWORD" "$url" "$@"
}

# check_http_status: 检查 HTTP 响应状态码
# 功能：判断 HTTP 状态码是否表示成功
# 参数：
#   $1 - HTTP 响应内容
#   $2 - HTTP 状态码
# 返回：0 表示成功，1 表示失败
check_http_status() {
    local resp="$1"
    local code="$2"
    echo "[DEBUG] check_http_status: HTTP状态码=$code"
    
    # 状态码 >= 400 表示请求失败
    if [[ "$code" -ge 400 ]]; then
        echo "HTTP $code: ${resp:0:200}" >&2
        echo "[DEBUG] HTTP错误响应内容: ${resp:0:5000}" >&2
        return 1
    fi
    return 0
}

# ======================================================================
#                        构件存在性检查函数
# ======================================================================
# 功能：检查目标仓库中是否已存在指定的构件版本
# 参数：
#   $1 - groupId
#   $2 - artifactId
#   $3 - version
# 返回：0 表示存在，1 表示不存在
# 用途：实现幂等性，避免重复同步
component_exists() {
    local g="$1"
    local a="$2"
    local v="$3"
    
    echo "[DEBUG] component_exists 开始检查: $g:$a:$v"
    
    # 构建 Nexus Search API URL
    # 说明：使用 Search API 查询指定 GAV 坐标的构件
    local url
    printf -v url "%s/service/rest/v1/search?repository=%s&group=%s&name=%s&version=%s" "$NEXUS_URL" "$DST_REPO" "$g" "$a" "$v"
    
    # 发送请求并获取响应
    local resp
    resp=$(curl_auth "$url")
    
    echo "[DEBUG] component_exists URL: $url"
    echo "[DEBUG] component_exists resp (前5000字符): ${resp:0:5000}"
    
    # 解析响应中的 items 数量
    # 说明：如果 items 数量 > 0，表示构件已存在
    local total
    echo "[DEBUG] component_exists 执行 jq: .items | length"
    total=$(echo "$resp" | jq -r '.items | length')
    echo "[DEBUG] component_exists 查询结果数量: $total"
    
    # 返回检查结果：total > 0 表示存在
    [[ "$total" -gt 0 ]]
}

# ======================================================================
#                        构件上传函数（核心）
# ======================================================================
# 功能：使用 Maven deploy:deploy-file 命令上传构件到目标仓库
# 参数：
#   $1 - groupId
#   $2 - artifactId
#   $3 - version
#   $4... - 资产文件列表，格式: "extension|classifier|filepath"
# 返回：0 表示成功，1 表示失败
#
# 为什么使用 Maven 而不是 REST API？
#   - Nexus3 REST API 不支持直接上传到 Snapshot 仓库
#   - Snapshot 版本需要 Maven 客户端生成时间戳版本号
#   - Maven deploy:deploy-file 可以正确处理 Snapshot 部署逻辑
upload_component() {
    local g="$1"      # groupId
    local a="$2"      # artifactId
    local v="$3"      # version
    shift 3
    local assets=("$@")  # 资产文件数组

    echo "[DEBUG] upload_component 开始上传: $g:$a:$v"
    echo "[DEBUG] upload_component 资产数量: ${#assets[@]}"

    # ------------------------------------------------------------------
    # 构建目标仓库 URL
    # ------------------------------------------------------------------
    # 认证方式选择：
    #   1. 如果指定了 MAVEN_SETTINGS，使用 settings.xml 中的认证配置
    #   2. 否则，将认证信息嵌入 URL（格式：http://user:pass@host/path）
    local repo_url
    if [[ -n "$MAVEN_SETTINGS" ]]; then
        # 方式1：使用 settings.xml 认证
        repo_url="${NEXUS_URL}/repository/${DST_REPO}/"
        echo "[DEBUG] 使用 settings.xml 认证，目标仓库URL: $repo_url"
    else
        # 方式2：URL 内嵌认证
        # 说明：需要对用户名和密码进行 URL 编码，防止特殊字符导致问题
        local encoded_password
        encoded_password=$(printf '%s' "$PASSWORD" | jq -sRr @uri)
        local encoded_user
        encoded_user=$(printf '%s' "$USERNAME" | jq -sRr @uri)
        
        # 解析 URL 协议和主机部分
        local protocol host_port
        protocol="${NEXUS_URL%%://*}"      # 提取协议（http 或 https）
        host_port="${NEXUS_URL#*://}"       # 提取主机:端口
        
        # 构建带认证的 URL
        repo_url="${protocol}://${encoded_user}:${encoded_password}@${host_port}/repository/${DST_REPO}/"
        echo "[DEBUG] 使用 URL 内嵌认证，目标仓库URL: ${protocol}://***:***@${host_port}/repository/${DST_REPO}/"
    fi

    # ------------------------------------------------------------------
    # 分类资产文件
    # ------------------------------------------------------------------
    # Maven deploy:deploy-file 需要区分不同类型的文件：
    #   - POM 文件：必需，包含构件元数据
    #   - 主文件：jar/war/ear 等，无 classifier
    #   - sources：源码包，classifier=sources
    #   - javadoc：文档包，classifier=javadoc
    #   - 其他：附加文件，需要单独上传
    local pom_file=""        # POM 文件路径
    local main_file=""       # 主文件路径
    local main_ext=""        # 主文件扩展名
    local sources_file=""    # 源码包路径
    local javadoc_file=""    # 文档包路径
    local other_files=()     # 其他文件列表

    # 遍历所有资产文件进行分类
    for asset in "${assets[@]}"; do
        # 解析资产信息：格式为 "extension|classifier|filepath"
        IFS='|' read -r ext classifier filepath <<< "$asset"
        echo "[DEBUG] upload_component 资产: ext=$ext, classifier=$classifier, filepath=$filepath"

        # 根据扩展名和分类器进行分类
        if [[ "$ext" == "pom" ]]; then
            # POM 文件
            pom_file="$filepath"
            echo "[DEBUG] 识别为 POM 文件: $pom_file"
        elif [[ -z "$classifier" ]]; then
            # 无分类器的文件，第一个作为主文件
            if [[ -z "$main_file" ]]; then
                main_file="$filepath"
                main_ext="$ext"
                echo "[DEBUG] 识别为主文件: $main_file (ext=$main_ext)"
            else
                other_files+=("$filepath")
                echo "[DEBUG] 添加到其他文件列表: $filepath"
            fi
        elif [[ "$classifier" == "sources" ]]; then
            # 源码包
            sources_file="$filepath"
            echo "[DEBUG] 识别为源码文件: $sources_file"
        elif [[ "$classifier" == "javadoc" ]]; then
            # 文档包
            javadoc_file="$filepath"
            echo "[DEBUG] 识别为文档文件: $javadoc_file"
        else
            # 其他分类器文件
            other_files+=("$filepath")
            echo "[DEBUG] 添加到其他文件列表: $filepath"
        fi
    done

    # ------------------------------------------------------------------
    # 验证必需文件
    # ------------------------------------------------------------------
    # POM 文件和主文件是必需的，缺少则无法上传
    if [[ -z "$pom_file" ]]; then
        echo "  警告: 未找到 POM 文件，跳过上传" >&2
        echo "[DEBUG] upload_component 缺少 POM 文件"
        return 1
    fi

    if [[ -z "$main_file" ]]; then
        echo "  警告: 未找到主文件(jar/war等)，跳过上传" >&2
        echo "[DEBUG] upload_component 缺少主文件"
        return 1
    fi

    # ------------------------------------------------------------------
    # 构建 Maven deploy:deploy-file 命令
    # ------------------------------------------------------------------
    echo "  上传: $g:$a:$v"
    echo "[DEBUG] upload_component 执行 Maven deploy:deploy-file..."

    # 构建命令参数
    local mvn_args=()
    
    # 如果指定了 settings.xml，添加 -s 参数
    if [[ -n "$MAVEN_SETTINGS" ]]; then
        mvn_args+=("-s" "$MAVEN_SETTINGS")
    fi
    
    # 添加基本参数
    mvn_args+=(
        deploy:deploy-file
        -DgroupId="$g"           # 组织 ID
        -DartifactId="$a"        # 构件 ID
        -Dversion="$v"           # 版本号
        -Dpackaging="$main_ext"  # 打包类型（jar/war/ear 等）
        -Dfile="$main_file"      # 主文件路径
        -DpomFile="$pom_file"    # POM 文件路径
        -Durl="$repo_url"        # 目标仓库 URL
    )
    
    # 如果使用 settings.xml，添加 repositoryId 参数
    # 说明：repositoryId 对应 settings.xml 中 server 的 id
    if [[ -n "$MAVEN_SETTINGS" ]]; then
        mvn_args+=(-DrepositoryId="$MAVEN_REPO_ID")
    fi

    # 添加源码包参数（如果存在）
    if [[ -n "$sources_file" ]]; then
        mvn_args+=(-Dsources="$sources_file")
        echo "[DEBUG] 添加源码文件参数: $sources_file"
    fi

    # 添加文档包参数（如果存在）
    if [[ -n "$javadoc_file" ]]; then
        mvn_args+=(-Djavadoc="$javadoc_file")
        echo "[DEBUG] 添加文档文件参数: $javadoc_file"
    fi

    # ------------------------------------------------------------------
    # 执行 Maven 部署命令
    # ------------------------------------------------------------------
    echo "[DEBUG] Maven 命令: mvn ${mvn_args[*]}"

    local mvn_output
    local mvn_exit_code
    
    # 执行命令并捕获输出
    # 说明：|| mvn_exit_code=$? 用于捕获非零退出码
    mvn_output=$(mvn "${mvn_args[@]}" 2>&1) || mvn_exit_code=$?
    
    # 打印 Maven 输出（缩进显示）
    echo "[DEBUG] Maven 输出:"
    echo "$mvn_output" | while IFS= read -r line; do
        echo "    $line"
    done

    # 检查执行结果
    if [[ ${mvn_exit_code:-0} -ne 0 ]]; then
        echo "  Maven 部署失败 (exit code: ${mvn_exit_code})" >&2
        return 1
    fi

    # ------------------------------------------------------------------
    # 上传附加文件（如果有）
    # ------------------------------------------------------------------
    # 说明：附加文件（如可执行 jar、测试 jar 等）需要单独上传
    # 因为 Maven deploy:deploy-file 一次只能上传一个 classifier 的文件
    for other_file in "${other_files[@]}"; do
        local filename
        filename=$(basename "$other_file")
        
        # 从文件名中提取 classifier
        # 文件名格式：artifactId-version-classifier.extension
        local classifier=""
        if [[ "$filename" =~ ${a}-${v}-([^.]+)\. ]]; then
            classifier="${BASH_REMATCH[1]}"
        fi

        if [[ -n "$classifier" ]]; then
            echo "[DEBUG] 上传附加文件: $filename (classifier=$classifier)"
            
            # 提取扩展名
            local ext=""
            if [[ "$filename" =~ \.([^.]+)$ ]]; then
                ext="${BASH_REMATCH[1]}"
            fi
            
            # 构建附加文件上传命令
            local attach_args=()
            if [[ -n "$MAVEN_SETTINGS" ]]; then
                attach_args+=("-s" "$MAVEN_SETTINGS")
            fi
            attach_args+=(
                deploy:deploy-file
                -DgroupId="$g"
                -DartifactId="$a"
                -Dversion="$v"
                -Dpackaging="$ext"
                -Dfile="$other_file"
                -Dclassifier="$classifier"
                -DgeneratePom=false    # 不生成 POM，使用已有的
                -Durl="$repo_url"
            )
            if [[ -n "$MAVEN_SETTINGS" ]]; then
                attach_args+=(-DrepositoryId="$MAVEN_REPO_ID")
            fi
            
            echo "[DEBUG] Maven 附加文件命令: mvn ${attach_args[*]}"
            
            local attach_output
            local attach_exit_code
            attach_output=$(mvn "${attach_args[@]}" 2>&1) || attach_exit_code=$?
            
            if [[ ${attach_exit_code:-0} -ne 0 ]]; then
                echo "  附加文件上传失败: $filename" >&2
            else
                echo "  附加文件上传成功: $filename"
            fi
        fi
    done

    echo "[DEBUG] upload_component 上传成功"
    return 0
}

# ======================================================================
#                        模式1：全量同步函数
# ======================================================================
# 功能：同步源仓库中所有构件的最新版本到目标仓库
# 参数：无
# 返回：0 表示成功，1 表示有失败
# 流程：
#   1. 获取源仓库所有构件坐标（groupId:artifactId）
#   2. 对每个构件查询最新版本
#   3. 检查目标仓库是否已存在（幂等性）
#   4. 下载构件文件
#   5. 上传到目标仓库
sync_all_latest() {
    echo "[DEBUG] sync_all_latest 开始执行"
    echo "================================================================="
    echo "模式1：全量同步 - 将 ${SRC_REPO} 所有构件的最新版本同步至 ${DST_REPO}"
    echo "================================================================="

    # 创建模式专用的临时目录
    local TMP_DIR="${TMP_DIR_BASE}/all"
    mkdir -p "$TMP_DIR"
    echo "[DEBUG] sync_all_latest 临时目录: $TMP_DIR"

    # ------------------------------------------------------------------
    # 步骤1：获取所有构件坐标（GA 列表）
    # ------------------------------------------------------------------
    echo "【1】获取源仓库 ${SRC_REPO} 的所有构件坐标 (group:artifact) ..."
    
    # GA 列表文件：存储所有 groupId|artifactId 对
    local ga_list_file="${TMP_DIR}/ga_list.txt"
    echo "[DEBUG] GA列表文件: $ga_list_file"
    
    # Nexus Search API 分页参数
    local continuation_token=""
    local page=1

    # 分页获取所有构件
    # 说明：Nexus API 使用 continuationToken 实现分页
    while : ; do
        echo "  获取第 $page 页..."
        
        # 构建 API URL
        local url
        printf -v url "%s/service/rest/v1/search?repository=%s&sort=group&direction=asc" "$NEXUS_URL" "$SRC_REPO"
        
        # 如果有分页 token，添加到 URL
        [[ -n "$continuation_token" ]] && url="${url}&continuationToken=${continuation_token}"
        echo "[DEBUG] 分页URL: $url"

        # 发送请求
        local resp
        resp=$(curl_auth "$url") || {
            echo "    请求失败，退出" >&2
            return 1
        }
        
        echo "[DEBUG] sync_all_latest 获取GA列表 URL: $url"
        echo "[DEBUG] sync_all_latest resp (前5000字符): ${resp:0:5000}"
        
        # 提取 GA 坐标并写入文件
        # 格式：groupId|artifactId
        echo "[DEBUG] 执行 jq: .items[] | \"\\(.group)|\\(.name)\""
        echo "$resp" | jq -r '.items[] | "\(.group)|\(.name)"' >> "$ga_list_file"
        
        # 获取下一页的 token
        echo "[DEBUG] 执行 jq: .continuationToken // empty"
        continuation_token=$(echo "$resp" | jq -r '.continuationToken // empty')
        echo "[DEBUG] continuation_token: $continuation_token"
        
        # 如果没有 token，表示已获取所有数据
        [[ -z "$continuation_token" ]] && break
        
        ((page++))
    done

    # 去重并排序 GA 列表
    sort -u "$ga_list_file" | tr -d '\r' > "${ga_list_file}.tmp"
    mv "${ga_list_file}.tmp" "$ga_list_file"
	
    # 统计构件数量
    local total_ga
    total_ga=$(wc -l < "$ga_list_file")
    echo "[DEBUG] GA列表文件排序完成，总行数: $total_ga"
    echo "  共发现 $total_ga 个独立构件"

    # ------------------------------------------------------------------
    # 步骤2：依次处理每个构件
    # ------------------------------------------------------------------
    echo "【2】依次查询每个构件的最新版本并同步..."
    echo "[DEBUG] 开始遍历 GA 列表"
    
    local counter=0
    local failed_ga=()  # 失败的构件列表

    # 读取 GA 列表并逐个处理
    while IFS='|' read -r group artifact; do
		# 清理变量中可能存在的回车符（防止 CRLF 换行符问题）
		group="${group//[$'\r'/]}"
		artifact="${artifact//[$'\r'/]}"
		
        # 使用前置递增避免 set -e 导致的退出问题
        ((++counter))
        echo "[DEBUG] ========== 处理第 $counter/$total_ga 个构件 =========="
        echo "[$counter/$total_ga] 处理: $group:$artifact"

        # --------------------------------------------------------------
        # 查询最新版本 
        # --------------------------------------------------------------
        # 说明：使用 sort=version&direction=desc&size=1  只取第一个（即最新版本）获取按版本降序排列的结果size=1
        local search_url
		printf -v search_url "%s/service/rest/v1/search?repository=%s&group=%s&name=%s&sort=version&direction=desc" "$NEXUS_URL" "$SRC_REPO" "$group" "$artifact"
        echo "[DEBUG] 查询最新版本 URL: $search_url"
        
        local resp
        resp=$(curl_auth "$search_url")
        echo "[DEBUG] 查询最新版本 resp (前5000字符): ${resp:0:5000}"
        
        # 检查是否找到构件
        local items
        echo "[DEBUG] 执行 jq: .items | length"
        items=$(echo "$resp" | jq -r '.items | length')
        echo "[DEBUG] items 数量: $items"
        
        if [[ "$items" -eq 0 ]]; then
            echo "  未找到组件，跳过" >&2
            echo "[DEBUG] 跳过此构件，继续下一个"
            continue
        fi

        # 提取版本号
        local version
        echo "[DEBUG] 执行 jq: .items[0].version"
        version=$(echo "$resp" | jq -r '.items[0].version')
        echo "[DEBUG] 解析版本: $version"
        
        # 提取资产列表
        # 说明：assets 包含该构件的所有文件（jar、pom、sources 等）
        local assets_json
        echo "[DEBUG] 执行 jq: .items[0].assets[]"
        assets_json=$(echo "$resp" | jq -c '.items[0].assets[]')
        echo "[DEBUG] assets_json 行数: $(echo "$assets_json" | wc -l)"

        # --------------------------------------------------------------
        # 幂等检查：目标仓库是否已存在
        # --------------------------------------------------------------
        echo "[DEBUG] 开始幂等检查..."
        if component_exists "$group" "$artifact" "$version"; then
            echo "  目标仓库已存在 $version，跳过"
            echo "[DEBUG] 幂等检查通过，跳过同步"
            continue
        fi
        echo "[DEBUG] 幂等检查通过，目标仓库不存在，继续同步"

        # --------------------------------------------------------------
        # 下载构件文件
        # --------------------------------------------------------------
        echo "[DEBUG] 开始下载主文件..."
        
        local asset_files=()
        local asset_counter=0
        
        # 遍历所有资产文件
        while IFS= read -r asset; do
            ((++asset_counter))
            echo "[DEBUG] ----- 处理第 $asset_counter 个 asset -----"
            echo "[DEBUG] 处理 asset: ${asset:0:200}"
            
            local download_url path filename ext classifier
            
            # 提取下载 URL
            echo "[DEBUG] 执行 jq: .downloadUrl"
            download_url=$(echo "$asset" | jq -r '.downloadUrl')
            echo "[DEBUG] download_url: $download_url"
            
            # 提取文件路径
            echo "[DEBUG] 执行 jq: .path"
            path=$(echo "$asset" | jq -r '.path')
            echo "[DEBUG] path: $path"
            
            # 提取文件名
            filename=$(basename "$path")
            echo "[DEBUG] filename: $filename"

            # 跳过校验和文件
            # 说明：校验和文件会在上传时自动生成，无需同步
            if [[ "$filename" =~ \.(md5|sha1|sha256|sha512|asc)$ ]]; then
                echo "[DEBUG] 跳过校验和文件: $filename"
                continue
            fi

            # 提取扩展名
            # 说明：支持复合扩展名如 tar.gz、tar.bz2
            ext=""
            if [[ "$filename" =~ \.([^.]+(\.(gz|bz2|zst))?)$ ]]; then
                ext="${BASH_REMATCH[1]}"
            fi
            echo "[DEBUG] 提取扩展名: $ext"

            # 检查是否为需要同步的文件类型
            if [[ -z "$ext" ]] || [[ -z "${SYNC_EXTS[$ext]:-}" ]]; then
                echo "[DEBUG] 跳过非目标扩展名: $ext"
                continue
            fi
            echo "[DEBUG] 扩展名 $ext 在同步列表中，继续处理"

            # 提取分类器
            # 说明：从文件名中提取，格式为 artifactId-version-classifier.extension
            classifier=""
            if [[ "$filename" =~ ${artifact}-${version}-([^.]+)\. ]]; then
                classifier="${BASH_REMATCH[1]}"
            fi
            echo "[DEBUG] 提取分类器: ${classifier:-无}"

            # 下载文件
            local local_file="${TMP_DIR}/${filename}"
            echo "[DEBUG] 本地文件路径: $local_file"
            echo "    下载: $filename"
            
            curl_auth -o "$local_file" "$download_url" || {
                echo "      下载失败" >&2
                echo "[DEBUG] 下载失败，添加到失败列表"
                failed_ga+=("$group:$artifact:$version")
                continue 2  # 跳出两层循环，处理下一个构件
            }
            echo "[DEBUG] 下载成功: $local_file"

            # 添加到资产列表
            asset_files+=("${ext}|${classifier}|${local_file}")
            echo "[DEBUG] 添加到 asset_files: ext=$ext, classifier=$classifier"
        done <<< "$assets_json"
        
        echo "[DEBUG] 共处理 $asset_counter 个 asset，有效文件 ${#asset_files[@]} 个"

        # 检查是否有有效文件
        if [[ ${#asset_files[@]} -eq 0 ]]; then
            echo "[DEBUG] 无有效主文件"
            echo "  无有效主文件，跳过"
            continue
        fi

        # --------------------------------------------------------------
        # 上传到目标仓库
        # --------------------------------------------------------------
        echo "[DEBUG] 开始上传..."
        if upload_component "$group" "$artifact" "$version" "${asset_files[@]}"; then
            echo "[DEBUG] upload_component 返回成功"
            echo "  完成"
        else
            echo "[DEBUG] upload_component 返回失败"
            echo "  上传失败" >&2
            failed_ga+=("$group:$artifact:$version")
        fi
        echo "[DEBUG] ========== 构件处理完成 =========="

    done < "$ga_list_file"

    # ------------------------------------------------------------------
    # 汇总结果
    # ------------------------------------------------------------------
    echo "[DEBUG] sync_all_latest 处理完成，开始汇总"
    echo "[DEBUG] 失败构件数量: ${#failed_ga[@]}"
    
    if [[ ${#failed_ga[@]} -eq 0 ]]; then
        echo "【完成】所有构件同步成功！"
    else
        echo "【警告】以下构件同步失败："
        printf '%s\n' "${failed_ga[@]}"
        return 1
    fi
}

# ======================================================================
#                        模式2：单构件同步函数
# ======================================================================
# 功能：同步指定的单个构件到目标仓库
# 参数：
#   $1 - groupId（必需）
#   $2 - artifactId（必需）
#   $3 - version（可选，不指定则同步最新版本）
# 返回：0 表示成功，1 表示失败
sync_single() {
    echo "[DEBUG] sync_single 开始执行"
    
    # 参数验证
    if [[ $# -lt 2 ]]; then
        echo "错误: 必须提供 groupId 和 artifactId" >&2
        echo "用法: $0 <groupId> <artifactId> [version]" >&2
        return 1
    fi

    local GROUP="$1"
    local ARTIFACT="$2"
    local VERSION="${3:-}"  # 版本可选

    echo "[DEBUG] 输入参数: GROUP=$GROUP, ARTIFACT=$ARTIFACT, VERSION=${VERSION:-未指定}"
    echo "================================================================="
    echo "模式2：单构件同步 - ${GROUP}:${ARTIFACT}${VERSION:+:$VERSION}"
    echo "================================================================="

    # 创建模式专用的临时目录
    local TMP_DIR="${TMP_DIR_BASE}/single"
    mkdir -p "$TMP_DIR"
    echo "[DEBUG] sync_single 临时目录: $TMP_DIR"

    # ------------------------------------------------------------------
    # 步骤1：确定要同步的版本
    # ------------------------------------------------------------------
    if [[ -z "$VERSION" ]]; then
        # 未指定版本，查询最新版本
        echo "[DEBUG] 未指定版本，需要查询最新版本"
        echo "【1】未指定版本，正在查询 $GROUP:$ARTIFACT 的最新版本..."
        
        local search_url
        printf -v search_url "%s/service/rest/v1/search?repository=%s&group=%s&name=%s&sort=version&direction=desc" "$NEXUS_URL" "$SRC_REPO" "$GROUP" "$ARTIFACT"
        echo "[DEBUG] 查询URL: $search_url"
        
        local resp
        resp=$(curl_auth "$search_url") || { echo "查询失败" >&2; return 1; }
        echo "[DEBUG] sync_single 查询最新版本 URL: $search_url"
        echo "[DEBUG] sync_single resp (前5000字符): ${resp:0:5000}"

        # 检查是否找到构件
        local items_count
        echo "[DEBUG] 执行 jq: .items | length"
        items_count=$(echo "$resp" | jq -r '.items | length')
        echo "[DEBUG] items_count: $items_count"
        
        if [[ "$items_count" -eq 0 ]]; then
            echo "错误: 在仓库 $SRC_REPO 中未找到构件 $GROUP:$ARTIFACT" >&2
            return 1
        fi

        # 提取版本号
        echo "[DEBUG] 执行 jq: .items[0].version"
        VERSION=$(echo "$resp" | jq -r '.items[0].version')
        echo "[DEBUG] 解析版本: $VERSION"
        echo "   最新版本: $VERSION"
    else
        # 已指定版本，验证是否存在
        echo "[DEBUG] 指定版本: $VERSION"
        echo "【1】指定版本: $VERSION"
        
        local check_url
        printf -v check_url "%s/service/rest/v1/search?repository=%s&group=%s&name=%s&version=%s" "$NEXUS_URL" "$SRC_REPO" "$GROUP" "$ARTIFACT" "$VERSION"
        echo "[DEBUG] 验证URL: $check_url"
        
        local resp
        resp=$(curl_auth "$check_url")
        echo "[DEBUG] 验证指定版本 URL: $check_url"
        echo "[DEBUG] 验证指定版本 resp (前5000字符): ${resp:0:5000}"
        
        local items_count
        echo "[DEBUG] 执行 jq: .items | length"
        items_count=$(echo "$resp" | jq -r '.items | length')
        echo "[DEBUG] items_count: $items_count"
        
        if [[ "$items_count" -eq 0 ]]; then
            echo "错误: 在仓库 $SRC_REPO 中未找到构件 $GROUP:$ARTIFACT:$VERSION" >&2
            return 1
        fi
        echo "[DEBUG] 版本验证通过"
    fi

    # ------------------------------------------------------------------
    # 步骤2：幂等检查
    # ------------------------------------------------------------------
    echo "[DEBUG] 开始幂等检查..."
    echo "【2】检查目标仓库 $DST_REPO 是否已存在 $VERSION ..."
    
    if component_exists "$GROUP" "$ARTIFACT" "$VERSION"; then
        echo "[DEBUG] 目标仓库已存在，无需同步"
        echo "   目标仓库已存在该版本，无需同步。"
        return 0
    fi
    echo "[DEBUG] 目标仓库不存在，继续同步"

    # ------------------------------------------------------------------
    # 步骤3：获取资产列表
    # ------------------------------------------------------------------
    echo "[DEBUG] 开始获取资产列表..."
    echo "【3】获取构件资产列表..."
    
    local assets_json
    local assets_url
    printf -v assets_url "%s/service/rest/v1/search?repository=%s&group=%s&name=%s&version=%s" "$NEXUS_URL" "$SRC_REPO" "$GROUP" "$ARTIFACT" "$VERSION"
    echo "[DEBUG] 获取资产列表 URL: $assets_url"
    
    local assets_resp
    assets_resp=$(curl_auth "$assets_url")
    echo "[DEBUG] 获取资产列表 resp (前5000字符): ${assets_resp:0:5000}"
    
    echo "[DEBUG] 执行 jq: .items[0].assets[]"
    assets_json=$(echo "$assets_resp" | jq -c '.items[0].assets[]')
    echo "[DEBUG] assets_json 行数: $(echo "$assets_json" | wc -l)"

    if [[ -z "$assets_json" ]]; then
        echo "[DEBUG] assets_json 为空"
        echo "错误: 未找到任何资产文件" >&2
        return 1
    fi

    # ------------------------------------------------------------------
    # 步骤4：下载构件文件
    # ------------------------------------------------------------------
    echo "[DEBUG] 开始下载主文件..."
    echo "【4】下载主文件..."
    
    local asset_files=()
    local asset_counter=0
    
    while IFS= read -r asset; do
        ((++asset_counter))
        echo "[DEBUG] ----- sync_single 处理第 $asset_counter 个 asset -----"
        echo "[DEBUG] sync_single 处理 asset: ${asset:0:200}"
        
        local download_url path filename ext classifier
        
        echo "[DEBUG] 执行 jq: .downloadUrl"
        download_url=$(echo "$asset" | jq -r '.downloadUrl')
        echo "[DEBUG] sync_single download_url: $download_url"
        
        echo "[DEBUG] 执行 jq: .path"
        path=$(echo "$asset" | jq -r '.path')
        echo "[DEBUG] path: $path"
        
        filename=$(basename "$path")
        echo "[DEBUG] filename: $filename"

        # 跳过校验和文件
        if [[ "$filename" =~ \.(md5|sha1|sha256|sha512|asc)$ ]]; then
            echo "[DEBUG] 跳过校验和文件: $filename"
            continue
        fi

        # 提取扩展名
        ext=""
        if [[ "$filename" =~ \.([^.]+(\.(gz|bz2|zst))?)$ ]]; then
            ext="${BASH_REMATCH[1]}"
        fi
        echo "[DEBUG] 提取扩展名: $ext"

        # 检查文件类型
        if [[ -z "$ext" ]] || [[ -z "${SYNC_EXTS[$ext]:-}" ]]; then
            echo "[DEBUG] 跳过非目标扩展名: $ext"
            continue
        fi
        echo "[DEBUG] 扩展名 $ext 在同步列表中，继续处理"

        # 提取分类器
        classifier=""
        if [[ "$filename" =~ ${ARTIFACT}-${VERSION}-([^.]+)\. ]]; then
            classifier="${BASH_REMATCH[1]}"
        fi
        echo "[DEBUG] 提取分类器: ${classifier:-无}"

        # 下载文件
        local local_file="${TMP_DIR}/${filename}"
        echo "[DEBUG] 本地文件路径: $local_file"
        echo "  下载: $filename"
        
        curl_auth -o "$local_file" "$download_url" || {
            echo "    下载失败" >&2
            echo "[DEBUG] 下载失败"
            return 1
        }
        echo "[DEBUG] 下载成功: $local_file"

        asset_files+=("${ext}|${classifier}|${local_file}")
        echo "[DEBUG] 添加到 asset_files: ext=$ext, classifier=$classifier"
    done <<< "$assets_json"
    
    echo "[DEBUG] 共处理 $asset_counter 个 asset，有效文件 ${#asset_files[@]} 个"

    if [[ ${#asset_files[@]} -eq 0 ]]; then
        echo "[DEBUG] 无有效主文件"
        echo "错误: 未找到任何可同步的主文件" >&2
        return 1
    fi

    # ------------------------------------------------------------------
    # 步骤5：上传到目标仓库
    # ------------------------------------------------------------------
    echo "[DEBUG] 开始上传..."
    echo "【5】上传至 $DST_REPO ..."
    
    if upload_component "$GROUP" "$ARTIFACT" "$VERSION" "${asset_files[@]}"; then
        echo "[DEBUG] upload_component 返回成功"
        echo "  上传成功！"
    else
        echo "[DEBUG] upload_component 返回失败"
        echo "  上传失败" >&2
        return 1
    fi

    echo "[DEBUG] sync_single 完成"
    echo "【完成】构件 $GROUP:$ARTIFACT:$VERSION 已同步至 $DST_REPO"
}

# ======================================================================
#                        主入口函数
# ======================================================================
# 功能：根据参数个数选择运行模式
# 参数：命令行参数
# 返回：同步函数的返回值
main() {
    # 打印配置信息
    echo "[DEBUG] ========== 脚本启动 =========="
    echo "[DEBUG] NEXUS_URL: $NEXUS_URL"
    echo "[DEBUG] USERNAME: $USERNAME"
    echo "[DEBUG] SRC_REPO: $SRC_REPO"
    echo "[DEBUG] DST_REPO: $DST_REPO"
    echo "[DEBUG] MAVEN_REPO_ID: $MAVEN_REPO_ID"
    
    if [[ -n "$MAVEN_SETTINGS" ]]; then
        echo "[DEBUG] 认证方式: settings.xml ($MAVEN_SETTINGS)"
    else
        echo "[DEBUG] 认证方式: URL 内嵌认证 (用户名/密码)"
    fi
    
    echo "[DEBUG] TMP_DIR_BASE: $TMP_DIR_BASE"
    echo "[DEBUG] 参数个数: $#"
    echo "[DEBUG] 参数列表: $*"
    echo "[DEBUG] ================================"
    
    # 检查 Maven 环境
    check_maven
    
    # 根据参数选择模式
    if [[ $# -eq 0 ]]; then
        # 无参数：全量同步模式
        sync_all_latest
    else
        # 有参数：单构件同步模式
        sync_single "$@"
    fi
}

# ======================================================================
#                        脚本执行入口
# ======================================================================
# 说明：调用 main 函数并传递所有命令行参数
main "$@"
