#!/bin/bash

# 基础路径配置
BASE_DIR="/d/WorkSpace"
LOG_DIR="${BASE_DIR}/logs"
mkdir -p "$LOG_DIR"  # 确保日志目录存在

# 日志文件命名（基于当前日期）
CURRENT_DATE=$(date +"%Y%m%d")
APP_LOG="${LOG_DIR}/${CURRENT_DATE}-app.log"
ERROR_LOG="${LOG_DIR}/${CURRENT_DATE}-error.log"

# 实际项目名称列表（请在此处修改为您的实际项目名称）
PROJECTS=(
    "tcp-ecms-cust"
    "ecms-rule-frontend"
    "tcp-ecms-system"
    "ty-gateway"
    "tcp-ecms-statistics"
    "tcp-ecms-retail-task"
    "tcp-ecms-rate"
    "tcp-ecms-product"
    "tcp-ecms-post-loan"
    "tcp-ecms-message"
    "tcp-ecms-interest-rate"
    "tcp-ecms-hierarchy"
    "tcp-ecms-docmanage"
    "tcp-ecms-cust"
    "tcp-ecms-corporate-task"
     "tcp-ecms-contract-loan"
    "tcp-ecms-common"
    "tcp-ecms-collateral"
    "tcp-ecms-batch-job"
    "tcp-ecms-airobot"
    "tcp-auth"
    "tansun-tcp-wf"
    "tansun-ipc-centers"
    "tansun-tcp-edoc"
    "risk-asset-mgt"
    "limit-mgt"
    "gateway"
    "ecms-external-data"
    "tymh-web"
    "tansun-tcp-wf"
    "ecms-h5-web"
    "ecms-pad-web"
    "ecms-wf-web"
    "ecms-rule-backend"
    "edoc-web"
    "tcp-ecms-airobot-web"
	"tymh-web"
    "ecms-h5-web"
    "ecms-pad-web"
    "ecms-wf-web"
    "edoc-web"
    "ecms-wf-web-designer"
	"Tansun Job"
	"Xxljob Admin Web"
)

# 日志记录函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$APP_LOG"
    echo "$1"  # 控制台也输出便于监控
}

error_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$ERROR_LOG"
    log "ERROR: $1"
}

