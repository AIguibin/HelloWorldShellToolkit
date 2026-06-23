"""AIguibinCLI Bootstrap - 首次启动自动下载 Git 便携版和 Node.js

被 bin/aiguibin.bat 调用，在 aiguibin.py 启动前运行。
检测 AIGUIBIN_CLI_HOME/git/ 和 AIGUIBIN_CLI_HOME/node/，缺失则自动下载。

版本号动态从 npmmirror API 获取，缓存到 config/runtime-versions.json，
避免每次启动都发起网络请求。

下载源:
  Git:  https://registry.npmmirror.com/-/binary/git-for-windows/
  Node: https://registry.npmmirror.com/-/binary/node/latest-v22.x/
"""

import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile

# AIGUIBIN_CLI_HOME: 优先环境变量，回退到 bootstrap.py 上两级目录
AIGUIBIN_CLI_HOME = os.environ.get(
    "AIGUIBIN_CLI_HOME",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
)

# .agent 目录用于存放应用级数据（历史记录、日志等）
AIGUIBIN_AGENT_DIR = os.path.join(AIGUIBIN_CLI_HOME, ".agent")
os.makedirs(AIGUIBIN_AGENT_DIR, exist_ok=True)
os.makedirs(os.path.join(AIGUIBIN_AGENT_DIR, "logs"), exist_ok=True)

# 目录和缓存路径
GIT_DIR = os.path.join(AIGUIBIN_CLI_HOME, "git")
NODE_DIR = os.path.join(AIGUIBIN_CLI_HOME, "node")
CONFIG_DIR = os.path.join(AIGUIBIN_CLI_HOME, "config")
VERSIONS_CACHE = os.path.join(CONFIG_DIR, "runtime-versions.json")

# npmmirror API 端点
GIT_API_URL = "https://registry.npmmirror.com/-/binary/git-for-windows/"
NODE_API_URL = "https://registry.npmmirror.com/-/binary/node/latest-v22.x/"

# 缓存有效期（秒）：7 天
CACHE_TTL = 7 * 24 * 3600


def _print(msg: str = "") -> None:
    """打印消息（不依赖 rich，bootstrap 可能在 rich 安装前运行）并写入日志"""
    print(msg, flush=True)

    # 同时写入 bootstrap.log
    try:
        log_file = os.path.join(AIGUIBIN_AGENT_DIR, "logs", "bootstrap.log")
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"[{timestamp}] {msg}\n")
    except Exception:
        pass  # 日志写入失败不影响主流程


def bootstrap_log(level: str, message: str) -> None:
    """
    写入 bootstrap 日志到 .agent/logs/bootstrap.log

    Args:
        level: 日志级别（INFO, WARNING, ERROR）
        message: 日志消息
    """
    try:
        log_file = os.path.join(AIGUIBIN_AGENT_DIR, "logs", "bootstrap.log")
        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"[{timestamp}] [{level}] {message}\n")
    except Exception:
        pass


def load_cached_versions() -> dict | None:
    """
    从缓存文件加载版本号

    Returns:
        包含 git_version, git_tag, node_version 的字典；
        缓存过期或不存在则返回 None
    """
    if not os.path.isfile(VERSIONS_CACHE):
        return None
    try:
        with open(VERSIONS_CACHE, "r", encoding="utf-8") as f:
            data = json.load(f)
        # 检查缓存是否过期
        cache_time = data.get("cache_time", 0)
        if time.time() - cache_time > CACHE_TTL:
            return None
        if "git_version" in data and "git_tag" in data and "node_version" in data:
            return data
        return None
    except Exception:
        return None


