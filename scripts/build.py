#!/usr/bin/env python3
"""
/build - 构建项目

用法:
  /build --target=debug
  /build --target=release --clean
  /build --target=test --env=ci
"""

import argparse
import os
import sys
import time


def main():
    parser = argparse.ArgumentParser(description="项目构建脚本")
    parser.add_argument("--target", required=True,
                        choices=["debug", "release", "test"],
                        help="构建目标")
    parser.add_argument("--env", default="dev", help="环境标识")
    parser.add_argument("--clean", action="store_true", help="构建前清理")
    args = parser.parse_args()

    task_id = os.environ.get("AIGUIBIN_TASK_ID", "N/A")
    output_dir = os.environ.get("AIGUIBIN_OUTPUT_DIR", ".")

    print(f"=" * 50)
    print(f"  Build Started")
    print(f"=" * 50)
    print(f"  Target: {args.target}")
    print(f"  Environment: {args.env}")
    print(f"  Clean: {args.clean}")
    print(f"  Task ID: {task_id}")
    print()

    total_steps = 4 if args.clean else 3
    base_step = 1 if args.clean else 0

    if args.clean:
        print(f"  [1/{total_steps}] Cleaning previous build...")
        time.sleep(0.3)
        print(f"  [1/{total_steps}] Clean complete")

    build_steps = {
        "debug": ["Compiling (debug)", "Linking (debug symbols)", "Generating debug symbols"],
        "release": ["Compiling (optimized)", "Linking (stripped)", "Optimizing binary"],
        "test": ["Compiling test sources", "Linking test binary", "Generating coverage data"],
    }

    for i, step in enumerate(build_steps.get(args.target, ["Unknown target"]), 1):
        step_num = base_step + i
        print(f"  [{step_num}/{total_steps}] {step}...")
        time.sleep(0.3)
        print(f"  [{step_num}/{total_steps}] {step} - OK")

    # 生成构建报告
    report_path = os.path.join(output_dir, "build_report.txt")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(f"Build Report\n")
        f.write(f"{'=' * 40}\n")
        f.write(f"Target: {args.target}\n")
        f.write(f"Environment: {args.env}\n")
        f.write(f"Status: SUCCESS\n")
    print(f"\n  Build report: {report_path}")

    print(f"\n  Build [bold green]SUCCESS[/bold green]")
    sys.exit(0)


if __name__ == "__main__":
    main()
