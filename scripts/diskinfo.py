#!/usr/bin/env python
"""
/diskinfo - 查看磁盘空间信息

用法:
  /diskinfo
"""

import os
import platform
import subprocess
import sys


def main():
    aiguibin_output_dir = os.environ.get("AIGUIBIN_OUTPUT_DIR", ".")
    aiguibin_workspace = os.environ.get("AIGUIBIN_WORKSPACE", os.getcwd())

    print("=" * 50)
    print("  Disk Space Information")
    print("=" * 50)
    print()

    if platform.system() == "Windows":
        _windows_disk_info()
    else:
        _unix_disk_info()

    print()

    # 保存报告
    report_path = os.path.join(aiguibin_output_dir, "diskinfo_report.txt")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("Disk Space Report\n")
        f.write(f"Workspace: {aiguibin_workspace}\n")
    print(f"  Report saved: {report_path}")


def _windows_disk_info():
    """Windows 下获取磁盘信息（PowerShell 优先）"""
    try:
        ps_cmd = (
            'Get-CimInstance Win32_LogicalDisk | '
            'ForEach-Object { '
            '  $freeGB = [math]::Round($_.FreeSpace/1GB, 1); '
            '  $sizeGB = [math]::Round($_.Size/1GB, 1); '
            '  "$($_.DeviceID)  $freeGB GB free / $sizeGB GB total" '
            '}'
        )
        result = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps_cmd],
            capture_output=True, text=True, timeout=15,
            encoding="utf-8", errors="replace"
        )
        for line in result.stdout.strip().split("\n"):
            line = line.strip()
            if line:
                print(f"  {line}")
    except Exception as e:
        print(f"  [ERROR] {e}")


def _unix_disk_info():
    """Linux/macOS 下获取磁盘信息"""
    try:
        result = subprocess.run(
            ["df", "-h"], capture_output=True, text=True, timeout=10
        )
        for line in result.stdout.strip().split("\n"):
            print(f"  {line}")
    except Exception as e:
        print(f"  [ERROR] {e}")


if __name__ == "__main__":
    main()