def save_cached_versions(git_version: str, git_tag: str, node_version: str) -> None:
    """
    保存版本号到缓存文件

    Args:
        git_version: Git 基础版本号（如 "2.45.0"）
        git_tag: Git 完整标签（如 "v2.45.0.windows.1"）
        node_version: Node.js 版本号（如 "v22.11.0"）
    """
    os.makedirs(CONFIG_DIR, exist_ok=True)
    data = {
        "git_version": git_version,
        "git_tag": git_tag,
        "node_version": node_version,
        "cache_time": time.time(),
    }
    try:
        with open(VERSIONS_CACHE, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        _print(f"  [警告] 缓存版本号失败: {e}")


def query_latest_git_version() -> tuple[str, str]:
    """
    从 npmmirror 查询最新 Git for Windows 版本号

    npmmirror 返回 JSON 数组，每个元素包含 name 字段（如 "v2.45.0.windows.1/"）。
    过滤掉 rc/preview 预发布版本，取最新稳定版。

    Returns:
        (base_version, full_tag) 元组，如 ("2.45.0", "v2.45.0.windows.1")
    """
    _print("  查询最新 Git 版本...")
    try:
        req = urllib.request.Request(
            GIT_API_URL, headers={"User-Agent": "AIguibinCLI-Bootstrap"}
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))

        versions: list[tuple[tuple[int, ...], str, str]] = []
        for item in data:
            name = item.get("name", "")
            # 格式: v2.45.0.windows.1/
            if not (name.startswith("v") and ".windows." in name):
                continue
            tag = name.strip("/")
            # 排除 rc/preview 预发布版本
            lower_tag = tag.lower()
            if "rc" in lower_tag or "preview" in lower_tag or "beta" in lower_tag:
                continue
            # 提取基础版本号: v2.45.0.windows.1 → 2.45.0
            base_ver = tag.lstrip("v").split(".windows.")[0]
            # 构建可排序的元组: (2, 45, 0, 1)
            parts: list[int] = []
            for part in base_ver.split("."):
                if part.isdigit():
                    parts.append(int(part))
            # 追加 windows 子版本号
            win_part = tag.split(".windows.")
            if len(win_part) > 1 and win_part[1].isdigit():
                parts.append(int(win_part[1]))
            else:
                parts.append(0)
            versions.append((tuple(parts), base_ver, tag))

        if not versions:
            _print("  [错误] 未找到 Git 稳定版本")
            sys.exit(1)

        # 按版本号排序，取最后一个（最新）
        versions.sort(key=lambda x: x[0])
        _, latest_base, latest_tag = versions[-1]
        _print(f"  最新 Git 版本: {latest_tag}")
        return latest_base, latest_tag
    except SystemExit:
        raise
    except Exception as e:
        _print(f"  [错误] 查询 Git 版本失败: {e}")
        sys.exit(1)


def query_latest_node_version() -> str:
    """
    从 npmmirror 查询最新 Node.js LTS 版本号

    npmmirror 的 latest-v22.x/ 端点返回 JSON 数组（目录文件列表），
    每个元素含 name 字段（如 "node-v22.11.0-win-x64.zip"）。
    从文件名中提取版本号。

    Returns:
        版本号字符串（如 "v22.11.0"），含 v 前缀
    """
    _print("  查询最新 Node.js 版本...")
    try:
        req = urllib.request.Request(
            NODE_API_URL, headers={"User-Agent": "AIguibinCLI-Bootstrap"}
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))

        # API 返回的是文件列表数组，从中提取版本号
        # 文件名格式: node-v22.11.0-win-x64.zip
        versions_found: list[str] = []
        if isinstance(data, list):
            for item in data:
                name = item.get("name", "") if isinstance(item, dict) else ""
                # 匹配 node-vXX.XX.X-win-x64.zip
                if name.startswith("node-v") and name.endswith("-win-x64.zip"):
                    # 提取 v22.11.0 部分
                    # node-v22.11.0-win-x64.zip → v22.11.0
                    parts = name.split("-")
                    # parts = ["node", "v22.11.0", "win", "x64.zip"]
                    if len(parts) >= 2:
                        ver = parts[1]
                        if ver.startswith("v") and ver[1:].split(".")[0].isdigit():
                            versions_found.append(ver)
        elif isinstance(data, dict):
            # 某些 API 可能返回 dict 格式
            ver = data.get("version", "")
            if ver:
                versions_found.append(ver)

        if not versions_found:
            _print("  [错误] 未找到 Node.js 版本信息")
            sys.exit(1)

        # 按版本号排序取最新（排除预发布版本）
        def version_key(v: str) -> tuple:
            """将 v22.11.0 转为 (22, 11, 0) 用于排序"""
            nums = v.lstrip("v").split(".")
            return tuple(int(n) for n in nums if n.isdigit())

        # 过滤掉预发布版本（含 -rc, -beta 等）
        stable_versions = [v for v in versions_found if "-" not in v]
        if not stable_versions:
            stable_versions = versions_found

        stable_versions.sort(key=version_key)
        version = stable_versions[-1]  # 取最新
        _print(f"  最新 Node.js 版本: {version}")
        return version  # v22.11.0
    except SystemExit:
        raise
    except Exception as e:
        _print(f"  [错误] 查询 Node.js 版本失败: {e}")
        sys.exit(1)


