#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AIguibinCLI 打包脚本 (Python 版)
最简单的逻辑：先复制到临时目录（模拟手工 copy），再压缩成 ZIP。
再也不用 Git Bash！
"""

import os
import sys
import shutil
import zipfile
from datetime import datetime
from pathlib import Path

# ─── Windows 控制台 UTF-8 支持 ────────────────────
if sys.platform == "win32":
    os.system("")
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# ─── 配置 ───────────────────────────────
SCRIPT_DIR = Path(__file__).resolve().parent
DIST_DIR = SCRIPT_DIR / "dist"
VERSION = "3.5.1"
PKG_NAME = f"AIguibinCLI-v{VERSION}"

# ─── 目录定义 ────────────────────────────
# 所有包都排除的目录
COMMON_EXCLUDE = {".git", ".agent", "__pycache__", "dist", ".vscode", ".idea", ".venv"}
# lite 包额外排除的目录（运行时由 install.bat 下载）
LITE_EXCLUDE = {"python", "git", "node", "tools"}
# 所有包都排除的文件模式
EXCLUDE_EXTENSIONS = {".pyc", ".pyo", ".7z", ".7z.exe"}
EXCLUDE_FILES = {"Thumbs.db", ".DS_Store"}


def should_exclude(rel_path: str, exclude_dirs: set) -> bool:
    """判断文件是否应排除"""
    parts = rel_path.replace("\\", "/").split("/")
    # 排除指定目录（匹配路径任一段）
    for part in parts:
        if part in exclude_dirs:
            return True
    # 排除指定扩展名
    filename = parts[-1]
    if any(filename.endswith(ext) for ext in EXCLUDE_EXTENSIONS):
        return True
    if filename in EXCLUDE_FILES:
        return True
    return False


def copy_files(src_dir: Path, dst_dir: Path, exclude_dirs: set):
    """复制文件到目标目录（模拟手工 copy）"""
    count = 0
    for root, dirs, files in os.walk(src_dir):
        rel_root = os.path.relpath(root, src_dir)
        if rel_root == ".":
            rel_root = ""

        # 过滤目录
        dirs[:] = [d for d in dirs if d not in exclude_dirs]

        for name in files:
            rel_path = os.path.join(rel_root, name) if rel_root else name
            if should_exclude(rel_path, exclude_dirs):
                continue

            src = os.path.join(root, name)
            dst = os.path.join(dst_dir, rel_path)

            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            count += 1
    return count


def make_zip(src_dir: Path, zip_path: Path, top_folder: str):
    """将源目录打包为 ZIP"""
    with zipfile.ZipFile(str(zip_path), "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(src_dir):
            for name in files:
                full_path = os.path.join(root, name)
                arcname = os.path.join(top_folder, os.path.relpath(full_path, src_dir))
                zf.write(full_path, arcname)

    size_mb = zip_path.stat().st_size / (1024 * 1024)
    return size_mb


def build(pkg_type: str, exclude_dirs: set):
    """构建一个包"""
    print(f"\n{'=' * 60}")
    print(f"  构建 {pkg_type.upper()} 包")
    print(f"{'=' * 60}")

    zip_name = f"{PKG_NAME}-{pkg_type}.zip"
    zip_path = DIST_DIR / zip_name

    # 步骤1：复制到临时目录
    tmp_dir = DIST_DIR / f"_tmp_{pkg_type}"
    print(f"  步骤1: 复制文件...")
    if tmp_dir.exists():
        shutil.rmtree(tmp_dir)
    tmp_dir.mkdir(parents=True, exist_ok=True)

    file_count = copy_files(SCRIPT_DIR, tmp_dir, exclude_dirs)
    print(f"    复制 {file_count} 个文件")

    # 步骤2：打包为 ZIP
    print(f"  步骤2: 压缩为 ZIP...")
    zip_path.unlink(missing_ok=True)
    size_mb = make_zip(tmp_dir, zip_path, PKG_NAME)
    print(f"    ZIP 大小: {size_mb:.2f} MB")

    # 步骤3：清理临时目录
    print(f"  步骤3: 清理临时目录...")
    shutil.rmtree(tmp_dir)

    print(f"  ✅ {pkg_type} 包完成: {zip_path}")
    return zip_path


def main():
    print("=" * 60)
    print(f"  AIguibinCLI v{VERSION} 打包脚本 (Python 版)")
    print("=" * 60)
    print(f"  源目录: {SCRIPT_DIR}")
    print(f"  输出目录: {DIST_DIR}")

    # 清理输出目录
    if DIST_DIR.exists():
        shutil.rmtree(DIST_DIR)
    DIST_DIR.mkdir(parents=True, exist_ok=True)

    start = datetime.now()

    # 构建 lite 包（不含运行时，用户运行 install.bat 下载）
    lite_exclude = COMMON_EXCLUDE | LITE_EXCLUDE
    build("lite", lite_exclude)

    # 构建 full 包（含运行时 python/git/node，开箱即用）
    build("full", COMMON_EXCLUDE)

    elapsed = (datetime.now() - start).total_seconds()
    print(f"\n{'=' * 60}")
    print(f"  ✅ 打包成功！耗时 {elapsed:.1f}s")
    print(f"  输出目录: {DIST_DIR}")
    print(f"{'=' * 60}")

    # 列出产物
    for f in sorted(DIST_DIR.glob("*.zip")):
        size_mb = f.stat().st_size / (1024 * 1024)
        print(f"  {f.name}  -  {size_mb:.2f} MB")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n❌ 打包失败: {e}")
        sys.exit(1)
