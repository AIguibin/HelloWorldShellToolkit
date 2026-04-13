#!/bin/bash

# 检查参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <branch-name>"
    exit 1
fi

BRANCH="$1"

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

# 创建A文件夹
mkdir -p NativeFloder
cd NativeFloder

# 克隆所有仓库的指定分支
for repo in "${REPOS[@]}"; do
    repo_name=$(basename "$repo" .git)
    echo "Cloning $repo_name into NativeFloder/$repo_name"
    git clone --branch "$BRANCH" "$repo" "$repo_name"
done

cd ..

# 创建B文件夹并复制A的内容
mkdir -p NoVersionFloder
cp -r NativeFloder/* NoVersionFloder/

# 删除B中所有项目的.git文件夹
find NoVersionFloder -type d -name ".git" -exec rm -rf {} +

# 创建C文件夹并复制B的内容
mkdir -p OnlyPomFolder
cp -r NoVersionFloder/* OnlyPomFolder/

# 进入C文件夹，遍历每个项目，仅保留pom.xml文件
cd OnlyPomFolder
for project in */; do
    if [ -d "$project" ]; then
        cd "$project"
        # 删除所有非pom.xml文件
        find . -type f -not -name 'pom.xml' -delete
        cd ..
    fi
done

cd ..

echo "操作完成。"