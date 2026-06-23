#!/usr/bin/env python3
"""
依赖管理示例脚本

展示如何在用户脚本中使用 AIguibinCLI 的依赖管理功能
"""

import os
import sys

def example_python_dependency_usage():
    """Python 依赖使用示例"""
    print("=== Python 依赖使用示例 ===")

    # 获取环境变量
    python_path = os.environ.get("AIGUIBIN_PYTHON", "python")
    site_packages = os.environ.get("AIGUIBIN_SITE_PACKAGES", "")

    # 使用已安装的包
    try:
        import rich
        from rich.console import Console

        console = Console()
        console.print("[green]✓[/green] rich 包可用")

        # 示例：使用 rich 输出
        console.print("[bold]Hello from AIguibinCLI dependency management![/bold]")

    except ImportError:
        print("[red]✗[/red] rich 包未安装")
        print("请运行: /install-python rich")

def example_node_dependency_usage():
    """Node.js 依赖使用示例"""
    print("\n=== Node.js 依赖使用示例 ===")

    # 检查 Node.js 是否可用
    node_path = os.environ.get("AIGUIBIN_NODE", "node")

    # 示例：调用 node 脚本
    print(f"Node.js 路径: {node_path}")

    # 如果安装了 TypeScript
    ts_path = os.path.join(node_path, "node_modules", ".bin", "tsc.cmd")
    if os.path.exists(ts_path):
        print("[green]✓[/green] TypeScript 可用")
    else:
        print("[yellow]![/yellow] TypeScript 未安装")
        print("请运行: /install-node --global typescript")

def example_shell_tool_usage():
    """Shell 工具使用示例"""
    print("\n=== Shell 工具使用示例 ===")

    # 检查自定义工具
    tools_dir = os.environ.get("AIGUIBIN_TOOLS_DIR", "tools")
    binaries_dir = os.path.join(tools_dir, "binaries")

    # 示例：检查 ripgrep 工具
    rg_path = os.path.join(binaries_dir, "rg.exe")
    if os.path.exists(rg_path):
        print("[green]✓[/green] ripgrep 工具可用")
        print(f"路径: {rg_path}")
    else:
        print("[yellow]![/yellow] ripgrep 工具未安装")
        print("请运行: /add-tool https://github.com/BurntSushi/ripgrep/releases/ rg.exe")

def example_dependency_detection():
    """依赖检测示例"""
    print("\n=== 依赖检测示例 ===")

    dependencies = {
        "rich": "Terminal UI",
        "pyyaml": "YAML parser",
        "pandas": "Data analysis",
        "numpy": "Numerical computing",
        "requests": "HTTP library"
    }

    missing_deps = []
    available_deps = []

    for dep, description in dependencies.items():
        try:
            __import__(dep)
            available_deps.append((dep, description))
        except ImportError:
            missing_deps.append((dep, description))

    print(f"\n可用的依赖 ({len(available_deps)}):")
    for dep, desc in available_deps:
        print(f"  ✓ {dep:15} - {desc}")

    if missing_deps:
        print(f"\n缺失的依赖 ({len(missing_deps)}):")
        for dep, desc in missing_deps:
            print(f"  ✗ {dep:15} - {desc}")

        print("\n安装缺失的依赖:")
        missing_names = [dep for dep, _ in missing_deps]
        print(f"  /install-python {' '.join(missing_names)}")

def example_config_file_usage():
    """配置文件使用示例"""
    print("\n=== 配置文件使用示例 ===")

    config_dir = os.environ.get("AIGUIBIN_CLI_HOME", "")
    deps_config_dir = os.path.join(config_dir, "config", "dependencies")

    python_config = os.path.join(deps_config_dir, "python-dependencies.yaml")
    node_config = os.path.join(deps_config_dir, "node-dependencies.json")
    tools_config = os.path.join(deps_config_dir, "shell-tools.yaml")

    configs = {
        "Python": python_config,
        "Node.js": node_config,
        "Shell Tools": tools_config
    }

    print("\n依赖配置文件:")
    for name, path in configs.items():
        if os.path.exists(path):
            print(f"  ✓ {name:12} - {path}")
        else:
            print(f"  ✗ {name:12} - {path} (未找到)")

def example_log_monitoring():
    """日志监控示例"""
    print("\n=== 日志监控示例 ===")

    agent_dir = os.environ.get("AIGUIBIN_AGENT_DIR", "")
    log_file = os.path.join(agent_dir, "logs", "dependencies.log")

    if os.path.exists(log_file):
        print(f"[green]✓[/green] 依赖日志文件存在: {log_file}")

        # 读取最后几行
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                if lines:
                    print(f"\n最近的 {min(5, len(lines))} 条日志:")
                    for line in lines[-5:]:
                        print(f"  {line.strip()}")
        except Exception as e:
            print(f"[red]✗[/red] 读取日志失败: {e}")
    else:
        print(f"[yellow]![/yellow] 依赖日志文件不存在: {log_file}")
        print("日志将在首次依赖操作时创建")

def main():
    """主函数"""
    print("AIguibinCLI 依赖管理系统示例\n")
    print("=" * 50)

    # 获取环境变量
    print("\n环境变量:")
    print(f"  AIGUIBIN_CLI_HOME: {os.environ.get('AIGUIBIN_CLI_HOME', 'N/A')}")
    print(f"  AIGUIBIN_AGENT_DIR: {os.environ.get('AIGUIBIN_AGENT_DIR', 'N/A')}")
    print(f"  AIGUIBIN_PYTHON: {os.environ.get('AIGUIBIN_PYTHON', 'N/A')}")
    print(f"  AIGUIBIN_NODE: {os.environ.get('AIGUIBIN_NODE', 'N/A')}")

    # 运行示例
    example_python_dependency_usage()
    example_node_dependency_usage()
    example_shell_tool_usage()
    example_dependency_detection()
    example_config_file_usage()
    example_log_monitoring()

    print("\n" + "=" * 50)
    print("示例运行完成！")
    print("\n更多信息请参考:")
    print("  /dep-config    - 查看依赖配置")
    print("  /list-python   - 查看 Python 包")
    print("  /list-node     - 查看 Node.js 包")
    print("  /list-tools    - 查看工具")

if __name__ == "__main__":
    main()