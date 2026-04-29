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
    "ecms-h5-web"
    "ecms-pad-web"
    "ecms-wf-web"
    "ecms-rule-backend"
    "edoc-web"
    "tcp-ecms-airobot-web"
    "ecms-wf-web"
    "ecms-wf-web-designer"
    "tansun-job"
    "xxljob-admin-web"
    "ecms-model-backend"
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

log "━━━━━━━━━━━━━━━━ 不包含ECMS-WEB,需特殊处理 ━━━━━━━━━━━━━━━━"

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
    
    # ==================== 第一阶段：pre_prod_release -> master ====================
	
	#查看当前分支状态
	git status >> "$APP_LOG" 2>&1
    
	#拉取最新的分支
	git pull --force >> "$APP_LOG" 2>&1
	
	
	#切换到pre_prod_release
	git checkout pre_prod_release >> "$APP_LOG" 2>&1
	
	# 检查并切换到 pre_prod_release 分支
    if ! git show-ref --verify --quiet refs/heads/pre_prod_release; then
        error_log "${PROJECT}: pre_prod_release 分支不存在"
        continue
    fi
    
    git checkout pre_prod_release >> "$APP_LOG" 2>&1
	
    
    # 强制更新 pre_prod_release
    log "强制更新 pre_prod_release..."
    git reset --hard HEAD >> "$APP_LOG" 2>&1
    git clean -fd >> "$APP_LOG" 2>&1
    if ! git pull --force >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: pre_prod_release 更新失败"
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
    
    # 合并 pre_prod_release 到 master
    log "合并 pre_prod_release 到 master..."
    if ! git merge pre_prod_release --no-commit >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: pre_prod_release→master 合并冲突"
        git merge --abort >> "$APP_LOG" 2>&1
        continue
    fi
	
    git commit -m "自动合并: pre_prod_release → master [$(date +'%Y-%m-%d %H:%M:%S')]" >> "$APP_LOG" 2>&1
	
	#查看提交的内容
	git cherry -v >> "$APP_LOG" 2>&1
	
	#推送 master 分支到远程
	log "推送 master 分支到远程仓库..."
	if ! git push origin master >> "$APP_LOG" 2>&1; then
        error_log "${PROJECT}: master 分支推送失败"
        continue
    fi
	
    log "✅ ${PROJECT} 处理完成"
done

log "========================== 所有项目处理完成 ========================="