#!/usr/bin/env python3
"""
AIguibin Agent System - 全局命令行 Agent 系统

v3.5 内嵌运行时支持 + 依赖管理:
  - 内嵌 Git Bash / Python / Node.js
  - 运行时检测与路径管理
  - 启动时显示运行时状态

使用方式:
  aiguibin                    # 启动交互式 CLI
  aiguibin /hello             # 直接执行命令
  aiguibin /build --target=release --clean myapp

架构:
  安装目录 (AIGUIBIN_CLI_HOME)     → 程序本体、配置 (config/)、应用数据 (.agent/)
  应用数据目录 (.agent/)           → 历史记录、应用级日志
  工作目录 (cwd)                   → 任务输出、工作空间上下文
"""

import os
import sys

# ─── Windows 控制台 UTF-8 支持 ────────────────────
if sys.platform == "win32":
    os.system("")  # 启用 ANSI 转义
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# ─── 路径解析 ───────────────────────────────────
# aiguibin.py 所在目录即为 AIGUIBIN_CLI_HOME（安装目录）
AIGUIBIN_CLI_HOME = os.path.dirname(os.path.abspath(__file__))
if AIGUIBIN_CLI_HOME not in sys.path:
    sys.path.insert(0, AIGUIBIN_CLI_HOME)

# .agent 目录用于存放应用级数据（历史记录、日志等）
AIGUIBIN_AGENT_DIR = os.path.join(AIGUIBIN_CLI_HOME, ".agent")
os.makedirs(AIGUIBIN_AGENT_DIR, exist_ok=True)
os.makedirs(os.path.join(AIGUIBIN_AGENT_DIR, "logs"), exist_ok=True)

from rich.console import Console

# 使用 force=True 确保 Windows 下也能输出 Unicode
_CONSOLE = Console(force_terminal=True)
from rich.panel import Panel

from core.command_parser import CommandParser
from core.dispatcher import Dispatcher
from core.executor import ScriptExecutor
from core.registry import ScriptRegistry
from core.runtime import RuntimeDetector
from core.task_manager import TaskManager

# ─── readline 兼容处理 ───────────────────────────
try:
    import readline
except ImportError:
    try:
        import pyreadline3 as readline  # type: ignore
    except ImportError:
        readline = None  # type: ignore


# ─── 应用级日志系统 ───────────────────────────
def app_log(level: str, message: str):
    """
    写入应用级日志到 .agent/logs/app.log

    Args:
        level: 日志级别（INFO, WARNING, ERROR）
        message: 日志消息
    """
    import time
    log_file = os.path.join(AIGUIBIN_AGENT_DIR, "logs", "app.log")
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"[{timestamp}] [{level}] {message}\n")
    except Exception as e:
        # 日志写入失败不影响主流程，但至少打印到 stderr
        print(f"日志写入失败: {e}", file=sys.stderr)


BANNER = r"""
[bold cyan]  ___  ___       _         _          _      _       _   
 / _ \|__ \     (_)       (_)        | |    (_)     | | 
| |_| |  ) |     _        | |_  ___   _     _  ___| |__
|  _  | / /     | |       | __|/ _ \ | |   | |/ _ \| '_ \
| | | |/ /_  _  | |  _   | |_| (_) )| |_  | |  __/ |_) |
|_| |_|____| (_)|_| (_)   \___\___/ (_)(_)|_|\___|_.__/
[/bold cyan]
[dim]  AIguibin Agent System v3.5 | /help 查看命令列表[/dim]
"""


def resolve_workspace() -> str:
    """
    解析当前工作空间目录

    优先级:
      1. --workspace 参数
      2. AIGUIBIN_WORKSPACE 环境变量
      3. 当前工作目录 (cwd)
    """
    # 检查命令行中的 --workspace 参数
    for i, arg in enumerate(sys.argv[1:], 1):
        if arg.startswith("--workspace="):
            return os.path.abspath(arg.split("=", 1)[1])
        if arg == "--workspace" and i < len(sys.argv) - 1:
            return os.path.abspath(sys.argv[i + 1])

    # 环境变量
    ws = os.environ.get("AIGUIBIN_WORKSPACE")
    if ws:
        return os.path.abspath(ws)

    # 当前目录
    return os.getcwd()