def get_versions() -> tuple[str, str, str]:
    """
    获取 Git 和 Node.js 版本号（优先缓存，否则查询 API）

    Returns:
        (git_version, git_tag, node_version) 元组
    """
    cached = load_cached_versions()
    if cached:
        _print(
            f"  使用缓存版本: Git {cached['git_version']}, "
            f"Node.js {cached['node_version']}"
        )
        return cached["git_version"], cached["git_tag"], cached["node_version"]

    git_ver, git_tag = query_latest_git_version()
    node_ver = query_latest_node_version()
    save_cached_versions(git_ver, git_tag, node_ver)
    return git_ver, git_tag, node_ver


def download_file(url: str, dest: str) -> None:
    """
    下载文件并显示进度条

    Args:
        url: 下载 URL
        dest: 本地保存路径
    """
    _print(f"  下载: {url}")
    try:
        req = urllib.request.Request(
            url, headers={"User-Agent": "AIguibinCLI-Bootstrap"}
        )
        with urllib.request.urlopen(req, timeout=300) as resp:
            total = int(resp.headers.get("Content-Length", 0))
            downloaded = 0
            chunk_size = 65536
            with open(dest, "wb") as f:
                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total > 0:
                        pct = downloaded * 100 // total
                        bar_len = 30
                        filled = bar_len * downloaded // total
                        bar = "=" * filled + " " * (bar_len - filled)
                        sys.stdout.write(
                            f"\r  [{bar}] {pct}% "
                            f"({downloaded // 1024}KB/{total // 1024}KB)"
                        )
                        sys.stdout.flush()
            _print("")  # 换行
        _print(f"  完成: {dest}")
    except Exception as e:
        _print(f"\n  [错误] 下载失败: {e}")
        if os.path.isfile(dest):
            os.remove(dest)
        sys.exit(1)


def ensure_git(git_version: str, git_tag: str) -> None:
    """
    检测并下载 PortableGit

    检测 AIGUIBIN_CLI_HOME/git/usr/bin/bash.exe，缺失则下载 .7z.exe 自解压包
    并静默解压到 git/ 目录。

    Args:
        git_version: Git 基础版本号（如 "2.45.0"）
        git_tag: Git 完整标签（如 "v2.45.0.windows.1"）
    """
    bash_path = os.path.join(GIT_DIR, "usr", "bin", "bash.exe")
    if os.path.isfile(bash_path):
        _print("  [OK] Git Bash 已存在，跳过")
        return

    _print("  Git Bash 未找到，开始下载 PortableGit...")

    # 构建下载 URL 和文件名
    # URL: https://registry.npmmirror.com/-/binary/git-for-windows/v2.45.0.windows.1/PortableGit-2.45.0-64-bit.7z.exe
    sfx_filename = f"PortableGit-{git_version}-64-bit.7z.exe"
    sfx_url = (
        f"https://registry.npmmirror.com/-/binary/git-for-windows/"
        f"{git_tag}/{sfx_filename}"
    )
    sfx_path = os.path.join(AIGUIBIN_CLI_HOME, sfx_filename)

    # 下载自解压包
    download_file(sfx_url, sfx_path)

    # 静默解压到 git/
    _print(f"  解压 PortableGit 到 {GIT_DIR}...")
    try:
        result = subprocess.run(
            [sfx_path, "-y", f"-o{GIT_DIR}"],
            capture_output=True,
            timeout=120,
        )
        if result.returncode != 0:
            _print(
                f"  [错误] PortableGit 解压失败 "
                f"(exit code: {result.returncode})"
            )
            if result.stderr:
                stderr_text = result.stderr.decode("utf-8", errors="replace")
                _print(f"  stderr: {stderr_text[:500]}")
            sys.exit(1)
    except SystemExit:
        raise
    except Exception as e:
        _print(f"  [错误] 解压异常: {e}")
        sys.exit(1)
    finally:
        # 清理自解压包
        if os.path.isfile(sfx_path):
            os.remove(sfx_path)

    # 验证
    if not os.path.isfile(bash_path):
        _print(f"  [错误] 解压后未找到 bash.exe: {bash_path}")
        sys.exit(1)
    _print("  [OK] PortableGit 安装完成")


