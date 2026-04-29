#!/bin/bash
set -euo pipefail

REMOTE_NAME="origin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}    $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}    $*"; }
error()   { echo -e "${RED}[ERROR]${NC}   $*"; }

on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        error "脚本执行异常终止，退出码: $exit_code"
        error "请根据上方提示排查问题后重新运行"
    fi
}
trap on_error EXIT

print_banner() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Git 本地文件夹 ↔ GitHub 仓库关联脚本${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_usage() {
    echo "用法: $0 <GitHub仓库URL>"
    echo ""
    echo "功能说明:"
    echo "  将当前本地文件夹与指定的 GitHub 仓库建立关联，"
    echo "  以当前文件夹名称作为分支名称创建本地分支并关联远程分支。"
    echo ""
    echo "参数:"
    echo "  GitHub仓库URL   远程仓库的完整地址 (HTTPS 或 SSH)"
    echo ""
    echo "示例:"
    echo "  $0 https://github.com/username/aiguibin-common-maven.git"
    echo "  $0 git@github.com:username/aiguibin-common-maven.git"
}

check_git_installed() {
    if ! command -v git &>/dev/null; then
        error "Git 未安装或不在 PATH 环境变量中"
        error "请先安装 Git: https://git-scm.com/downloads"
        exit 1
    fi
    local git_version
    git_version=$(git --version 2>/dev/null || echo "unknown")
    info "Git 环境检查通过: $git_version"
}

check_git_config() {
    local has_user_name=true
    local has_user_email=true

    if ! git config user.name &>/dev/null || [ -z "$(git config user.name)" ]; then
        has_user_name=false
    fi
    if ! git config user.email &>/dev/null || [ -z "$(git config user.email)" ]; then
        has_user_email=false
    fi

    if ! $has_user_name || ! $has_user_email; then
        warn "Git 用户信息未完整配置:"
        $has_user_name || warn "  - user.name 未设置"
        $has_user_email || warn "  - user.email 未设置"
        warn "建议执行以下命令进行配置:"
        $has_user_name || warn "  git config --global user.name \"你的名字\""
        $has_user_email || warn "  git config --global user.email \"你的邮箱\""
        echo ""
        read -rp "是否继续执行? (y/n) " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]] || { info "用户取消操作"; exit 0; }
    fi
}

check_remote_repo_accessible() {
    local repo_url="$1"
    info "正在验证远程仓库可访问性..."
    if git ls-remote "$repo_url" HEAD &>/dev/null; then
        success "远程仓库可访问: $repo_url"
    else
        warn "无法访问远程仓库: $repo_url"
        warn "可能原因: 网络连接问题 / 仓库不存在 / 权限不足 (SSH密钥未配置)"
        echo ""
        read -rp "是否忽略此警告继续执行? (y/n) " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]] || { info "用户取消操作"; exit 0; }
    fi
}

get_branch_name() {
    local folder_name
    folder_name=$(basename "$(pwd)")

    if [ -z "$folder_name" ]; then
        error "无法获取当前文件夹名称"
        exit 1
    fi

    local sanitized_name
    sanitized_name=$(echo "$folder_name" | sed 's/[ ~^:?*\[\\]//g' | sed 's/\.\.//g' | sed 's/\/\///g' | sed 's/@{.*//g')

    if [ "$folder_name" != "$sanitized_name" ]; then
        warn "文件夹名称包含 Git 分支不允许的字符，已自动清理"
        warn "  原始名称: '$folder_name'"
        warn "  清理后名称: '$sanitized_name'"
    fi

    if [ -z "$sanitized_name" ]; then
        error "清理后的分支名称为空，请检查当前文件夹名称"
        exit 1
    fi

    echo "$sanitized_name"
}

check_working_tree_clean() {
    if ! git rev-parse --verify HEAD &>/dev/null; then
        return 0
    fi

    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        warn "当前工作区存在未提交的更改"
        warn "切换分支可能导致更改丢失或冲突"
        echo ""
        git status --short 2>/dev/null | head -10
        echo ""
        read -rp "是否继续执行? (y/n) " -n 1 -r
        echo ""
        [[ $REPLY =~ ^[Yy]$ ]] || { info "用户取消操作"; exit 0; }
    fi
}

init_git_repo() {
    if [ -d ".git" ]; then
        info "当前目录已初始化 Git 仓库"
    else
        info "当前目录未初始化 Git 仓库，正在执行 git init..."
        git init
        success "Git 仓库初始化成功"
    fi
}

