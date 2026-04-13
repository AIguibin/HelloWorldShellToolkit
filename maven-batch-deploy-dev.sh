#!/bin/bash
# ============================================================================
# Maven 批量部署脚本 (增强版)
# 功能特性:
#   1. 支持两种模式：指定路径工程 / 自动遍历当前目录工程
#   2. 支持指定分支并强制更新（支持大小写自动转换）
#   3. 支持指定 Maven setting 文件
#   4. 支持跳过 Git 操作
#   5. 支持并行/串行部署
#   6. 智能模块发现（支持多级目录查找）
# ============================================================================

# 设置UTF-8编码环境
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# ============================================================================
# 配置区域 - 以下配置可以直接在脚本中修改
# ============================================================================

# Maven 配置
SKIP_TESTS=true                     # 是否跳过测试
MAVEN_SETTINGS="/d/Maven/config/ncms-admin-dev-settings.xml"                  # Maven settings.xml 文件路径（可设置为绝对路径）
# 示例: MAVEN_SETTINGS="/opt/maven/conf/settings.xml"

# Git 配置
DEFAULT_BRANCH="DEV"             # 默认分支名称
GIT_FORCE_UPDATE=true            # 是否强制更新分支
GIT_SKIP=false					 # 默认不跳过Git操作

# 部署配置
PARALLEL_DEPLOY=false              # 是否并行部署
TIMEOUT=2400                       # 每个项目超时时间（秒），40分钟

# 目录排除配置
EXCLUDE_DIRS=".git,.idea,target,logs,node_modules,.settings,.project,.classpath,.vscode,*.bak,*.tmp,temp,build,dist,out,bin"

# 模块发现配置
#CLIENT_PATTERNS="*client*,*Client*,*CLIENT*,*api-client*,*-client-*,*api*,*Api*,*API*,*consumer*,*Consumer*"
#DTO_PATTERNS="*dto*,*Dto*,*DTO*,*model*,*-model*,*-dto-*,*domain*,*Domain*,*entity*,*Entity*,*pojo*,*Pojo*"
CLIENT_PATTERNS="*client*,*Client*,*CLIENT*"
DTO_PATTERNS="*dto*,*Dto*,*DTO*"

# 模块查找深度配置
MODULE_SEARCH_DEPTH=2              # 模块查找深度：1=仅根目录，2=根目录+子目录

# 日志配置
BASE_DIR="/d/WorkSpace"
LOG_DIR="${BASE_DIR}/deploy-logs"  # 日志目录   
LOG_RETENTION_DAYS=7               # 日志保留天数

# 高级配置
MAX_PARALLEL_JOBS=4                # 最大并行任务数（根据CPU核心数调整）
MAVEN_OPTS_MEMORY="-Xmx2048m -XX:MaxPermSize=512m"  # Maven内存选项
DEPLOY_SKIP_MODULES="test*,example*,demo*,sample*"  # 跳过部署的模块模式

# ============================================================================
# 脚本内部变量 - 请勿修改
# ============================================================================

# 版本信息
SCRIPT_VERSION="2.1.0"
SCRIPT_NAME="Maven Batch Deploy"
SCRIPT_AUTHOR="DevOps Team"

# 状态变量
TOTAL_PROJECTS=0
SUCCESS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
CURRENT_PROJECT_INDEX=0

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# 粗体颜色
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'

# 背景色
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'

# ============================================================================
# 初始化函数
# ============================================================================

# 初始化脚本
init_script() {
	# 进入文件夹
	cd /d/WorkSpace || {
			echo "无法进入目录: /d/WorkSpace"
			continue
	}
    # 创建日志目录
    mkdir -p "$LOG_DIR"
    
    # 设置日志文件
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="${LOG_DIR}/deploy-batch-${timestamp}.log"
    ERROR_LOG="${LOG_DIR}/deploy-errors-${timestamp}.log"
    SUMMARY_LOG="${LOG_DIR}/deploy-summary-${timestamp}.log"
    
    # 清理旧日志
    cleanup_old_logs
    
    # 显示脚本头
    show_header
}

# 显示脚本头信息
show_header() {
    echo -e "${BOLD_BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo -e "║    ${BOLD_YELLOW}$SCRIPT_NAME ${BOLD_BLUE}v$SCRIPT_VERSION${NC}${BOLD_BLUE}                              ║"
    echo "║                                                              ║"
    echo "║    批量部署工具 - 支持多工程、多模块、Git分支管理            ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_message "INFO" "脚本启动: $SCRIPT_NAME v$SCRIPT_VERSION"
    log_message "INFO" "作者: $SCRIPT_AUTHOR"
    log_message "INFO" "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_message "CONFIG" "模块查找深度: $MODULE_SEARCH_DEPTH"
}

# 清理旧日志
cleanup_old_logs() {
    if [ -d "$LOG_DIR" ]; then
        find "$LOG_DIR" -name "*.log" -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null
        log_message "DEBUG" "已清理超过 ${LOG_RETENTION_DAYS} 天的日志文件"
    fi
}

# ============================================================================
# 工具函数
# ============================================================================

# 日志函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO") color=$GREEN; prefix="ℹ️ " ;;
        "WARN") color=$YELLOW; prefix="⚠️ " ;;
        "ERROR") color=$RED; prefix="❌ " ;;
        "DEBUG") color=$GRAY; prefix="🐛 " ;;
        "STEP") color=$CYAN; prefix="📦 " ;;
        "SUCCESS") color=$MAGENTA; prefix="✅ " ;;
        "CONFIG") color=$BLUE; prefix="⚙️ " ;;
        *) color=$NC; prefix="" ;;
    esac
    
    # 控制台输出
    echo -e "${color}${prefix}[${timestamp}] [${level}] ${message}${NC}"
    
    # 文件日志（无颜色和emoji）
    local clean_message=$(echo "$message" | sed -e 's/\x1b\[[0-9;]*m//g' -e 's/[\x00-\x1F\x7F]//g')
    echo "[${timestamp}] [${level}] ${clean_message}" >> "$LOG_FILE"
    
    # 如果是错误，同时记录到错误日志
    if [ "$level" = "ERROR" ]; then
        echo "[${timestamp}] ${clean_message}" >> "$ERROR_LOG"
    fi
}

# 详细日志
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        log_message "DEBUG" "$1"
    fi
}

# 显示进度条
show_progress() {
    local current=$1
    local total=$2
    local width=50
    
    if [ $total -eq 0 ]; then
        return
    fi
    
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}进度:${NC} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${BOLD_YELLOW}%3d%%${NC} (%d/%d)" $percent $current $total
    
    if [ $current -eq $total ]; then
        printf "\n"
    fi
}