def create_components(workspace: str, console: Console | None = None):
    """
    创建核心组件

    Args:
        workspace: 工作空间目录（任务输出位置）
        console: Rich Console 实例
    """
    if console is None:
        console = Console(force_terminal=True)

    # 创建 RuntimeDetector 实例
    runtime_detector = RuntimeDetector(AIGUIBIN_CLI_HOME)

    # 安装目录下的资源
    config_path = os.path.join(AIGUIBIN_CLI_HOME, "config", "registry.yaml")
    scripts_dir = os.path.join(AIGUIBIN_CLI_HOME, "scripts")

    # 工作空间下的任务目录
    task_manager = TaskManager(workspace)

    registry = ScriptRegistry(config_path, scripts_dir)
    executor = ScriptExecutor(scripts_dir, AIGUIBIN_CLI_HOME=AIGUIBIN_CLI_HOME)
    dispatcher = Dispatcher(registry, task_manager, executor, console, AIGUIBIN_CLI_HOME=AIGUIBIN_CLI_HOME, AIGUIBIN_AGENT_DIR=AIGUIBIN_AGENT_DIR)
    parser = CommandParser()

    return {
        "console": console,
        "registry": registry,
        "task_manager": task_manager,
        "executor": executor,
        "dispatcher": dispatcher,
        "parser": parser,
        "workspace": workspace,
        "runtime_detector": runtime_detector,
    }


class AiguibinCLI:
    """交互式命令行界面"""

    def __init__(self, workspace: str):
        self.workspace = workspace
        self.components = create_components(workspace)
        self.console = self.components["console"]
        self.dispatcher = self.components["dispatcher"]
        self.parser = self.components["parser"]
        self.registry = self.components["registry"]
        self.runtime_detector = self.components["runtime_detector"]

        # 设置 readline
        self._setup_readline()

    def _setup_readline(self):
        """配置 readline（命令历史与自动补全）"""
        if readline is None:
            return

        # 历史文件存放在 .agent/ 目录（应用级数据）
        history_file = os.path.join(AIGUIBIN_AGENT_DIR, ".aiguibin_history")
        try:
            readline.read_history_file(history_file)
        except FileNotFoundError:
            pass

        # 自动补全：命令名补全 + 文件路径补全
        _all_commands = []
        for cmd in self.registry.list_commands():
            _all_commands.append(f"/{cmd.name}")
        _all_commands += ["/help", "/list", "/status", "/register",
                         "/unregister", "/reload", "/exit", "/quit",
                         "/workspace", "/cd", "/shell", "/install-pkg",
                         "/env", "/doctor"]

        def completer(text, state):
            # 读当前输入行的完整内容和光标位置
            line = readline.get_line_buffer()
            # 如果以 / 开头且光标在第一个 token → 命令名补全
            if line.startswith("/") and " " not in line:
                matches = [c for c in _all_commands if c.startswith(text)]
                if state < len(matches):
                    return matches[state]
                return None
            # 否则 → 文件路径补全（支持含空格的路径用引号包裹）
            import glob as _glob
            # 去掉可能的引号
            clean = text.strip('"').strip("'")
            matches = _glob.glob(clean + "*")
            # 将含空格的路径用引号包裹
            wrapped = []
            for m in matches:
                if " " in m:
                    wrapped.append(f'"{m}"')
                else:
                    wrapped.append(m)
            if state < len(wrapped):
                return wrapped[state]
            return None

        readline.set_completer(completer)
        readline.parse_and_bind("tab: complete")

    def run(self):
        """启动交互式 CLI"""
        self.console.print(BANNER)
        self.console.print(
            f"  [dim]Aiguibin Home: {AIGUIBIN_CLI_HOME}[/dim]\n"
            f"  [dim]Workspace:  {self.workspace}[/dim]"
        )

        # 显示运行时检测状态
        status = self.runtime_detector.check_runtime()
        runtime_info = []
        if status.python_available:
            runtime_info.append(f"[green]Python({status.python_source})[/green]")
        else:
            runtime_info.append("[red]Python(none)[/red]")
        if status.bash_available:
            runtime_info.append(f"[green]Bash({status.bash_source})[/green]")
        else:
            runtime_info.append("[red]Bash(none)[/red]")
        if status.git_available:
            runtime_info.append("[green]Git[/green]")
        else:
            runtime_info.append("[yellow]Git(未安装)[/yellow]")
        if status.node_available:
            runtime_info.append(f"[green]Node({status.node_source})[/green]")
        else:
            runtime_info.append("[dim]Node(--)[/dim]")

        self.console.print(f"  [dim]Runtime:    {' | '.join(runtime_info)}[/dim]")

        # Git 未安装时显示警告
        if not status.git_available:
            self.console.print()
            self.console.print(
                "  [yellow]提示:[/yellow] Git 未安装，/shell 和 /install-pkg 不可用。\n"
                "  [dim]运行 install.bat 安装 Git 和 Node.js。[/dim]"
            )

        self.console.print()

        running = True
        while running:
            try:
                # 提示符显示当前工作空间名称
                ws_name = os.path.basename(self.workspace)
                user_input = input(f" ｡◕‿◕｡aiguibinᶫᵒᵛᵉᵧₒᵤ♥⠊{ws_name}▄︻┻═┳一☠  ").strip()
            except (EOFError, KeyboardInterrupt):
                self.console.print("\n[bold]Bye![/bold]")
                break

            if not user_input:
                continue

            # 非 / 开头的输入提示
            if not user_input.startswith("/"):
                # 尝试作为 shell 命令解释
                if user_input.startswith("!"):
                    self._run_shell(user_input[1:])
                    continue
                self.console.print(
                    "[dim]提示: 命令以 [cyan]/[/cyan] 开头，如 [cyan]/help[/cyan] 查看命令列表[/dim]"
                )
                continue

            # 解析并调度
            parsed = self.parser.parse(user_input)
            running = self.dispatcher.dispatch(parsed)

        # 保存历史
        if readline is not None:
            try:
                history_file = os.path.join(AIGUIBIN_AGENT_DIR, ".aiguibin_history")
                readline.write_history_file(history_file)
            except Exception:
                pass

    def _run_shell(self, cmd: str):
        """执行 shell 命令（! 前缀），优先使用内嵌 Bash"""
        import subprocess

        self.console.print(f"[dim]$ {cmd}[/dim]")

        # 如果 Git Bash 可用，优先用内嵌 bash 执行
        bash_path = self.runtime_detector.get_bash_path()
        if bash_path and self.runtime_detector.get_git_home():
            # 使用内嵌 Git Bash 执行命令
            env = os.environ.copy()
            env["PATH"] = self.runtime_detector.build_path_env()
            env["LANG"] = "zh_CN.UTF-8"
            env["LC_ALL"] = "zh_CN.UTF-8"
            result = subprocess.run(
                [bash_path, "-c", cmd],
                env=env,
                cwd=self.workspace,
            )
        else:
            # 回退到系统 shell
            result = subprocess.run(cmd, shell=True, cwd=self.workspace)

        if result.returncode != 0:
            self.console.print(f"[dim]exit code: {result.returncode}[/dim]")