setup_remote() {
    local repo_url="$1"

    if git remote get-url "$REMOTE_NAME" &>/dev/null; then
        local existing_url
        existing_url=$(git remote get-url "$REMOTE_NAME")

        if [ "$existing_url" = "$repo_url" ]; then
            info "远程仓库 '$REMOTE_NAME' 已存在且 URL 一致"
            info "  URL: $repo_url"
        else
            warn "远程仓库 '$REMOTE_NAME' 已存在，URL 不一致"
            warn "  当前 URL: $existing_url"
            warn "  目标 URL: $repo_url"
            echo ""
            read -rp "是否更新远程仓库 URL? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git remote set-url "$REMOTE_NAME" "$repo_url"
                success "远程仓库 URL 已更新: $repo_url"
            else
                info "保留现有远程仓库 URL: $existing_url"
            fi
        fi
    else
        info "正在添加远程仓库 '$REMOTE_NAME'..."
        git remote add "$REMOTE_NAME" "$repo_url"
        success "远程仓库添加成功: $repo_url"
    fi
}

setup_branch() {
    local branch_name="$1"

    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    if [ "$current_branch" = "$branch_name" ]; then
        info "当前已在分支 '$branch_name' 上"
        return 0
    fi

    if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
        info "本地分支 '$branch_name' 已存在"
        check_working_tree_clean
        info "正在切换到分支 '$branch_name'..."
        git checkout "$branch_name"
        success "已切换到分支 '$branch_name'"
    else
        info "正在创建并切换到分支 '$branch_name'..."
        git checkout -b "$branch_name"
        success "分支 '$branch_name' 创建并切换成功"
    fi
}

setup_upstream() {
    local branch_name="$1"

    info "正在从远程仓库获取最新信息..."
    if git fetch "$REMOTE_NAME" 2>/dev/null; then
        success "远程仓库信息获取成功"
    else
        warn "无法从远程仓库获取信息 (可能是新仓库或网络问题)"
    fi

    if git show-ref --verify --quiet "refs/remotes/$REMOTE_NAME/$branch_name" 2>/dev/null; then
        info "远程分支 '$REMOTE_NAME/$branch_name' 已存在，正在设置上游跟踪..."
        git branch --set-upstream-to="$REMOTE_NAME/$branch_name" "$branch_name"
        success "上游分支跟踪设置成功: $branch_name -> $REMOTE_NAME/$branch_name"
    else
        info "远程分支 '$REMOTE_NAME/$branch_name' 尚不存在"
        info "将在首次推送时自动创建远程分支并建立跟踪关系"
        info "首次推送命令: git push -u $REMOTE_NAME $branch_name"
    fi
}

print_summary() {
    local branch_name="$1"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    local actual_remote_url
    actual_remote_url=$(git remote get-url "$REMOTE_NAME" 2>/dev/null || echo "未配置")

    echo ""
    echo -e "${CYAN}========================================${NC}"
    success "所有步骤执行完成！"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "  ${BLUE}当前分支:${NC}   $current_branch"
    echo -e "  ${BLUE}远程仓库:${NC}   $REMOTE_NAME -> $actual_remote_url"
    echo ""
    info "后续操作建议:"
    echo "  1. 添加文件:     git add ."
    echo "  2. 提交更改:     git commit -m \"初始提交\""
    echo "  3. 推送到远程:   git push -u $REMOTE_NAME $branch_name"
    echo ""
}

main() {
    if [ $# -ne 1 ]; then
        error "参数数量不正确"
        echo ""
        print_usage
        exit 1
    fi

    local repo_url="$1"

    if [[ ! "$repo_url" =~ ^(https?://|git@|ssh://) ]]; then
        error "仓库 URL 格式不正确: $repo_url"
        error "支持的格式: HTTPS (https://github.com/...) / SSH (git@github.com:...) / SSH (ssh://...)"
        exit 1
    fi

    print_banner

    local branch_name
    branch_name=$(get_branch_name)

    info "当前文件夹: $(basename "$(pwd)")"
    info "目标分支名: $branch_name"
    info "目标仓库:   $repo_url"
    echo ""

    check_git_installed
    check_git_config
    echo ""

    check_remote_repo_accessible "$repo_url"
    echo ""

    init_git_repo
    echo ""

    setup_remote "$repo_url"
    echo ""

    setup_branch "$branch_name"
    echo ""

    setup_upstream "$branch_name"

    print_summary "$branch_name"
}

main "$@"