# 主循环处理所有项目
for PROJECT in "${PROJECTS[@]}"; do
    PROJECT_DIR="${BASE_DIR}/${PROJECT}"
    
    log "━━━━━━━━━━━━━━━━ 开始处理 ${PROJECT} ━━━━━━━━━━━━━━━━"
    
    # 检查项目目录是否存在
    if [ ! -d "$PROJECT_DIR" ]; then
        error_log "目录不存在: ${PROJECT_DIR}"
        continue
    fi
    
    cd "$PROJECT_DIR" || {
        error_log "无法进入目录: ${PROJECT_DIR}"
        continue
    }
    
    # ==================== 第一阶段：test_alpha_deploy -> master ====================
	
	#查看当前分支状态
	git status >> "$APP_LOG" 2>&1
    
	#拉取最新的分支
	git pull --force >> "$APP_LOG" 2>&1
	
	
	#切换到test_alpha_deploy
	git checkout test_alpha_deploy >> "$APP_LOG" 2>&1
	
	# 检查并切换到 test_alpha_deploy 分支
    if ! git show-ref --verify --quiet refs/heads/test_alpha_deploy; then
        error_log "${PROJECT}: test_alpha_deploy 分支不存在"
        continue
    fi
    
    git checkout test_alpha_deploy >> "$APP_LOG" 2>&1
	
    
    # 强制更新 test_alpha_deploy
    log "强制更新 test_alpha_deploy..."
    git reset --hard HEAD >> "$APP_LOG" 2>&1
    git clean -fd >> "$APP_LOG" 2>&1
    if ! git pull --force >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: test_alpha_deploy 更新失败"
        continue
    fi
    
    # 切换到 master 并强制更新
    git checkout master >> "$APP_LOG" 2>&1
    log "强制更新 master..."
    git reset --hard HEAD >> "$APP_LOG" 2>&1
    git clean -fd >> "$APP_LOG" 2>&1
    if ! git pull --force >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: master 更新失败"
        continue
    fi
    
    # 合并 test_alpha_deploy 到 master
    log "合并 test_alpha_deploy 到 master..."
    if ! git merge test_alpha_deploy --no-commit >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: test_alpha_deploy→master 合并冲突"
        git merge --abort >> "$APP_LOG" 2>&1
        continue
    fi
	
    git commit -m "自动合并: test_alpha_deploy → master [$(date + '%Y-%m-%d %H:%M')]" >> "$APP_LOG" 2>&1
	
	#查看提交的内容
	git cherry -v >> "$APP_LOG" 2>&1
	
	#推送 master 分支到远程
	log "推送 master 分支到远程仓库..."
	if ! git push origin master >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: master 分支推送失败"
        continue
    fi
	
    
    # ==================== 第二阶段：master -> dev_alpha_deploy ====================
	
	git checkout dev_alpha_deploy >> "$APP_LOG" 2>&1
	git pull --force >> "$APP_LOG" 2>&1
    # 更新 master
    git checkout master >> "$APP_LOG" 2>&1
    git pull --force >> "$APP_LOG" 2>&1
	
    
	
    # 检查并切换到 dev_alpha_deploy 分支
    if ! git show-ref --verify --quiet refs/heads/dev_alpha_deploy; then
        error_log "${PROJECT}: dev_alpha_deploy 分支不存在"
        continue
    fi
    
    git checkout dev_alpha_deploy >> "$APP_LOG" 2>&1
    
    # 强制更新 dev_alpha_deploy
    log "强制更新 dev_alpha_deploy..."
    git reset --hard HEAD >> "$APP_LOG" 2>&1
    git clean -fd >> "$APP_LOG" 2>&1
    if ! git pull --force >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: dev_alpha_deploy 更新失败"
        continue
    fi
    
	
    # 合并 master 到 dev_alpha_deploy
    log "合并 master 到 dev_alpha_deploy..."
    if ! git merge master --no-commit >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: master→dev_alpha_deploy 合并冲突"
        git merge --abort >> "$APP_LOG" 2>&1
        continue
    fi
	
    git commit -m "自动合并: master → dev_alpha_deploy  [$(date + '%Y-%m-%d %H:%M')]" >> "$APP_LOG" 2>&1
	
	#查看提交的内容
	git cherry -v >> "$APP_LOG" 2>&1
	
	#推送 dev_alpha_deploy 分支到远程
	log "推送 dev_alpha_deploy 分支到远程仓库..."
	if ! git push origin dev_alpha_deploy >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: dev_alpha_deploy 分支推送失败"
        continue
    fi
    
    log "✅ ${PROJECT} 处理完成"
done

log "========= 信贷天元前端分支公共文件夹app/export-template合并开始 =========="

echo "信贷天元前端分支公共文件夹app/export-template合并开始..."

echo "切换ecms-web信贷前端目录..."

cd "${BASE_DIR}/ecms-web" || {
	error_log "无法进入目录信贷前端: ${BASE_DIR}/ecms-web"
	continue
}
echo "开始执行合并操作..."

git remote set-url origin http://10.12.168.107/ecms/ecms-web.git && git checkout test_alpha_deploy && git fetch --all && git reset --hard origin/test_alpha_deploy && git pull

# 定义要合并的文件夹路径
TARGET_DIR="app/export-template"

# 检查当前目录是否为Git仓库
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    error_log "错误：当前目录不是Git仓库"
    exit 1
fi

# 检查目标文件夹是否存在
if [ ! -d "$TARGET_DIR" ]; then
    error_log "错误：目标文件夹 '$TARGET_DIR' 不存在"
    exit 1
fi