def ensure_node(node_version: str) -> None:
    """
    检测并下载 Node.js 便携版

    检测 AIGUIBIN_CLI_HOME/node/node.exe，缺失则下载 zip 并扁平化解压到 node/。

    Args:
        node_version: Node.js 版本号（如 "v22.11.0"）
    """
    node_path = os.path.join(NODE_DIR, "node.exe")
    if os.path.isfile(node_path):
        _print("  [OK] Node.js 已存在，跳过")
        return

    _print("  Node.js 未找到，开始下载...")

    # 构建下载 URL
    # URL: https://registry.npmmirror.com/-/binary/node/v22.11.0/node-v22.11.0-win-x64.zip
    zip_filename = f"node-{node_version}-win-x64.zip"
    zip_url = (
        f"https://registry.npmmirror.com/-/binary/node/"
        f"{node_version}/{zip_filename}"
    )
    zip_path = os.path.join(AIGUIBIN_CLI_HOME, zip_filename)

    # 下载 zip
    download_file(zip_url, zip_path)

    # 解压到 AIGUIBIN_CLI_HOME（解压后会产生 node-vXX.XX.X-win-x64/ 目录）
    extract_dir = os.path.join(AIGUIBIN_CLI_HOME, f"node-{node_version}-win-x64")
    _print("  解压 Node.js...")
    try:
        with zipfile.ZipFile(zip_path) as z:
            z.extractall(AIGUIBIN_CLI_HOME)
    except Exception as e:
        _print(f"  [错误] Node.js 解压失败: {e}")
        sys.exit(1)
    finally:
        # 清理 zip
        if os.path.isfile(zip_path):
            os.remove(zip_path)

    # 扁平化：重命名 node-vXX.XX.X-win-x64/ → node/
    if os.path.isdir(extract_dir):
        # 如果 node/ 已存在，先删除
        if os.path.isdir(NODE_DIR):
            shutil.rmtree(NODE_DIR, ignore_errors=True)
        try:
            # 使用 shutil.move 替代 os.rename
            # os.rename 在 Windows 上可能因文件锁/权限问题失败 (WinError 5)
            shutil.move(extract_dir, NODE_DIR)
        except Exception as e:
            _print(f"  [错误] 重命名 Node.js 目录失败: {e}")
            _print(f"  尝试手动重命名: {extract_dir} → {NODE_DIR}")
            sys.exit(1)
    else:
        _print(f"  [错误] 解压后未找到目录: {extract_dir}")
        sys.exit(1)

    # 验证
    if not os.path.isfile(node_path):
        _print(f"  [错误] 安装后未找到 node.exe: {node_path}")
        sys.exit(1)
    _print("  [OK] Node.js 安装完成")


def main() -> None:
    """主入口"""
    bootstrap_log("INFO", "Bootstrap 开始")
    _print("[bootstrap] 检查运行时环境...")
    _print(f"  AIGUIBIN_CLI_HOME: {AIGUIBIN_CLI_HOME}")
    _print(f"  AIGUIBIN_AGENT_DIR: {AIGUIBIN_AGENT_DIR}")

    # 获取版本号（优先缓存）
    git_version, git_tag, node_version = get_versions()

    # 确保 Git
    _print()
    _print("[bootstrap] 检查 Git Bash...")
    ensure_git(git_version, git_tag)

    # 确保 Node.js
    _print()
    _print("[bootstrap] 检查 Node.js...")
    ensure_node(node_version)

    _print()
    _print("[bootstrap] 运行时环境就绪")
    bootstrap_log("INFO", "Bootstrap 完成，运行时环境就绪")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:
        bootstrap_log("ERROR", f"Bootstrap 致命错误: {e}")
        _print(f"[bootstrap] 致命错误: {e}")
        sys.exit(1)
