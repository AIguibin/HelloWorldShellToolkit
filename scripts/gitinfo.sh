#!/usr/bin/env bash
# ============================================================
# /gitinfo - 查看当前 Git 仓库信息
#
# 用法:
#   /gitinfo
#   /gitinfo --remote=origin
# ============================================================

AIGUIBIN_TASK_ID="${AIGUIBIN_TASK_ID:-N/A}"
AIGUIBIN_OUTPUT_DIR="${AIGUIBIN_OUTPUT_DIR:-.}"
AIGUIBIN_WORKSPACE="${AIGUIBIN_WORKSPACE:-.}"

# 默认 remote
REMOTE="${1:-origin}"
# 从 --remote=X 参数中提取值
for arg in "$@"; do
    case $arg in
        --remote=*) REMOTE="${arg#*=}" ;;
    esac
done

echo "=================================================="
echo "  Git Repository Info"
echo "=================================================="
echo ""

# 检查是否在 git 仓库中
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "  [ERROR] Not a git repository"
    echo "  Workspace: $AIGUIBIN_WORKSPACE"
    exit 1
fi

# 基本信息
echo "  Branch:    $(git branch --show-current 2>/dev/null || echo 'detached')"
echo "  Commit:    $(git log -1 --format='%h %s' 2>/dev/null || echo 'N/A')"
echo "  Author:    $(git log -1 --format='%an <%ae>' 2>/dev/null || echo 'N/A')"
echo "  Date:      $(git log -1 --format='%ai' 2>/dev/null || echo 'N/A')"
echo ""

# Remote 信息
REMOTE_URL=$(git remote get-url "$REMOTE" 2>/dev/null)
if [ -n "$REMOTE_URL" ]; then
    echo "  Remote ($REMOTE): $REMOTE_URL"
else
    echo "  Remote ($REMOTE): not configured"
fi
echo ""

# 状态
echo "  --- Status ---"
git status --short 2>/dev/null | head -10
echo ""

# 最近 5 条 commit
echo "  --- Recent Commits ---"
git log --oneline -5 2>/dev/null
echo ""

# 输出到文件
REPORT="$AIGUIBIN_OUTPUT_DIR/gitinfo_report.txt"
{
    echo "Git Info Report"
    echo "Generated: $(date)"
    echo "Workspace: $AIGUIBIN_WORKSPACE"
    echo "Branch: $(git branch --show-current 2>/dev/null)"
    echo "Commit: $(git log -1 --format='%H' 2>/dev/null)"
    echo ""
    git status 2>/dev/null
    echo ""
    git log --oneline -10 2>/dev/null
} > "$REPORT"

echo "  Report saved: $REPORT"
