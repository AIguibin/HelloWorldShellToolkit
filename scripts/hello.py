#!/usr/bin/env python3
"""
/hello - 向世界问好

用法:
  /hello
  /hello --name=Alice
  /hello --name=World --count=3
"""

import argparse
import os
import sys


def main():
    parser = argparse.ArgumentParser(description="Hello World 脚本")
    parser.add_argument("--name", default="World", help="问候对象名称")
    parser.add_argument("--count", type=int, default=1, help="问候次数")
    args = parser.parse_args()

    # 获取 Aiguibin 注入的环境变量
    task_id = os.environ.get("AIGUIBIN_TASK_ID", "N/A")
    output_dir = os.environ.get("AIGUIBIN_OUTPUT_DIR", ".")

    print(f"=" * 50)
    print(f"  Hello, {args.name}!")
    print(f"=" * 50)
    print()

    for i in range(args.count):
        print(f"  [{i + 1}/{args.count}] Greeting sent to: {args.name}")

    print()
    print(f"  Task ID: {task_id}")
    print(f"  Output Dir: {output_dir}")

    # 在输出目录生成结果文件
    result_path = os.path.join(output_dir, "hello_result.txt")
    with open(result_path, "w", encoding="utf-8") as f:
        f.write(f"Hello, {args.name}!\n")
        f.write(f"Greeted {args.count} time(s)\n")
    print(f"  Result saved: {result_path}")


if __name__ == "__main__":
    main()
