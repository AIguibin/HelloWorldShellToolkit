#!/bin/bash

# 检查参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <branch-name>"
    exit 1
fi

BRANCH="$1"
APP_LOG="/d/WorkSpace/logs/$(date +"%Y%m%d")-app.log"

# 定义远程仓库地址数组
REPOS=(
    "http://10.12.170.176/ecms/ecms-external-data.git"
	"http://10.12.170.176/arch/gateway.git"
	"http://10.12.170.176/ecms/limit-mgt.git"
	"http://10.12.170.176/ecms/risk-asset-mgt.git"
	"http://10.12.170.176/ecms/ecms-common/tansun-tcp-edoc.git"
	"http://10.12.170.176/arch/tansun-ipc-centers.git"
	"http://10.12.170.176/ecms/ecms-common/tansun-tcp-wf.git"
	"http://10.12.170.176/arch/tcp-auth.git"
	"http://10.12.170.176/ecms/tcp-ecms-airobot.git"
	"http://10.12.170.176/ecms/tcp-ecms-batch-job.git"
	"http://10.12.170.176/ecms/tcp-ecms-collateral.git"
	"http://10.12.170.176/ecms/tcp-ecms-common.git"
	"http://10.12.170.176/ecms/tcp-ecms-contract-loan.git"
	"http://10.12.170.176/ecms/tcp-ecms-corporate-task.git"
	"http://10.12.170.176/ecms/tcp-ecms-cust.git"
	"http://10.12.170.176/ecms/tcp-ecms-docmanage.git"
	"http://10.12.170.176/ecms/tcp-ecms-hierarchy.git"
	"http://10.12.170.176/ecms/tcp-ecms-interest-rate.git"
	"http://10.12.170.176/ecms/tcp-ecms-message.git"
	"http://10.12.170.176/ecms/tcp-ecms-post-loan.git"
	"http://10.12.170.176/ecms/tcp-ecms-product.git"
	"http://10.12.170.176/ecms/tcp-ecms-rate.git"
	"http://10.12.170.176/ecms/tcp-ecms-retail-task.git"
	"http://10.12.170.176/ecms/tcp-ecms-statistics.git"
	"http://10.12.170.176/arch/ty-gateway.git"
	"http://10.12.170.176/ecms/tcp-ecms-system.git"
	"http://10.12.170.176/ecms/tansun-job.git"
	"http://10.12.170.176/ecms/ecms-rule-backend.git"
	"http://10.12.170.176/ecms/ecms-model-backend.git"
    "http://10.12.170.176/arch/external-gateway.git"
    "http://10.12.170.176/arch/sentinel-dashboard.git" 
	"http://10.12.170.176/ecms/tymh-web.git"
	"http://10.12.170.176/ecms/html/ecms-h5-web.git"
	"http://10.12.170.176/ecms/html/ecms-pad-web.git"
	"http://10.12.170.176/ecms/html/ecms-wf-web.git"
	"http://10.12.170.176/ecms/edoc-web.git"
	"http://10.12.170.176/ecms/tcp-ecms-airobot-web.git"
	"http://10.12.168.107/ecms/ecms-web.git"
	"http://10.12.170.176/ecms/html/ecms-wf-web-designer.git"
	"http://10.12.170.176/ecms/ecms-rule-frontend.git"
	"http://10.12.170.176/ecms/ecms-model-frontend.git"
    # 添加更多仓库地址...
)

# 进入文件夹

cd /d/WorkSpace || {
        echo "无法进入目录: /d/WorkSpace"
        continue
}

# 克隆所有仓库的指定分支
for repo in "${REPOS[@]}"; do
    repo_name=$(basename "$repo" .git)
    echo "Cloning $repo_name into $repo_name"
    git clone --branch "$BRANCH" "$repo" "$repo_name"
	
	# 检查项目目录是否存在
    if [ ! -d "$repo_name" ]; then
        echo "目录不存在: ${repo_name}"
        continue
    fi
	
	cd "$repo_name" || {
        echo "无法进入目录: ${repo_name}"
        continue
    }
	#切换分支
	git checkout "$BRANCH"
	#拉取最新的分支
	git pull --force >> "$APP_LOG" 2>&1
	
	# 强制更新 
    echo "强制更新 $BRANCH ..."
    git reset --hard HEAD >> "$APP_LOG" 2>&1
    git clean -fd >> "$APP_LOG" 2>&1
    if ! git pull --force >> "$APP_LOG" 2>&1; then
        echo "${repo_name}: $BRANCH 更新失败"
        continue
    fi
	
	#退回上一级目录
	cd ..
	echo "退回上一级目录" & pwd
done

echo "操作完成。"