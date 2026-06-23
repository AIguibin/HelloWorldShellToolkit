#!/bin/bash
# /link-remote-repo - 将当前本地目录关联到远程 Git 仓库
#
# 用法:
#   aiguibin /link-remote-repo <repo-url> [分支名]
#   aiguibin /link-remote-repo --repo-url=<url> --branch=<name>
#
# 环境变量:
#   - AIGUIBIN_CLI_HOME: 安装目录
#   - AIGUIBIN_BASH: Bash 路径
#   - AIGUIBIN_WORKSPACE: 工作目录

set -e  # 遇到错误立即退出

# ---------- 帮助信息 ----------
show_help() {
    cat << 'EOF'
用法: aiguibin /link-remote-repo <repo-url> [分支名] [options]

使用场景：
  ──────────────────────────────────────────────────────────────
  场景1：关联本地目录到远程仓库（首次初始化）
  ──────────────────────────────────────────────────────────────
  # 将当前目录初始化为 Git 仓库并推送到远程 master 分支
  aiguibin /link-remote-repo https://github.com/user/repo.git

  ──────────────────────────────────────────────────────────────
  场景2：指定分支名关联（如 main 分支）
  ──────────────────────────────────────────────────────────────
  # 使用 main 分支而非默认的 master
  aiguibin /link-remote-repo https://github.com/user/repo.git main

  ──────────────────────────────────────────────────────────────
  场景3：已有 Git 仓库，更换远程地址
  ──────────────────────────────────────────────────────────────
  # 目录已有 .git，脚本会自动检测并更新 origin 地址
  aiguibin /link-remote-repo https://github.com/user/new-repo.git main

  ──────────────────────────────────────────────────────────────
  场景4：使用 --flag 参数格式
  ──────────────────────────────────────────────────────────────
  aiguibin /link-remote-repo --repo-url=https://github.com/user/repo.git --branch=main

参数:
  repo-url        远程仓库地址（必填，如 https://github.com/user/repo.git）
  分支名          目标分支名（可选，默认 master）

选项:
  --repo-url URL  远程仓库地址（等价于位置参数 1）
  --branch NAME   目标分支名（等价于位置参数 2）
  -h, --help      显示此帮助信息

执行流程:
  1. 检查参数合法性
  2. 初始化 Git 仓库（如目录非 Git 仓库则执行 git init）
  3. 设置远程仓库 origin（已存在则更新地址）
  4. 确保本地分支名为指定分支
  5. 添加并提交本地文件（git add . && git commit）
  6. 拉取远程内容并合并（允许无关历史，如远程有该分支）
  7. 推送到远程仓库并建立追踪关系

注意事项:
  - 需要本机已安装 Git 并配置好 SSH/HTTPS 凭证
  - 如远程仓库已有内容且与本地冲突，需手动解决后重新推送
  - 脚本使用 --allow-unrelated-histories 合并，不使用 rebase
EOF
}

# ---------- 解析命令行参数 ----------
REPO_URL=""
BRANCH="master"

# 先解析 --help
for arg in "$@"; do
    if [ "$arg" == "--help" ] || [ "$arg" == "-h" ]; then
        show_help
        exit 0
    fi
done

# 解析位置参数和 --flag 参数
POSITIONAL=()
while [ $# -gt 0 ]; do
    case "$1" in
        --repo-url=*)
            REPO_URL="${1#*=}"
            shift
            ;;
        --repo-url)
            REPO_URL="$2"
            shift 2
            ;;
        --branch=*)
            BRANCH="${1#*=}"
            shift
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# 位置参数回退
if [ -z "$REPO_URL" ] && [ ${#POSITIONAL[@]} -ge 1 ]; then
    REPO_URL="${POSITIONAL[0]}"
fi
if [ "$BRANCH" == "master" ] && [ ${#POSITIONAL[@]} -ge 2 ]; then
    BRANCH="${POSITIONAL[1]}"
fi

# ---------- 参数检查 ----------
if [ -z "$REPO_URL" ]; then
    echo "错误：缺少仓库地址 (repo-url)"
    echo "用法: aiguibin /link-remote-repo <repo-url> [分支名]"
    echo "示例: aiguibin /link-remote-repo https://github.com/user/repo.git main"
    echo "帮助: aiguibin /link-remote-repo --help"
    exit 1
fi

echo "==> 当前目录: $(pwd)"
echo "==> 远程仓库: $REPO_URL"
echo "==> 目标分支: $BRANCH"

# ---------- 初始化 Git（如需要） ----------
if [ -d ".git" ]; then
    echo "==> 目录已是 Git 仓库，将复用现有 .git"
else
    echo "==> 初始化 Git 仓库"
    git init
fi

# ---------- 设置远程仓库 origin ----------
# 检查是否已存在 origin 远程
if git remote | grep -q "^origin$"; then
    CURRENT_URL=$(git remote get-url origin)
    if [ "$CURRENT_URL" != "$REPO_URL" ]; then
        echo "==> 更新 origin 地址: $CURRENT_URL -> $REPO_URL"
        git remote set-url origin "$REPO_URL"
    else
        echo "==> origin 地址已正确，无需更改"
    fi
else
    echo "==> 添加远程仓库 origin"
    git remote add origin "$REPO_URL"
fi

# ---------- 确保本地分支名为指定分支 ----------
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "==> 当前分支为 $CURRENT_BRANCH，将重命名为 $BRANCH"
    git branch -M "$BRANCH"
elif [ -z "$CURRENT_BRANCH" ]; then
    # 刚初始化的仓库可能没有分支，创建一个孤立分支
    echo "==> 创建分支 $BRANCH"
    git checkout --orphan "$BRANCH" 2>/dev/null || git branch "$BRANCH"
    git checkout "$BRANCH" 2>/dev/null || true
fi

# ---------- 添加并提交本地文件 ----------
echo "==> 添加当前目录所有文件到 Git"
git add .

# 检查是否有待提交的更改
if git diff --cached --quiet; then
    echo "==> 没有需要提交的文件（可能已经提交过）"
else
    echo "==> 创建初始提交"
    git commit -m "Initial commit from local folder"
fi

# ---------- 拉取远程内容（允许无关历史） ----------
# 先检查远程仓库是否有该分支（避免空仓库时 pull 报错）
if git ls-remote --heads origin "$BRANCH" | grep -q "refs/heads/$BRANCH"; then
    echo "==> 远程已存在分支 $BRANCH，将拉取并合并（允许无关历史）"
    # 使用 --allow-unrelated-histories 合并，不使用 rebase 以避免复杂冲突
    if ! git pull origin "$BRANCH" --allow-unrelated-histories --no-rebase; then
        echo "错误：拉取时发生合并冲突，请手动解决后执行 'git push -u origin $BRANCH'"
        exit 2
    fi
else
    echo "==> 远程仓库尚无分支 $BRANCH，跳过拉取步骤"
fi

# ---------- 推送到远程仓库 ----------
echo "==> 推送到远程仓库（建立追踪关系）"
git push -u origin "$BRANCH"

echo "✅ 完成！本地目录已成功关联到 $REPO_URL 的 $BRANCH 分支"