def run_single(command_str: str, workspace: str | None = None):
    """单次命令执行模式（非交互式）"""
    if workspace is None:
        workspace = resolve_workspace()

    console = Console(force_terminal=True)
    components = create_components(workspace, console)
    parser = components["parser"]
    dispatcher = components["dispatcher"]

    parsed = parser.parse(command_str)
    dispatcher.dispatch(parsed)


def main():
    app_log("INFO", f"AIguibinCLI 启动，安装目录: {AIGUIBIN_CLI_HOME}")
    app_log("INFO", f"应用数据目录: {AIGUIBIN_AGENT_DIR}")

    workspace = resolve_workspace()
    app_log("INFO", f"工作目录: {workspace}")

    # 过滤掉 --workspace 参数
    args = []
    skip_next = False
    for i, arg in enumerate(sys.argv[1:]):
        if skip_next:
            skip_next = False
            continue
        if arg.startswith("--workspace="):
            continue
        if arg == "--workspace":
            skip_next = True
            continue
        args.append(arg)

    if args:
        # 非交互式模式: aiguibin /hello --name=World
        command_str = " ".join(args)
        app_log("INFO", f"执行单次命令: {command_str}")
        run_single(command_str, workspace)
    else:
        # 交互式模式
        app_log("INFO", "启动交互式模式")
        cli = AiguibinCLI(workspace)
        cli.run()

    app_log("INFO", "AIguibinCLI 正常退出")


if __name__ == "__main__":
    main()
