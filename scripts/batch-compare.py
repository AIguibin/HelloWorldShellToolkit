#!/usr/bin/env python3
"""
batch-compare.py — 批量对比两个目录下所有 Excel 文件

用法:
    python batch-compare.py <基板目录> <对比目录> [-o 输出目录]

示例:
    python batch-compare.py ./config_v1 ./config_v2 -o ./diff-output

匹配规则:
    同一子目录下，优先精确匹配 {name}.v1.{ext}，否则按文件名相似度模糊匹配。
"""

import argparse
import sys
import subprocess
from pathlib import Path
from difflib import SequenceMatcher

EXCEL_EXTS = {".xls", ".xlsx"}
SIMILARITY_THRESHOLD = 0.5


# ── 匹配逻辑 ─────────────────────────────────────────

def find_best_match(base_file: Path, candidates: list[Path]) -> Path | None:
    """
    为基板文件在候选列表中找到最佳匹配。
    策略1: 精确模式  {stem}.v1{ext}
    策略2: 模糊匹配  SequenceMatcher 相似度
    """
    stem = base_file.stem
    ext = base_file.suffix

    # 策略1：精确模式
    candidate = f"{stem}.v1{ext}"
    for cf in candidates:
        if cf.name == candidate:
            return cf

    # 策略2：模糊匹配
    best, best_score = None, 0.0
    for cf in candidates:
        score = SequenceMatcher(None, base_file.name, cf.name).ratio()
        if score > best_score:
            best_score = score
            best = cf

    if best_score >= SIMILARITY_THRESHOLD:
        return best
    return None


# ── 收集待对比文件对 ────────────────────────────────

def collect_pairs(dir_a: Path, dir_b: Path) -> list[tuple[Path, Path, str]]:
    """返回 [(A路径, B路径, 子目录名), ...]"""
    pairs = []

    for subdir in sorted(dir_a.iterdir()):
        if not subdir.is_dir():
            continue
        category = subdir.name
        subdir_b = dir_b / category

        if not subdir_b.is_dir():
            print(f"  [跳过] B 目录中不存在子目录: {category}/")
            continue

        files_a = sorted(f for f in subdir.iterdir() if f.is_file())
        files_b = sorted(f for f in subdir_b.iterdir() if f.is_file())

        for fa in files_a:
            if fa.suffix.lower() not in EXCEL_EXTS:
                print(f"  [跳过] 非 Excel: {fa.relative_to(dir_a.parent)}")
                continue

            match = find_best_match(fa, files_b)
            if match is None:
                print(f"  [警告] 未匹配到对应文件: {fa.relative_to(dir_a.parent)}")
                continue

            pairs.append((fa, match, category))
            print(f"  [配对] {fa.name}  ⇄  {match.name}")

    return pairs


# ── 单个对比执行 ─────────────────────────────────────

def run_one(file_a: Path, file_b: Path, out_dir: Path, category: str, diff_only: bool = False) -> bool:
    """执行一对文件的对比，返回是否成功。"""
    cat_dir = out_dir / category
    cat_dir.mkdir(parents=True, exist_ok=True)

    output_path = cat_dir / f"{file_a.stem}.xlsx"

    script = Path(__file__).resolve().parent / "aiguibin-compare-excel.py"

    cmd = [
        sys.executable,
        str(script),
        str(file_a),
        str(file_b),
        "-o", str(output_path),
    ]
    if diff_only:
        cmd.append("--diff-only")

    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")

    if result.returncode != 0:
        err = result.stderr.strip() or result.stdout.strip()
        print(f"    ✗ 失败 → {err[-300:]}")
        return False

    outputs = []
    if output_path.exists():
        outputs.append(output_path.name)
    md_path = cat_dir / f"{file_a.stem}_structured_diff.md"
    if md_path.exists():
        outputs.append(md_path.name)

    print(f"    ✓ 完成 → {', '.join(outputs)}")
    return True


# ── 主入口 ──────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="批量对比两个目录下所有 Excel 文件，按子目录一一配对并生成差异报告"
    )
    parser.add_argument(
        "dir_a", nargs="?", default=None,
        help="基板目录（基准版本）— 位置参数或 --dir-a",
    )
    parser.add_argument(
        "dir_b", nargs="?", default=None,
        help="对比目录（新版本）— 位置参数或 --dir-b",
    )
    parser.add_argument(
        "--dir-a", dest="dir_a_opt", default=None,
        help="基板目录（基准版本）",
    )
    parser.add_argument(
        "--dir-b", dest="dir_b_opt", default=None,
        help="对比目录（新版本）",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="输出目录（默认: ./batch-compare-output）",
    )
    parser.add_argument(
        "--diff-only", action="store_true",
        help="仅输出有差异的行（传递至 aiguibin-compare-excel.py）",
    )

    args = parser.parse_args()

    dir_a = Path(args.dir_a_opt or args.dir_a).resolve() if (args.dir_a_opt or args.dir_a) else None
    dir_b = Path(args.dir_b_opt or args.dir_b).resolve() if (args.dir_b_opt or args.dir_b) else None

    if not dir_a:
        print("[错误] 缺少基板目录（位置参数1 或 --dir-a）")
        sys.exit(1)
    if not dir_b:
        print("[错误] 缺少对比目录（位置参数2 或 --dir-b）")
        sys.exit(1)
    out_dir = Path(args.output).resolve() if args.output else Path.cwd() / "batch-compare-output"

    if not dir_a.is_dir():
        print(f"[错误] A 目录不存在: {dir_a}")
        sys.exit(1)
    if not dir_b.is_dir():
        print(f"[错误] B 目录不存在: {dir_b}")
        sys.exit(1)

    print("=" * 60)
    print("  批量 Excel 对比工具")
    print("=" * 60)
    print()
    print(f"  基板目录 (A): {dir_a}")
    print(f"  对比目录 (B): {dir_b}")
    print(f"  输出目录:      {out_dir}")
    if args.diff_only:
        print(f"  模式:          仅差异行")
    print()

    # 1. 配对
    print("── 1. 文件配对 ──")
    pairs = collect_pairs(dir_a, dir_b)
    print(f"  共 {len(pairs)} 对文件待对比\n")

    if not pairs:
        print("[结束] 未找到可对比的文件对。")
        return

    # 2. 对比
    print("── 2. 批量对比 ──")
    success, fail = 0, 0
    for i, (fa, fb, cat) in enumerate(pairs, 1):
        print(f"[{i}/{len(pairs)}] {fa.name}  ⇄  {fb.name}")
        if run_one(fa, fb, out_dir, cat, diff_only=args.diff_only):
            success += 1
        else:
            fail += 1

    # 3. 汇总
    print()
    print("=" * 60)
    print(f"  批量对比完成: 成功 {success}, 失败 {fail}")
    print(f"  输出目录: {out_dir}")
    print("=" * 60)


if __name__ == "__main__":
    main()