# 检查依赖命令
check_dependencies() {
    local missing_deps=()
    
    log_message "STEP" "检查系统依赖..."
    
    # 检查 Maven
    if ! command -v mvn &> /dev/null; then
        missing_deps+=("Maven")
    else
        local maven_version=$(mvn -v 2>/dev/null | head -n 1 | grep -o 'Apache Maven [0-9.]*')
        log_message "DEBUG" "Maven 版本: ${maven_version:-未知}"
    fi
    
    # 检查 Git (如果不跳过 Git 操作)
    if [ "$GIT_SKIP" != true ] && ! command -v git &> /dev/null; then
        missing_deps+=("Git")
    elif [ "$GIT_SKIP" != true ]; then
        local git_version=$(git --version 2>/dev/null | grep -o '[0-9.]*')
        log_message "DEBUG" "Git 版本: ${git_version:-未知}"
    fi
    
    # 检查 timeout 命令
    if ! command -v timeout &> /dev/null; then
        missing_deps+=("timeout (coreutils)")
    fi
    
    # 检查 realpath
    if ! command -v realpath &> /dev/null; then
        missing_deps+=("realpath")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message "ERROR" "缺少依赖: ${missing_deps[*]}"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "Maven")
                    echo -e "  ${RED}✗${NC} 请安装 Maven: https://maven.apache.org/install.html"
                    ;;
                "Git")
                    echo -e "  ${RED}✗${NC} 请安装 Git: https://git-scm.com/downloads"
                    ;;
                "timeout")
                    echo -e "  ${RED}✗${NC} 请安装 coreutils 包 (通常已预装)"
                    ;;
                "realpath")
                    echo -e "  ${RED}✗${NC} 请安装 coreutils 包"
                    ;;
            esac
        done
        exit 1
    else
        log_message "SUCCESS" "所有依赖检查通过"
    fi
}

# 检查 Maven 配置
check_maven_config() {
    log_message "STEP" "检查 Maven 配置..."
    
    # 检查 settings 文件是否存在
    if [ -n "$MAVEN_SETTINGS" ]; then
        if [ ! -f "$MAVEN_SETTINGS" ]; then
            log_message "ERROR" "指定的 settings.xml 文件不存在: $MAVEN_SETTINGS"
            MAVEN_SETTINGS=""
        else
            log_message "SUCCESS" "使用 Maven settings: $MAVEN_SETTINGS"
        fi
    else
        # 检查默认的 settings 文件
        local default_settings=(
            "$HOME/.m2/settings.xml"
            "/etc/maven/settings.xml"
            "/opt/maven/conf/settings.xml"
            "/usr/local/maven/conf/settings.xml"
        )
        
        for settings_file in "${default_settings[@]}"; do
            if [ -f "$settings_file" ]; then
                log_message "INFO" "发现 Maven settings: $settings_file"
                break
            fi
        done
    fi
    
    # 设置 Maven 内存选项
    export MAVEN_OPTS="${MAVEN_OPTS_MEMORY} ${MAVEN_OPTS}"
    log_message "DEBUG" "Maven 内存选项: $MAVEN_OPTS"
}

