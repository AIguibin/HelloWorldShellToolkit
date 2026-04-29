#!/bin/bash

# 设置日志文件
LOG_FILE="app.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "开始执行合并操作..."

git remote set-url origin http://10.12.168.107/ecms/ecms-web.git && git checkout test_alpha_deploy && git fetch --all && git reset --hard origin/test_alpha_deploy && git pull

# 定义要合并的文件夹路径
TARGET_DIR="app/export-template"

# 检查当前目录是否为Git仓库
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "错误：当前目录不是Git仓库"
    exit 1
fi

# 检查目标文件夹是否存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "错误：目标文件夹 '$TARGET_DIR' 不存在"
    exit 1
fi

# 函数：检查是否有未提交的更改
check_clean_worktree() {
    if ! git diff-index --quiet HEAD --; then
        echo "错误：工作区有未提交的更改，请先清理工作区"
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
        echo "检测到冲突，正在回滚合并..."
        git reset --hard HEAD
        git clean -fd
        echo "错误：合并过程中出现冲突，已回滚"
        return 1
    fi
    
    # 如果没有冲突，提交更改
    git add "$TARGET_DIR"
    if git commit -m "$commit_message"; then
        git push origin "$target_branch"
        echo "成功合并并推送到 $target_branch"
        return 0
    else
        echo "错误：提交失败"
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
