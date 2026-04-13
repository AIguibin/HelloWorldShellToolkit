#!/bin/bash

# 配置参数
PROTECTED_BRANCHES=("master" "main" "dev_bugfix_all" "dev_alpha_bugfix"  "dev_alpha_deploy" "test_alpha_bugfix" "test_alpha_deploy")  # 保护分支列表
DAYS_OLD=30                                          # 过期天数
PATTERN=""                                           # 分支名正则模式
DRY_RUN=false                                        # 模拟运行模式

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --days)
            DAYS_OLD="$2"
            shift 2
            ;;
        --pattern)
            PATTERN="$2"
            shift 2
            ;;
        --protect)
            PROTECTED_BRANCHES+=("$2")
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "未知选项: $1"
            exit 1
            ;;
    esac
done

# 安全确认
echo "=== 远程分支清理 (Windows兼容版) ==="
echo "• 保护分支: ${PROTECTED_BRANCHES[*]}"
echo "• 过期天数: $DAYS_OLD 天"
[ -n "$PATTERN" ] && echo "• 分支匹配: $PATTERN"
$DRY_RUN && echo "• 模拟运行: 仅显示不删除"
echo "--------------------------------"
echo "警告: 此操作将永久删除远程分支！"

if ! $DRY_RUN; then
    read -p "确认执行? (y/n) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# Windows兼容时间计算
NOW=$(date +%s)
TIME_CUTOFF=$(date -d "$DAYS_OLD days ago" +%s)

# 创建保护分支正则
protect_regex=$(IFS="|"; echo "${PROTECTED_BRANCHES[*]}")

echo "开始扫描远程分支..."
git fetch --prune --all # 更新远程引用

git for-each-ref --format='%(refname:short) %(committerdate:unix)' refs/remotes | \
grep -v 'HEAD' | while read remote_branch date; do
    # 提取纯分支名（去掉 origin/ 前缀）
    branch=${remote_branch#origin/}
    
    # 跳过保护分支
    if [[ "$branch" =~ ^($protect_regex)$ ]]; then
        continue
    fi
    
    # 检查正则匹配
    if [ -n "$PATTERN" ] && ! [[ "$branch" =~ $PATTERN ]]; then
        continue
    fi
    
    # 检查时间阈值（使用实际提交时间）
    last_commit_date=$(git log -1 --format=%at "$remote_branch" 2>/dev/null)
    if [ -z "$last_commit_date" ]; then
        continue  # 跳过无效分支
    fi
    
    if [ "$last_commit_date" -lt "$TIME_CUTOFF" ]; then
        # Windows兼容日期格式化
        last_update=$(date -d "@$last_commit_date" "+%Y-%m-%d" 2>/dev/null || date -d @$last_commit_date "+%Y-%m-%d")
        
        if $DRY_RUN; then
            printf "待删除分支: \033[1;33m%-30s\033[0m (最后更新: %s)\n" "$branch" "$last_update"
        else
            printf "删除远程分支: \033[1;31m%-30s\033[0m (最后更新: %s)\n" "$branch" "$last_update"
            git push origin --delete "$branch"
        fi
    fi
done

if $DRY_RUN; then
    echo "模拟运行完成！实际执行请移除 --dry-run 参数"
else
    echo "远程分支清理完成！"
    echo "执行后续清理: git remote prune origin"
fi