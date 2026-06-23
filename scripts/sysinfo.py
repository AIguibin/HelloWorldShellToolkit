#!/usr/bin/env python3
"""
/sysinfo - 显示系统信息

用法:
  /sysinfo
  /sysinfo --section=python
  /sysinfo --section=env
"""

import argparse
import os
import platform
import sys


def show_system():
    print(f"  OS: {platform.system()} {platform.release()}")
    print(f"  Platform: {platform.platform()}")
    print(f"  Architecture: {platform.machine()}")
    print(f"  Processor: {platform.processor() or 'N/A'}")
    print(f"  Node: {platform.node()}")
    print(f"  Python Version: {platform.python_version()}")
    print(f"  Python Implementation: {platform.python_implementation()}")


def show_python():
    print(f"  Version: {sys.version}")
    print(f"  Executable: {sys.executable}")
    print(f"  Prefix: {sys.prefix}")
    print(f"  Path:")
    for p in sys.path[:5]:
        print(f"    - {p}")
    if len(sys.path) > 5:
        print(f"    ... and {len(sys.path) - 5} more")


def show_env():
    interesting = [
        "PATH", "HOME", "USER", "SHELL", "LANG", "LC_ALL",
        "PYTHONPATH", "VIRTUAL_ENV", "CONDA_DEFAULT_ENV",
        "AIGUIBIN_TASK_ID", "AIGUIBIN_TASK_DIR", "AIGUIBIN_OUTPUT_DIR",
    ]
    print("  Environment Variables:")
    for key in sorted(interesting):
        value = os.environ.get(key, "(not set)")
        if len(str(value)) > 80:
            value = str(value)[:77] + "..."
        print(f"    {key} = {value}")


def main():
    parser = argparse.ArgumentParser(description="系统信息脚本")
    parser.add_argument("--section", default="all",
                        choices=["all", "system", "python", "env"],
                        help="显示的模块")
    args = parser.parse_args()

    print(f"=" * 50)
    print(f"  System Information")
    print(f"=" * 50)
    print()

    if args.section in ("all", "system"):
        print("  --- System ---")
        show_system()
        print()

    if args.section in ("all", "python"):
        print("  --- Python ---")
        show_python()
        print()

    if args.section in ("all", "env"):
        print("  --- Environment ---")
        show_env()
        print()


if __name__ == "__main__":
    main()