# 显示当前配置
show_configuration() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD_YELLOW}当前配置:${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
    
    # Git 配置
    echo -e "  ${BLUE}Git 配置:${NC}"
    echo -e "    默认分支: ${GRAY}${DEFAULT_BRANCH}${NC}"
    echo -e "    强制更新: ${GRAY}$([ "$GIT_FORCE_UPDATE" = true ] && echo "是" || echo "否")${NC}"
    echo -e "    跳过操作: ${GRAY}$([ "$GIT_SKIP" = true ] && echo "是" || echo "否")${NC}"
	if [ -n "$TARGET_BRANCH" ];then
		echo -e "目标分支: ${GRAY}${TARGET_BRANCH}${NC}"
	fi
    
    # Maven 配置
    echo -e "  ${BLUE}Maven 配置:${NC}"
    echo -e "    跳过测试: ${GRAY}$([ "$SKIP_TESTS" = true ] && echo "是" || echo "否")${NC}"
    echo -e "    Settings: ${GRAY}${MAVEN_SETTINGS:-未指定}${NC}"
    echo -e "    超时时间: ${GRAY}${TIMEOUT}秒${NC}"
    
    # 部署配置
    echo -e "  ${BLUE}部署配置:${NC}"
    echo -e "    并行部署: ${GRAY}$([ "$PARALLEL_DEPLOY" = true ] && echo "是 (最大${MAX_PARALLEL_JOBS}个)" || echo "否")${NC}"
    echo -e "    排除目录: ${GRAY}${EXCLUDE_DIRS}${NC}"
    echo -e "    查找深度: ${GRAY}${MODULE_SEARCH_DEPTH}${NC}"
    
    # 模块配置
    echo -e "  ${BLUE}模块配置:${NC}"
    echo -e "    Client模式: ${GRAY}${CLIENT_PATTERNS}${NC}"
    echo -e "    DTO模式: ${GRAY}${DTO_PATTERNS}${NC}"
    echo -e "    跳过模块: ${GRAY}${DEPLOY_SKIP_MODULES}${NC}"
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
# Git 操作函数 (增加大小写兼容)
# ============================================================================

# 尝试切换分支，支持大小写自动转换
try_checkout_branch() {
    local target_branch="$1"
    local current_dir="$2"
    
    # 保存当前目录
    cd "$current_dir" || return 1
    
    # 定义分支名尝试列表（按优先级排序）
    local branch_attempts=()
    
    # 添加原分支名
    branch_attempts+=("$target_branch")
    
    # 添加小写版本
    local lower_branch=$(echo "$target_branch" | tr '[:upper:]' '[:lower:]')
    if [ "$lower_branch" != "$target_branch" ]; then
        branch_attempts+=("$lower_branch")
    fi
    
    # 添加大写版本
    local upper_branch=$(echo "$target_branch" | tr '[:lower:]' '[:upper:]')
    if [ "$upper_branch" != "$target_branch" ] && [ "$upper_branch" != "$lower_branch" ]; then
        branch_attempts+=("$upper_branch")
    fi
    
    # 首字母大写，其余小写
    local capitalized_branch=$(echo "$target_branch" | sed 's/.*/\L&/; s/\w/\u&/')
    if [ "$capitalized_branch" != "$target_branch" ] && 
       [ "$capitalized_branch" != "$lower_branch" ] && 
       [ "$capitalized_branch" != "$upper_branch" ]; then
        branch_attempts+=("$capitalized_branch")
    fi
    
    # 去重
    local unique_branches=()
    for branch in "${branch_attempts[@]}"; do
        if [[ ! " ${unique_branches[@]} " =~ " ${branch} " ]]; then
            unique_branches+=("$branch")
        fi
    done
    
    log_message "DEBUG" "分支尝试列表: ${unique_branches[*]}"
    
    # 尝试每个分支
    for branch_to_try in "${unique_branches[@]}"; do
        log_message "DEBUG" "尝试分支: $branch_to_try"
        
        # 检查分支是否存在（本地）
        if git show-ref --verify --quiet "refs/heads/$branch_to_try" 2>/dev/null; then
            # 本地分支存在，尝试切换
            if git checkout "$branch_to_try" 2>&1 | tee -a "$LOG_FILE"; then
                log_message "SUCCESS" "成功切换到本地分支: $branch_to_try"
                echo "$branch_to_try"
                return 0
            fi
        fi
        
        # 检查远程分支
        if git ls-remote --exit-code --heads origin "$branch_to_try" 2>/dev/null; then
            # 远程分支存在，尝试拉取并切换
            log_message "DEBUG" "从远程拉取分支: $branch_to_try"
            if git fetch origin "$branch_to_try:$branch_to_try" 2>&1 | tee -a "$LOG_FILE"; then
                if git checkout "$branch_to_try" 2>&1 | tee -a "$LOG_FILE"; then
                    log_message "SUCCESS" "成功切换到远程分支: $branch_to_try"
                    echo "$branch_to_try"
                    return 0
                fi
            fi
        fi
    done
    
    # 所有尝试都失败
    log_message "ERROR" "无法找到分支: $target_branch (尝试了: ${unique_branches[*]})"
    echo ""
    return 1
}

# Git 操作：检查状态、切换分支、强制更新
git_operations() {
    local project_path="$1"
    local target_branch="${2:-$DEFAULT_BRANCH}"
    
    log_message "STEP" "执行 Git 操作: 尝试切换到分支 '${target_branch}'"
    
    # 检查是否是 Git 仓库
    if [ ! -d "$project_path/.git" ]; then
        log_message "WARN" "不是 Git 仓库，跳过 Git 操作"
        return 1
    fi
    
    # 保存当前目录
    local current_dir=$(pwd)
    cd "$project_path" || return 1
    
    # 获取远程仓库信息
    local remote_url=$(git remote -v 2>/dev/null | head -n1 | awk '{print $2}')
    local repo_name=$(basename -s .git "$remote_url" 2>/dev/null || echo "未知仓库")
    
    log_message "INFO" "仓库: ${repo_name}"
    log_message "INFO" "路径: $(pwd)"
    
    # 检查当前状态
    local current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
    local has_changes=false
    
    # 检查是否有未提交的更改
    if git status --porcelain 2>/dev/null | grep -q '^'; then
        has_changes=true
        log_message "WARN" "发现未提交的更改:"
        git status --short | head -10
    fi
    
    # 如果有未提交的更改且不跳过，询问用户
    if [ "$has_changes" = true ] && [ "$GIT_FORCE_UPDATE" = true ]; then
        log_message "WARN" "将强制更新，未提交的更改可能会丢失！"
        read -p "是否继续？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            cd "$current_dir"
            return 1
        fi
        
        # 暂存更改
        log_message "INFO" "暂存未提交的更改..."
        git stash push -m "Auto-stashed by deploy script $(date '+%Y-%m-%d %H:%M:%S')" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # 如果已经在目标分支
    if [ "$current_branch" = "$target_branch" ]; then
        log_message "INFO" "已在目标分支 '${target_branch}'"
        
        # 更新分支
        log_message "STEP" "更新分支..."
        if ! git pull origin "$target_branch" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "ERROR" "Git 更新失败"
            cd "$current_dir"
            return 1
        fi
    else
        # 尝试切换分支（支持大小写转换）
        local final_branch=$(try_checkout_branch "$target_branch" "$project_path")
        
        if [ -z "$final_branch" ]; then
            log_message "ERROR" "分支切换失败，跳过项目"
            cd "$current_dir"
            return 1
        fi
        
        log_message "SUCCESS" "成功切换到分支 '${final_branch}'"
        
        # 更新分支
        if [ "$GIT_FORCE_UPDATE" = true ]; then
            log_message "STEP" "强制更新分支..."
            if ! git pull --force origin "$final_branch" 2>&1 | tee -a "$LOG_FILE"; then
                log_message "ERROR" "Git 强制更新失败"
                cd "$current_dir"
                return 1
            fi
        else
            log_message "STEP" "更新分支..."
            if ! git pull origin "$final_branch" 2>&1 | tee -a "$LOG_FILE"; then
                log_message "ERROR" "Git 更新失败"
                cd "$current_dir"
                return 1
            fi
        fi
    fi
    
    # 显示最新提交信息
    local latest_commit=$(git log --oneline -1 2>/dev/null || echo "无法获取提交信息")
    local commit_hash=$(echo "$latest_commit" | cut -d' ' -f1)
    local commit_msg=$(echo "$latest_commit" | cut -d' ' -f2-)
    
    log_message "INFO" "最新提交: ${commit_hash:0:7} - ${commit_msg}"
    
    # 如果有暂存的更改，恢复它们
    if [ "$has_changes" = true ] && [ "$GIT_FORCE_UPDATE" = true ]; then
        log_message "STEP" "恢复暂存的更改..."
        if git stash pop 2>&1 | tee -a "$LOG_FILE"; then
            log_message "SUCCESS" "已恢复暂存的更改"
        else
            log_message "WARN" "恢复暂存更改时发生冲突"
        fi
    fi
    
    cd "$current_dir"
    log_message "SUCCESS" "Git 操作完成"
    return 0
}

# ============================================================================
# 模块发现函数 (增加多级目录查找)
# ============================================================================

# 检查是否跳过模块
should_skip_module() {
    local module_name="$1"
    
    # 将跳过模式转换为数组
    IFS=',' read -ra skip_patterns <<< "$DEPLOY_SKIP_MODULES"
    
    for pattern in "${skip_patterns[@]}"; do
        pattern=$(echo "$pattern" | xargs)  # 去除空格
        if [[ -n "$pattern" ]] && [[ "$module_name" == $pattern ]]; then
            return 0  # 应该跳过
        fi
    done
    
    return 1  # 不应该跳过
}

# 检查目录名是否匹配模式
matches_pattern() {
    local dir_name="$1"
    local pattern_list="$2"
    
    # 将模式列表转换为数组
    IFS=',' read -ra patterns <<< "$pattern_list"
    
    for pattern in "${patterns[@]}"; do
        pattern=$(echo "$pattern" | xargs)  # 去除空格
        if [[ -n "$pattern" ]] && [[ "$dir_name" == $pattern ]]; then
            return 0  # 匹配
        fi
    done
    
    return 1  # 不匹配
}

# 在指定目录查找模块
find_modules_in_directory() {
    local search_dir="$1"
    local depth="$2"
    local base_dir="${3:-$search_dir}"
    
    local modules=()
    
    # 将匹配模式转换为数组
    IFS=',' read -ra client_patterns_array <<< "$CLIENT_PATTERNS"
    IFS=',' read -ra dto_patterns_array <<< "$DTO_PATTERNS"
    
    # 将数组转换回逗号分隔的字符串，用于matches_pattern函数
    local client_patterns_str=$(IFS=','; echo "${client_patterns_array[*]}")
    local dto_patterns_str=$(IFS=','; echo "${dto_patterns_array[*]}")
    
    # 查找目录下的所有pom.xml文件
    while IFS= read -r pom_file; do
        [ -z "$pom_file" ] && continue
        
        # 获取模块目录
        local module_dir=$(dirname "$pom_file")
        
        # 计算相对于base_dir的路径
        local relative_path="${module_dir#$base_dir/}"
        if [ "$relative_path" = "$module_dir" ]; then
            relative_path="."  # 如果在base_dir本身
        fi
        
        # 如果是当前目录，使用目录名
        if [ "$relative_path" = "." ]; then
            relative_path=$(basename "$module_dir")
        fi
        
        # 获取模块名称（目录名）
        local module_name=$(basename "$module_dir")
        
        # 检查是否应该跳过
        if should_skip_module "$module_name"; then
            log_verbose "跳过模块: $module_name (匹配跳过模式)"
            continue
        fi
        
        # 检查是否为有效的Maven模块
        if [ ! -f "$pom_file" ]; then
            continue
        fi
        
        # 检查模块名是否匹配client或dto模式
        local is_client=false
        local is_dto=false
        
        # 检查 client 模式
        if matches_pattern "$module_name" "$client_patterns_str"; then
            is_client=true
        fi
        
        # 检查 dto 模式
        if matches_pattern "$module_name" "$dto_patterns_str"; then
            is_dto=true
        fi
        
        # 如果都不匹配，尝试从pom.xml中读取artifactId
        if [ "$is_client" = false ] && [ "$is_dto" = false ]; then
            local artifact_id=$(grep -o '<artifactId>[^<]*</artifactId>' "$pom_file" | head -1 | sed 's/<artifactId>//;s/<\/artifactId>//')
            
            if matches_pattern "$artifact_id" "$client_patterns_str"; then
                is_client=true
            fi
            
            if matches_pattern "$artifact_id" "$dto_patterns_str"; then
                is_dto=true
            fi
        fi
        
        if [ "$is_client" = true ] || [ "$is_dto" = true ]; then
            # 根据深度决定使用哪个路径
            if [ "$depth" -eq 1 ] && [ "$module_dir" = "$search_dir" ]; then
                # 根目录下的模块
                modules+=("$module_name")
            elif [ "$depth" -gt 1 ] && [ "$module_dir" != "$search_dir" ]; then
                # 子目录下的模块
                modules+=("$relative_path")
            fi
        fi
        
    done < <(find "$search_dir" -maxdepth "$depth" -mindepth 1 -name "pom.xml" -type f 2>/dev/null | grep -v "$search_dir/pom.xml")
    
    # 去重
    local unique_modules=()
    for module in "${modules[@]}"; do
        if [[ ! " ${unique_modules[@]} " =~ " ${module} " ]]; then
            unique_modules+=("$module")
        fi
    done
    
    # 排序：client 模块在前
    local sorted_modules=$(printf "%s\n" "${unique_modules[@]}" | sort | awk '
        {
            module = $0
            priority = 3  # 默认优先级
            
            # 检查是否是client模块
            if (module ~ /[Cc][Ll][Ii][Ee][Nn][Tt]/ || module ~ /[Aa][Pp][Ii]/ || module ~ /[Cc][Oo][Nn][Ss][Uu][Mm][Ee][Rr]/) {
                priority = 1
            }
            # 检查是否是dto模块
            else if (module ~ /[Dd][Tt][Oo]/ || module ~ /[Mm][Oo][Dd][Ee][Ll]/ || module ~ /[Ee][Nn][Tt][Ii][Tt][Yy]/ || module ~ /[Dd][Oo][Mm][Aa][Ii][Nn]/) {
                priority = 2
            }
            
            printf "%s:%d\n", module, priority
        }
    ' | sort -t: -k2 -n | cut -d: -f1)
    
    echo "${sorted_modules[@]}"
}

# 发现项目中的 client/dto 模块（支持多级目录查找）
discover_modules() {
    local project_path="$1"
    
    log_verbose "正在发现模块: $project_path (查找深度: $MODULE_SEARCH_DEPTH)"
    
    local all_modules=()
    
    # 按深度逐级查找
    for ((depth=1; depth<=MODULE_SEARCH_DEPTH; depth++)); do
        log_verbose "在深度 $depth 查找模块..."
        local depth_modules=$(find_modules_in_directory "$project_path" "$depth" "$project_path")
        
        if [ -n "$depth_modules" ]; then
            while IFS= read -r module; do
                [ -z "$module" ] && continue
                
                # 检查模块是否已经在列表中
                local found=false
                for existing_module in "${all_modules[@]}"; do
                    if [ "$existing_module" = "$module" ]; then
                        found=true
                        break
                    fi
                done
                
                if [ "$found" = false ]; then
                    all_modules+=("$module")
                fi
            done <<< "$depth_modules"
        fi
    done
    
    # 如果没有找到模块，尝试更智能的查找
    if [ ${#all_modules[@]} -eq 0 ]; then
        log_verbose "常规查找未找到模块，尝试扩展查找..."
        
        # 查找所有包含pom.xml的目录
        local all_pom_dirs=$(find "$project_path" -name "pom.xml" -type f 2>/dev/null | xargs -I {} dirname {} | sort -u)
        
        for pom_dir in $all_pom_dirs; do
            # 跳过项目根目录
            if [ "$pom_dir" = "$project_path" ]; then
                continue
            fi
            
            # 获取相对于项目根目录的路径
            local relative_path="${pom_dir#$project_path/}"
            
            # 获取目录名
            local dir_name=$(basename "$pom_dir")
            
            # 检查目录名是否包含关键词
            if [[ "$dir_name" =~ [Cc][Ll][Ii][Ee][Nn][Tt] ]] || 
               [[ "$dir_name" =~ [Dd][Tt][Oo] ]] || 
               [[ "$dir_name" =~ [Aa][Pp][Ii] ]] || 
               [[ "$dir_name" =~ [Mm][Oo][Dd][Ee][Ll] ]]; then
                
                # 检查是否应该跳过
                if ! should_skip_module "$dir_name"; then
                    all_modules+=("$relative_path")
                fi
            fi
        done
    fi
    
    # 去重
    local unique_modules=()
    for module in "${all_modules[@]}"; do
        if [[ ! " ${unique_modules[@]} " =~ " ${module} " ]]; then
            unique_modules+=("$module")
        fi
    done
    
    # 排序：client 模块在前，短路径在前
    local sorted_modules=$(printf "%s\n" "${unique_modules[@]}" | sort | awk '
        {
            module = $0
            # 计算路径深度（斜杠数量）
            depth = gsub(/\//, "/", module)
            
            priority = 3  # 默认优先级
            
            # 检查是否是client模块
            if (module ~ /[Cc][Ll][Ii][Ee][Nn][Tt]/ || module ~ /[Aa][Pp][Ii]/ || module ~ /[Cc][Oo][Nn][Ss][Uu][Mm][Ee][Rr]/) {
                priority = 1
            }
            # 检查是否是dto模块
            else if (module ~ /[Dd][Tt][Oo]/ || module ~ /[Mm][Oo][Dd][Ee][Ll]/ || module ~ /[Ee][Nn][Tt][Ii][Tt][Yy]/ || module ~ /[Dd][Oo][Mm][Aa][Ii][Nn]/) {
                priority = 2
            }
            
            # 输出: 模块:优先级:深度
            printf "%s:%d:%d\n", module, priority, depth
        }
    ' | sort -t: -k2,2n -k3,3n | cut -d: -f1)
    
    local module_list=$(echo "$sorted_modules" | tr '\n' ',' | sed 's/,$//')
    
    if [ -z "$module_list" ]; then
        log_verbose "未找到 client/dto 模块"
        echo ""
        return 1
    fi
    
    echo "$module_list"
    return 0
}

# ============================================================================
# 部署核心函数
# ============================================================================

# 部署单个项目
deploy_single_project() {
    local project_path="$1"
    local project_name=$(basename "$project_path")
    
    CURRENT_PROJECT_INDEX=$((CURRENT_PROJECT_INDEX + 1))
    
    echo -e "\n${BLUE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD_BLUE}项目 [$CURRENT_PROJECT_INDEX/$TOTAL_PROJECTS]: ${project_name}${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
    
    log_message "STEP" "开始处理项目: ${project_name}"
    log_message "INFO" "项目路径: ${project_path}"
    
    # 1. Git 操作（如果不跳过）
    if [ "$GIT_SKIP" != true ] ; then
		local branch_to_use="${TARGET_BRANCH:-$DEFAULT_BRANCH}"
        if ! git_operations "$project_path" "$branch_to_use"; then
            if [ "$FAIL_ON_GIT_ERROR" = true ]; then
                log_message "ERROR" "Git 操作失败，终止项目部署"
                return 1
            else
                log_message "WARN" "Git 操作失败，继续尝试部署"
            fi
        fi
	else 
		log_message "INFO" "跳过Git操作"
    fi
    
    # 2. 检查项目有效性
    if [ ! -f "$project_path/pom.xml" ]; then
        log_message "ERROR" "不是 Maven 项目（未找到 pom.xml），跳过"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return 1
    fi
    
    # 3. 发现模块
    local modules=$(discover_modules "$project_path")
    if [ -z "$modules" ]; then
        log_message "WARN" "未发现 client/dto 模块，跳过部署"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        return 1
    fi
    
    log_message "SUCCESS" "发现模块: ${modules}"
    
    # 4. 进入项目目录
    cd "$project_path" || {
        log_message "ERROR" "无法进入项目目录"
        return 1
    }
    
    # 5. 准备 Maven 命令
    local maven_cmd="mvn clean deploy"
    
    # 添加模块参数
    if [ -n "$modules" ]; then
        maven_cmd="$maven_cmd -pl $modules -am"
    fi
    
    # 添加 settings 文件参数
    if [ -n "$MAVEN_SETTINGS" ] && [ -f "$MAVEN_SETTINGS" ]; then
        maven_cmd="$maven_cmd -s $MAVEN_SETTINGS"
    fi
    
    # 添加测试参数
    if [ "$SKIP_TESTS" = true ]; then
        maven_cmd="$maven_cmd -DskipTests -Dmaven.test.skip=true -DskipITs -DaltDeploymentRepository=nexus-snapshots::default::http://192.15.3.99:10390/repository/maven-credit-dev-snapshots/"
    fi
    
    # 添加其他参数
    if [ "$VERBOSE" = true ]; then
        maven_cmd="$maven_cmd -X"
    fi
    
    # 添加非交互模式
    maven_cmd="$maven_cmd -B"
    
    # 6. 执行部署
    log_message "STEP" "执行 Maven 部署..."
    log_message "DEBUG" "命令: $maven_cmd"
    
    local start_time=$(date +%s)
    
    # 执行命令（带超时控制）
    local output_file="${LOG_DIR}/maven-${project_name}-${start_time}.log"
    
    echo "开始时间: $(date)" > "$output_file"
    echo "项目: $project_name" >> "$output_file"
    echo "模块: $modules" >> "$output_file"
    echo "命令: $maven_cmd" >> "$output_file"
    echo "========================================" >> "$output_file"
    
    if timeout $TIMEOUT bash -c "$maven_cmd" 2>&1 | tee -a "$output_file"; then
        local exit_code=${PIPESTATUS[0]}
        
        if [ $exit_code -eq 0 ]; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            echo -e "\n========================================" >> "$output_file"
            echo "结束时间: $(date)" >> "$output_file"
            echo "状态: 成功" >> "$output_file"
            echo "耗时: ${duration}秒" >> "$output_file"
            
            log_message "SUCCESS" "✅ 项目 ${project_name} 部署成功 (耗时: ${duration}秒)"
            
            # 记录部署信息
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $project_name - 模块: $modules - 耗时: ${duration}秒" >> "$LOG_FILE"
            
            cd - > /dev/null
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            echo -e "\n========================================" >> "$output_file"
            echo "结束时间: $(date)" >> "$output_file"
            echo "状态: 失败 (退出码: $exit_code)" >> "$output_file"
            echo "耗时: ${duration}秒" >> "$output_file"
            
            log_message "ERROR" "❌ 项目 ${project_name} 部署失败 (退出码: $exit_code)"
            
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAILED: $project_name - 退出码: $exit_code" >> "$ERROR_LOG"
            
            cd - > /dev/null
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return 1
        fi
    else
        local timeout_status=$?
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        if [ $timeout_status -eq 124 ]; then
            log_message "ERROR" "⏰ 项目 ${project_name} 部署超时 (${TIMEOUT}秒)"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] TIMEOUT: $project_name - 超时: ${TIMEOUT}秒" >> "$ERROR_LOG"
        else
            log_message "ERROR" "❌ 项目 ${project_name} 部署过程出错"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $project_name - 未知错误" >> "$ERROR_LOG"
        fi
        
        echo -e "\n========================================" >> "$output_file"
        echo "结束时间: $(date)" >> "$output_file"
        echo "状态: 异常" >> "$output_file"
        echo "耗时: ${duration}秒" >> "$output_file"
        
        cd - > /dev/null
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# 获取当前目录下的所有工程
get_all_projects() {
    local base_dir="${1:-.}"
    
    log_message "STEP" "正在扫描目录: $(realpath "$base_dir")"
    
    local projects=()
    
    # 使用简单的查找方法
    # 首先查找一级目录
    while IFS= read -r dir; do
        if [ -f "$dir/pom.xml" ]; then
            projects+=("$dir")
            log_verbose "发现项目: $(basename "$dir")"
        fi
    done < <(find "$base_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
    
    # 如果没有找到，再查找二级目录
    if [ ${#projects[@]} -eq 0 ]; then
        log_verbose "一级目录未找到项目，尝试查找二级目录..."
        while IFS= read -r dir; do
            if [ -f "$dir/pom.xml" ]; then
                projects+=("$dir")
                log_verbose "发现项目: $(basename "$dir")"
            fi
        done < <(find "$base_dir" -maxdepth 2 -mindepth 1 -type d 2>/dev/null)
    fi
    
    # 过滤排除目录
    local filtered_projects=()
    for project in "${projects[@]}"; do
        local include=true
        
        # 检查是否应该排除
        IFS=',' read -ra exclude_array <<< "$EXCLUDE_DIRS"
        for exclude in "${exclude_array[@]}"; do
            exclude=$(echo "$exclude" | xargs)
            if [[ -n "$exclude" ]] && [[ "$project" == *"$exclude"* ]]; then
                log_verbose "排除目录: $project (匹配模式: $exclude)"
                include=false
                break
            fi
        done
        
        if [ "$include" = true ]; then
            filtered_projects+=("$project")
        fi
    done
    
    # 按目录名排序
    if [ ${#filtered_projects[@]} -gt 0 ]; then
        filtered_projects=($(printf "%s\n" "${filtered_projects[@]}" | sort))
    fi
    
    echo "${filtered_projects[@]}"
}

# 并行部署
deploy_parallel() {
    local project_paths=("$@")
    local pids=()
    local results=()
    
    log_message "INFO" "开始并行部署 ${#project_paths[@]} 个项目 (最大并发: ${MAX_PARALLEL_JOBS})"
    
    # 准备进度显示
    local processed=0
    local total=${#project_paths[@]}
    
    for project_path in "${project_paths[@]}"; do
        local project_name=$(basename "$project_path")
        
        # 等待有空闲的进程槽
        while [ ${#pids[@]} -ge $MAX_PARALLEL_JOBS ]; do
            # 检查是否有进程结束
            for idx in "${!pids[@]}"; do
                local pid=${pids[$idx]}
                if ! kill -0 "$pid" 2>/dev/null; then
                    # 进程已结束，从数组中移除
                    unset "pids[$idx]"
                    pids=("${pids[@]}")  # 重新索引数组
                    
                    # 更新进度
                    processed=$((processed + 1))
                    show_progress $processed $total
                fi
            done
            sleep 1
        done
        
        # 启动后台任务
        log_message "DEBUG" "启动并行部署: $project_name"
        deploy_single_project "$project_path" &
        
        local pid=$!
        pids+=($pid)
        results+=("$project_path:$pid")
    done
    
    # 等待所有进程完成
    while [ ${#pids[@]} -gt 0 ]; do
        for idx in "${!pids[@]}"; do
            local pid=${pids[$idx]}
            if ! kill -0 "$pid" 2>/dev/null; then
                # 进程已结束
                unset "pids[$idx]"
                pids=("${pids[@]}")
                
                processed=$((processed + 1))
                show_progress $processed $total
            fi
        done
        sleep 1
    done
    
    # 等待所有后台进程完成并收集结果
    for idx in "${!results[@]}"; do
        local pid=${results[$idx]%:*}
        if wait $pid; then
            : # 成功已在 deploy_single_project 中统计
        else
            : # 失败已在 deploy_single_project 中统计
        fi
    done
    
    log_message "INFO" "并行部署完成"
}

# ============================================================================
# 部署摘要函数
# ============================================================================

# 显示部署摘要
show_summary() {
    local total_time=$1
    
    echo -e "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD_GREEN}部署摘要${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    # 项目统计
    echo -e "${BLUE}项目统计:${NC}"
    echo -e "  总项目数:   ${BOLD_YELLOW}$TOTAL_PROJECTS${NC}"
    echo -e "  成功:       ${BOLD_GREEN}$SUCCESS_COUNT${NC}"
    echo -e "  失败:       ${BOLD_RED}$FAIL_COUNT${NC}"
    echo -e "  跳过:       ${GRAY}$SKIP_COUNT${NC}"
    
    # 成功率
    if [ $TOTAL_PROJECTS -gt 0 ]; then
        local success_rate=$((SUCCESS_COUNT * 100 / TOTAL_PROJECTS))
        echo -e "  成功率:     ${BOLD_BLUE}${success_rate}%${NC}"
    fi
    
    # 时间统计
    echo -e "\n${BLUE}时间统计:${NC}"
    echo -e "  总耗时:     $((total_time / 3600))小时$(((total_time % 3600) / 60))分$((total_time % 60))秒"
    echo -e "  平均耗时:   $(($total_time / ($SUCCESS_COUNT + $FAIL_COUNT + 1)))秒/项目"
    
    # 配置信息
    echo -e "\n${BLUE}配置信息:${NC}"
    if [ -n "$TARGET_BRANCH" ]; then
        echo -e "  目标分支:   ${GRAY}${TARGET_BRANCH}${NC}"
    fi
    if [ -n "$MAVEN_SETTINGS" ]; then
        echo -e "  Maven配置:  ${GRAY}${MAVEN_SETTINGS}${NC}"
    fi
    echo -e "  部署模式:   ${GRAY}$([ "$PARALLEL_DEPLOY" = true ] && echo "并行" || echo "串行")${NC}"
    echo -e "  跳过测试:   ${GRAY}$([ "$SKIP_TESTS" = true ] && echo "是" || echo "否")${NC}"
    echo -e "  查找深度:   ${GRAY}${MODULE_SEARCH_DEPTH}${NC}"
    
    # 日志信息
    echo -e "\n${BLUE}日志信息:${NC}"
    echo -e "  详细日志:   ${GRAY}${LOG_FILE}${NC}"
    if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
        echo -e "  错误日志:   ${RED}${ERROR_LOG}${NC}"
    fi
    echo -e "  日志目录:   ${GRAY}${LOG_DIR}${NC}"
    
    # 最终状态
    echo -e "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
    
    if [ $FAIL_COUNT -eq 0 ] && [ $SUCCESS_COUNT -gt 0 ]; then
        echo -e "${BG_GREEN}${BOLD_YELLOW} ✓ 所有项目部署成功！ ${NC}"
    elif [ $SUCCESS_COUNT -gt 0 ] && [ $FAIL_COUNT -gt 0 ]; then
        echo -e "${BG_YELLOW}${BOLD_BLUE} ⚠ 部分项目部署完成 ${NC}"
        echo -e "${YELLOW}   ${FAIL_COUNT}个项目失败，请检查错误日志${NC}"
    elif [ $SUCCESS_COUNT -eq 0 ]; then
        echo -e "${BG_RED}${BOLD_YELLOW} ✗ 所有项目部署失败！ ${NC}"
    fi
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
    
    # 保存摘要到文件
    save_summary "$total_time"
}

# 保存摘要到文件
save_summary() {
    local total_time=$1
    
    cat > "$SUMMARY_LOG" << EOF
部署摘要 - $(date '+%Y-%m-%d %H:%M:%S')

项目统计:
  总项目数: $TOTAL_PROJECTS
  成功: $SUCCESS_COUNT
  失败: $FAIL_COUNT
  跳过: $SKIP_COUNT

时间统计:
  总耗时: $((total_time / 3600))小时$(((total_time % 3600) / 60))分$((total_time % 60))秒

配置信息:
  目标分支: ${TARGET_BRANCH:-未指定}
  Maven配置: ${MAVEN_SETTINGS:-默认}
  部署模式: $([ "$PARALLEL_DEPLOY" = true ] && echo "并行" || echo "串行")
  跳过测试: $([ "$SKIP_TESTS" = true ] && echo "是" || echo "否")
  查找深度: $MODULE_SEARCH_DEPTH

日志文件:
  详细日志: $LOG_FILE
  错误日志: $ERROR_LOG
  摘要日志: $SUMMARY_LOG

部署项目列表:
EOF
    
    # 记录所有处理的项目
    for project in "${ALL_PROJECTS[@]}"; do
        echo "  - $(basename "$project")" >> "$SUMMARY_LOG"
    done
}

# ============================================================================
# 主函数
# ============================================================================

# 输出帮助信息
show_help() {
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD_YELLOW}$SCRIPT_NAME - 批量部署工具 v$SCRIPT_VERSION${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD_GREEN}用法:${NC}"
    echo -e "  $0 [选项] [工程路径1] [工程路径2] ..."
    echo ""
    echo -e "${BOLD_GREEN}模式说明:${NC}"
    echo -e "  1. ${BLUE}指定路径模式:${NC} 部署指定的工程路径"
    echo -e "     $0 -b develop /path/to/project1 /path/to/project2"
    echo ""
    echo -e "  2. ${BLUE}自动遍历模式:${NC} 自动遍历当前目录下的所有工程"
    echo -e "     $0 -b master"
    echo ""
    echo -e "${BOLD_GREEN}选项:${NC}"
    echo -e "  ${YELLOW}-h, --help${NC}                显示此帮助信息"
    echo -e "  ${YELLOW}-b, --branch <branch>${NC}     指定 Git 分支 (默认: ${DEFAULT_BRANCH})"
    echo -e "  ${YELLOW}-s, --settings <path>${NC}     指定 Maven settings.xml 文件路径"
    echo -e "  ${YELLOW}-g, --git-skip${NC}            跳过 Git 操作 (不切换分支和更新)"
    echo -e "  ${YELLOW}-f, --force-update${NC}        强制更新分支 (git pull --force)"
    echo -e "  ${YELLOW}-p, --parallel${NC}            并行部署模式"
    echo -e "  ${YELLOW}-t, --test${NC}                不跳过测试 (默认跳过)"
    echo -e "  ${YELLOW}-l, --limit <n>${NC}           限制处理项目数量"
    echo -e "  ${YELLOW}-m, --modules${NC}             仅查找模块，不执行部署"
    echo -e "  ${YELLOW}-e, --exclude <pattern>${NC}   排除目录模式 (追加到默认排除列表)"
    echo -e "  ${YELLOW}-v, --verbose${NC}             详细输出模式"
    echo -e "  ${YELLOW}-q, --quiet${NC}               安静模式，只输出错误"
    echo -e "  ${YELLOW}-c, --config${NC}              显示当前配置"
    echo -e "  ${YELLOW}-V, --version${NC}             显示版本信息"
    echo -e "  ${YELLOW}-d, --depth <n>${NC}           设置模块查找深度 (默认: ${MODULE_SEARCH_DEPTH})"
    echo ""
    echo -e "${BOLD_GREEN}新功能:${NC}"
    echo -e "  ${GREEN}✓${NC} 分支大小写自动兼容 (DEV/dev/Dev)"
    echo -e "  ${GREEN}✓${NC} 多级目录模块查找"
    echo -e "  ${GREEN}✓${NC} 智能模块发现"
    echo ""
    echo -e "${BOLD_GREEN}示例:${NC}"
    echo -e "  ${GRAY}# 部署指定工程到 develop 分支${NC}"
    echo -e "  $0 -b develop -s ~/.m2/settings.xml project1 project2"
    echo ""
    echo -e "  ${GRAY}# 自动遍历当前目录，并行部署到 release 分支${NC}"
    echo -e "  $0 -b release/1.0 --parallel --limit 10"
    echo ""
    echo -e "  ${GRAY}# 跳过 Git，仅运行测试${NC}"
    echo -e "  $0 --git-skip --test"
    echo ""
    echo -e "  ${GRAY}# 设置查找深度为3，查找更深层的模块${NC}"
    echo -e "  $0 --depth 3"
    echo ""
    echo -e "  ${GRAY}# 仅发现模块，不部署${NC}"
    echo -e "  $0 --modules"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
}

# 主函数
main() {
    local start_time=$(date +%s)
    
    # 初始化脚本
    init_script
    
    # 解析命令行参数
    local projects_to_deploy=()
    local only_discover=false
    local exclude_patterns=""
    local limit_projects=0
    local show_config_only=false
    GIT_SKIP=false
    VERBOSE=false
    QUIET=false
    TARGET_BRANCH=""
    FAIL_ON_GIT_ERROR=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -b|--branch)
                TARGET_BRANCH="$2"
                shift 2
                ;;
            -s|--settings)
                MAVEN_SETTINGS="$2"
                shift 2
                ;;
            -g|--git-skip)
                GIT_SKIP=true
                shift
                ;;
            -f|--force-update)
                GIT_FORCE_UPDATE=true
                FAIL_ON_GIT_ERROR=true
                shift
                ;;
            -p|--parallel)
                PARALLEL_DEPLOY=true
                shift
                ;;
            -t|--test)
                SKIP_TESTS=false
                shift
                ;;
            -l|--limit)
                limit_projects="$2"
                if ! [[ "$limit_projects" =~ ^[0-9]+$ ]]; then
                    log_message "ERROR" "无效的限制数值: $2"
                    exit 1
                fi
                shift 2
                ;;
            -m|--modules)
                only_discover=true
                shift
                ;;
            -e|--exclude)
                exclude_patterns="$2"
                EXCLUDE_DIRS="${EXCLUDE_DIRS},${exclude_patterns}"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                VERBOSE=false
                shift
                ;;
            -c|--config)
                show_config_only=true
                shift
                ;;
            -V|--version)
                echo -e "${BOLD_YELLOW}$SCRIPT_NAME v$SCRIPT_VERSION${NC}"
                echo -e "作者: $SCRIPT_AUTHOR"
                exit 0
                ;;
            -d|--depth)
                MODULE_SEARCH_DEPTH="$2"
                if ! [[ "$MODULE_SEARCH_DEPTH" =~ ^[1-9][0-9]*$ ]]; then
                    log_message "ERROR" "无效的查找深度: $2 (必须是正整数)"
                    exit 1
                fi
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_message "ERROR" "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                # 检查是否是存在的目录
                if [ -d "$1" ]; then
                    projects_to_deploy+=("$(realpath "$1")")
                elif [ -f "$1/pom.xml" ]; then
                    projects_to_deploy+=("$(realpath "$(dirname "$1")")")
                else
                    log_message "WARN" "跳过无效路径: $1"
                fi
                shift
                ;;
        esac
    done
    
	# 如果没有指定分支但需要Git操作，使用默认分支
	if [ "$GIT_SKIP" != true ] && [ -z "$TARGET_BRANCH" ]; then
		TARGET_BRANCH="$DEFAULT_BRANCH"
		log_message "INFO" "未指定分支，使用默认分支：$DEFAULT_BRANCH"
	fi
	
	if [ "$GIT_SKIP" != true ]; then
		TARGET_BRANCH=""
	fi
	
    # 如果只需要显示配置
    if [ "$show_config_only" = true ]; then
        show_configuration
        exit 0
    fi
    
    # 检查依赖
    check_dependencies
    
    # 检查 Maven 配置
    check_maven_config
    
    # 模式选择
    if [ ${#projects_to_deploy[@]} -gt 0 ]; then
        # 模式1: 部署指定路径的工程
        log_message "INFO" "模式1: 部署指定路径的工程 (${#projects_to_deploy[@]}个)"
    else
        # 模式2: 自动遍历当前目录下的工程
        log_message "INFO" "模式2: 自动遍历当前目录下的工程"
        
        projects_to_deploy=($(get_all_projects "."))
        
        if [ ${#projects_to_deploy[@]} -eq 0 ]; then
            log_message "ERROR" "当前目录下未找到任何 Maven 工程"
            echo -e "${RED}请确认:${NC}"
            echo -e "  1. 当前目录是否包含 Maven 项目"
            echo -e "  2. 项目是否包含 pom.xml 文件"
            echo -e "  3. 排除配置是否正确: ${EXCLUDE_DIRS}"
            exit 1
        fi
        
        # 限制项目数量
        if [ $limit_projects -gt 0 ]; then
            projects_to_deploy=("${projects_to_deploy[@]:0:$limit_projects}")
            log_message "INFO" "限制处理前 ${limit_projects} 个项目"
        fi
        
        log_message "SUCCESS" "发现 ${#projects_to_deploy[@]} 个工程"
    fi
    
    TOTAL_PROJECTS=${#projects_to_deploy[@]}
    ALL_PROJECTS=("${projects_to_deploy[@]}")
    
    # 显示即将部署的项目列表
    if [ "$QUIET" = false ]; then
        echo -e "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD_YELLOW}即将部署以下项目 (${TOTAL_PROJECTS}个):${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
        
        for idx in "${!projects_to_deploy[@]}"; do
            local project_path="${projects_to_deploy[$idx]}"
            local project_name=$(basename "$project_path")
            # 只输出项目名称，不调用log_verbose
            echo -e "  $((idx+1)). ${BOLD_BLUE}${project_name}${NC}"
        done
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    fi
    
    # 显示当前配置
    show_configuration
    
    # 如果是仅发现模块模式
    if [ "$only_discover" = true ]; then
        log_message "INFO" "仅发现模块模式，不执行部署"
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD_YELLOW}模块发现结果:${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
        echo "项目,路径,模块列表"
        
        for project_path in "${projects_to_deploy[@]}"; do
            project_name=$(basename "$project_path")
            modules=$(discover_modules "$project_path")
            echo "$project_name,$project_path,$modules"
        done
        
        echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
        exit 0
    fi
    
    # 确认提示
    if [ "$QUIET" = false ]; then
        echo -e "\n${YELLOW}══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD_YELLOW}部署确认${NC}"
        echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
        
        echo -e "  项目总数: ${BOLD_YELLOW}${TOTAL_PROJECTS}${NC}"
		echo -e "  目标分支: ${BOLD_BLUE}${TARGET_BRANCH}${NC}"
		echo -e "  Git 操作: $([ "$GIT_SKIP" = true ] && echo "跳过" || echo "执行 (分支: ${TARGET_BRANCH:-$DEFAULT_BRANCH}) ")"
		echo -e "  强制更新: $([ "$GIT_FORCE_UPDATE" = true ] && echo "是" || echo "否")"
        
		echo -e "  跳过测试: $([ "$SKIP_TESTS" = true ] && echo "是" || echo "否")"
        echo -e "  并行部署: $([ "$PARALLEL_DEPLOY" = true ] && echo "是" || echo "否")"
        echo -e "  查找深度: ${MODULE_SEARCH_DEPTH}"
        if [ -n "$MAVEN_SETTINGS" ]; then
            echo -e "  Maven配置: ${MAVEN_SETTINGS}"
        fi
        echo -e "${YELLOW}══════════════════════════════════════════════════════════════${NC}"
        
        read -p "是否继续部署？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_message "INFO" "用户取消部署"
            exit 0
        fi
    fi
    
    # 执行部署
    log_message "STEP" "开始批量部署..."
    
    if [ "$PARALLEL_DEPLOY" = true ] && [ $TOTAL_PROJECTS -gt 1 ]; then
        if [ "$QUIET" = false ]; then
            log_message "WARN" "警告：并行部署模式可能造成资源竞争和部署顺序问题"
            read -p "确认启用并行部署？(y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                PARALLEL_DEPLOY=false
            fi
        fi
    fi
    
    if [ "$PARALLEL_DEPLOY" = true ] && [ $TOTAL_PROJECTS -gt 1 ]; then
        deploy_parallel "${projects_to_deploy[@]}"
    else
        # 串行部署
        for project_path in "${projects_to_deploy[@]}"; do
            deploy_single_project "$project_path"
            
            # 显示进度
            if [ "$QUIET" = false ]; then
                show_progress $((SUCCESS_COUNT + FAIL_COUNT + SKIP_COUNT)) $TOTAL_PROJECTS
            fi
        done
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # 显示摘要
    if [ "$QUIET" = false ]; then
        show_summary $total_duration
    else
        # 安静模式下只输出摘要
        echo "部署完成: 成功 $SUCCESS_COUNT, 失败 $FAIL_COUNT, 跳过 $SKIP_COUNT, 总计 $TOTAL_PROJECTS"
    fi
    
    # 错误汇总
    if [ -s "$ERROR_LOG" ]; then
        if [ "$QUIET" = false ]; then
            log_message "WARN" "以下项目部署失败:"
            cat "$ERROR_LOG" | while read line; do
                log_message "ERROR" "$line"
            done
        fi
    fi
    
    log_message "INFO" "详细日志请查看: $LOG_FILE"
    
    # 返回适当的退出码
    if [ $FAIL_COUNT -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# ============================================================================
# 脚本入口
# ============================================================================

# 确保在出错时退出
set -e

# 捕获中断信号
trap 'echo -e "\n${RED}部署被用户中断${NC}"; exit 130;' INT TERM

# 执行主函数
main "$@"