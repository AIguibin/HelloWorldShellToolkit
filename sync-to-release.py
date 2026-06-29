#!/usr/bin/env python3
r"""
sync-to-release.py — 将开发目录中的源码/配置/脚本同步到 D:\AIguibinCLI

用法:
    python sync-to-release.py                 # 预览模式（仅显示差异，不执行）
    python sync-to-release.py --apply         # 执行同步
    python sync-to-release.py --apply --diff  # 执行同步并显示每个文件的差异
"""

import argparse
import filecmp
import os
import shutil
import sys
from pathlib import Path

# ─── Windows 控制台 UTF-8 支持 ────────────────────
if sys.platform == "win32":
    os.system("")
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# ─── 配置 ─────────────────────────────────────
SOURCE = Path(__file__).resolve().parent
TARGET = Path("D:/AIguibinCLI")

# 不同步的目录/文件
SKIP_DIRS = {
    "python", "git", "node", "tools",
    ".agent", ".git", "dist", "__pycache__",
    ".vscode", ".idea", ".venv",
}
SKIP_FILES = {
    "sync-to-release.py",  # 不同步自身
}

# 需要从根目录同步的文件（非目录递归）
ROOT_FILES = [
    "aiguibin.py",
    "build.py",
    "install.bat",
    "uninstall.bat",
    "requirements.txt",
    ".gitignore",
    "CLAUDE.md",
]

# 需要递归同步的目录（相对于 SOURCE）
SYNC_DIRS = [
    "core",
    "bin",
    "config",
    "scripts",
]


def should_skip(path: Path) -> bool:
    """判断是否应跳过"""
    parts = path.parts
    for part in parts:
        if part in SKIP_DIRS:
            return True
    if path.name in SKIP_FILES:
        return True
    if path.name.endswith(".pyc") or path.name == ".DS_Store":
        return True
    return False


def collect_files(src_dir: Path) -> list[Path]:
    """收集需要同步的源文件列表"""
    files: list[Path] = []

    # 根目录指定文件
    for fname in ROOT_FILES:
        fpath = src_dir / fname
        if fpath.is_file() and not should_skip(fpath):
            files.append(fpath)

    # 需要递归的目录
    for dirname in SYNC_DIRS:
        d = src_dir / dirname
        if not d.is_dir():
            continue
        for fpath in d.rglob("*"):
            if fpath.is_file() and not should_skip(fpath):
                files.append(fpath)

    return sorted(files)


def compare_and_sync(apply_changes: bool = False, show_diff: bool = False) -> int:
    """
    对比并同步。返回有差异的文件数。
    """
    if not TARGET.is_dir():
        print(f"[错误] 目标目录不存在: {TARGET}")
        return -1

    source_files = collect_files(SOURCE)
    if not source_files:
        print("[提示] 未找到需要同步的文件")
        return 0

    to_update: list[tuple[Path, Path]] = []
    to_create: list[tuple[Path, Path]] = []

    for src in source_files:
        rel = src.relative_to(SOURCE)
        dst = TARGET / rel

        if not dst.exists():
            to_create.append((src, dst))
        elif not filecmp.cmp(str(src), str(dst), shallow=False):
            to_update.append((src, dst))

    # ── 预览模式 ──
    if not apply_changes:
        print("=" * 60)
        print("  同步预览 (开发 → D:\\AIguibinCLI)")
        print("=" * 60)
        print()
        print(f"  开发目录: {SOURCE}")
        print(f"  运行目录: {TARGET}")
        print()

        if to_update:
            print(f"  ── 需更新 ({len(to_update)} 个文件) ──")
            for src, dst in to_update:
                rel = src.relative_to(SOURCE)
                src_size = src.stat().st_size
                dst_size = dst.stat().st_size
                diff = src_size - dst_size
                sign = "+" if diff > 0 else ""
                print(f"    M  {rel}  ({src_size}B  ←  {dst_size}B  {sign}{diff})")
            print()

        if to_create:
            print(f"  ── 需新增 ({len(to_create)} 个文件) ──")
            for src, dst in to_create:
                rel = src.relative_to(SOURCE)
                print(f"    +  {rel}  →  {dst}")
            print()

        total = len(to_update) + len(to_create)
        if total == 0:
            print("  [OK] 已是最新，无需同步")
            print()
        else:
            print(f"  共 {total} 个文件待同步")
            print()
            print("  使用 --apply 执行同步:")
            print("    python sync-to-release.py --apply")
            print()

        return total

    # ── 执行同步 ──
    print("=" * 60)
    print("  执行同步 (开发 → D:\\AIguibinCLI)")
    print("=" * 60)
    print()

    for src, dst in to_update:
        rel = src.relative_to(SOURCE)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f"  M  {rel}")
        if show_diff:
            _print_diff(src, dst)

    for src, dst in to_create:
        rel = src.relative_to(SOURCE)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        print(f"  +  {rel}")

    total = len(to_update) + len(to_create)
    print()
    if total == 0:
        print("  [OK] 已是最新，无文件需要同步")
    else:
        print(f"  [OK] 同步完成 ({total} 个文件)")
    print()

    return total


def _print_diff(src: Path, dst: Path):
    """显示文件差异摘要"""
    try:
        src_text = src.read_text(encoding="utf-8", errors="replace")
        dst_text = dst.read_text(encoding="utf-8", errors="replace")
        src_lines = src_text.splitlines()
        dst_lines = dst_text.splitlines()
        added = max(0, len(src_lines) - len(dst_lines))
        removed = max(0, len(dst_lines) - len(src_lines))
        if added or removed:
            print(f"       行变更: +{added}/-{removed}")
    except Exception:
        pass


def main():
    parser = argparse.ArgumentParser(
        description="将开发目录中的源码/配置/脚本同步到 D:\\AIguibinCLI"
    )
    parser.add_argument(
        "--apply", action="store_true",
        help="执行实际同步（默认仅预览）",
    )
    parser.add_argument(
        "--diff", action="store_true",
        help="--apply 时显示每个文件的行数变更",
    )
    args = parser.parse_args()

    result = compare_and_sync(apply_changes=args.apply, show_diff=args.diff)

    if result < 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