# 函数：检查是否有未提交的更改
check_clean_worktree() {
    if ! git diff-index --quiet HEAD --; then
        error_log "错误：工作区有未提交的更改，请先清理工作区"
        exit 1
    fi
}

# 函数：尝试合并指定文件夹
merge_folder() {
    local source_branch=$1
    local target_branch=$2
    local commit_message="Merge folder '$TARGET_DIR' from $source_branch to $target_branch"
    
    echo "尝试从 $source_branch 合并到 $target_branch..."
    
    # 切换到目标分支并更新
    git checkout "$target_branch" || exit 1
    git pull origin "$target_branch" || exit 1
    
    # 使用git checkout将特定文件夹从源分支检出到目标分支
    git checkout "$source_branch" -- "$TARGET_DIR"
    
    # 检查是否有冲突
    if git diff --name-only --diff-filter=U | grep -q "^$TARGET_DIR/"; then
        error_log "检测到冲突，正在回滚合并..."
        git reset --hard HEAD
        git clean -fd
        error_log "错误：合并过程中出现冲突，已回滚"
        return 1
    fi
    
    # 如果没有冲突，提交更改
    git add "$TARGET_DIR"
    if git commit -m "$commit_message"; then
        git push origin "$target_branch"
        echo "成功合并并推送到 $target_branch"
        return 0
    else
        error_log "错误：提交失败"
        return 1
    fi
}

# 主执行流程
check_clean_worktree

# 第一步：从test_alpha_deploy合并到master
if merge_folder "test_alpha_deploy" "master"; then
    echo "第一步合并成功，继续执行第二步..."
    # 第二步：从master合并到dev_alpha_deploy
    if merge_folder "master" "dev_alpha_deploy"; then
        echo "所有合并操作完成"
    else
        echo "第二步合并失败"
    fi
else
    echo "第一步合并失败，停止执行"
fi


git remote set-url origin http://10.12.168.107/ecms/ecms-web.git && git checkout master && git fetch --all && git reset --hard origin/master && git pull && git remote -v && git remote set-url origin http://10.12.170.176/ecms/ecms-web.git  && echo "新仓库"   && git remote -v && git push origin master --force && \
git remote set-url origin http://10.12.168.107/ecms/ecms-web.git && git checkout dev_bugfix_all && git fetch --all && git reset --hard origin/dev_bugfix_all && git pull && git remote -v && git remote set-url origin http://10.12.170.176/ecms/ecms-web.git  && echo "新仓库"   && git remote -v && git push  origin dev_bugfix_all --force && \
git remote set-url origin http://10.12.168.107/ecms/ecms-web.git && git checkout dev_alpha_bugfix && git fetch --all && git reset --hard origin/dev_alpha_bugfix && git pull && git remote -v && git remote set-url origin http://10.12.170.176/ecms/ecms-web.git  && echo "新仓库"   && git remote -v && git push  origin dev_alpha_bugfix --force && \
git remote set-url origin http://10.12.168.107/ecms/ecms-web.git && git checkout dev_alpha_deploy && git fetch --all && git reset --hard origin/dev_alpha_deploy && git pull && git remote -v && git remote set-url origin http://10.12.170.176/ecms/ecms-web.git   && echo "新仓库"  && git remote -v && git push  origin dev_alpha_deploy --force && \
git remote set-url origin http://10.12.168.107/ecms/ecms-web.git && git checkout test_alpha_bugfix && git fetch --all && git reset --hard origin/test_alpha_bugfix && git pull && git remote -v && git remote set-url origin http://10.12.170.176/ecms/ecms-web.git  && echo "新仓库"   && git remote -v && git push  origin test_alpha_bugfix --force && \
git remote set-url origin http://10.12.168.107/ecms/ecms-web.git && git checkout test_alpha_deploy && git fetch --all && git reset --hard origin/test_alpha_deploy && git pull && git remote -v && git remote set-url origin http://10.12.170.176/ecms/ecms-web.git  && echo "新仓库" && git remote -v && git push  origin test_alpha_deploy --force


log "========================== 所有项目处理完成 ========================="