"""
命令调度器 - 将解析后的命令路由到对应处理器

v3.5 内嵌运行时支持 + 依赖管理:
  - /shell    → 启动内嵌 Git Bash 交互式 Shell
  - /install-pkg → 通过 npm 全局安装包
  - /env      → 显示所有运行时路径信息
  - /doctor   → 诊断运行时完整性
  - 注入 AIGUIBIN_BASH, AIGUIBIN_PYTHON 环境变量

v3.5 依赖管理支持:
  - /list-python, /install-python, /update-python, /uninstall-python → Python依赖管理
  - /list-node, /install-node, /update-node, /uninstall-node → Node.js依赖管理
  - /list-tools, /add-tool, /remove-tool → Shell工具管理
  - /dep-config, /dep-sync → 依赖配置管理
"""

import os
import subprocess

from rich.panel import Panel
from rich.table import Table

from .command_parser import ParsedCommand
from .executor import ScriptExecutor
from .registry import CommandDef, ScriptRegistry
from .runtime import RuntimeDetector
from .task_manager import TaskManager
from .dependency_manager import create_dependency_managers


class Dispatcher:
    """命令调度器"""

    def __init__(self, registry: ScriptRegistry, task_manager: TaskManager,
                 executor: ScriptExecutor, console, AIGUIBIN_CLI_HOME: str = "",
                 AIGUIBIN_AGENT_DIR: str = ""):
        self.registry = registry
        self.task_manager = task_manager
        self.executor = executor
        self.console = console
        self.AIGUIBIN_CLI_HOME = AIGUIBIN_CLI_HOME
        self.AIGUIBIN_AGENT_DIR = AIGUIBIN_AGENT_DIR

        # 创建 RuntimeDetector 实例
        self.runtime_detector = RuntimeDetector(AIGUIBIN_CLI_HOME) if AIGUIBIN_CLI_HOME else None

        # 创建依赖管理器
        if AIGUIBIN_CLI_HOME and AIGUIBIN_AGENT_DIR:
            python_path = self.runtime_detector.get_python_path() if self.runtime_detector else None
            node_exe = self.runtime_detector.get_node_path() if self.runtime_detector else None
            node_home = os.path.dirname(node_exe) if node_exe else None
            self.dep_managers = create_dependency_managers(
                AIGUIBIN_CLI_HOME, AIGUIBIN_AGENT_DIR, python_path, node_home
            )
        else:
            self.dep_managers = {}

        # 内置命令处理器
        self._builtins = {
            "help": self._cmd_help,
            "list": self._cmd_list,
            "status": self._cmd_status,
            "register": self._cmd_register,
            "unregister": self._cmd_unregister,
            "reload": self._cmd_reload,
            "workspace": self._cmd_workspace,
            "cd": self._cmd_cd,
            "shell": self._cmd_shell,
            "install-pkg": self._cmd_install_pkg,
            "env": self._cmd_env,
            "doctor": self._cmd_doctor,
            "exit": self._cmd_exit,
            "quit": self._cmd_exit,
            # Python 依赖管理
            "list-python": self._cmd_list_python,
            "install-python": self._cmd_install_python,
            "update-python": self._cmd_update_python,
            "uninstall-python": self._cmd_uninstall_python,
            "export-python": self._cmd_export_python,
            # Node.js 依赖管理
            "list-node": self._cmd_list_node,
            "install-node": self._cmd_install_node,
            "update-node": self._cmd_update_node,
            "uninstall-node": self._cmd_uninstall_node,
            # Shell 工具管理
            "list-tools": self._cmd_list_tools,
            "add-tool": self._cmd_add_tool,
            "remove-tool": self._cmd_remove_tool,
            # 依赖配置管理
            "dep-config": self._cmd_dep_config,
            "dep-sync": self._cmd_dep_sync,
        }

    def dispatch(self, parsed: ParsedCommand) -> bool:
        """调度命令，返回是否应继续运行"""
        command = parsed.command

        if not command:
            return True

        # 1. 内置命令
        if command in self._builtins:
            return self._builtins[command](parsed)

        # 2. 注册脚本
        cmd_def = self.registry.get(command)
        if cmd_def:
            return self._execute_script(cmd_def, parsed)

        # 3. 未知命令
        self.console.print(
            f"[bold red]未知命令:[/bold red] [yellow]/{command}[/yellow]"
        )
        self.console.print("输入 [cyan]/help[/cyan] 查看可用命令")
        return True

    def _execute_script(self, cmd_def: CommandDef, parsed: ParsedCommand) -> bool:
        """执行已注册的脚本"""
        # 参数校验
        valid, errors = self.registry.validate_params(
            cmd_def, parsed.kwargs, parsed.flags, parsed.positional_args
        )
        if not valid:
            self.console.print("[bold red]参数校验失败:[/bold red]")
            for err in errors:
                self.console.print(f"  [red]x[/red] {err}")
            return True

        # 创建任务（在工作空间下）
        task_id = self.task_manager.create_task(
            command=parsed.command,
            args={
                "positional": parsed.positional_args,
                "kwargs": parsed.kwargs,
                "flags": list(parsed.flags),
            },
        )
        task_dir = self.task_manager.get_task_dir(task_id)
        self.task_manager.update_status(task_id, "running")

        self.console.print(
            f"[bold green]Task:[/bold green] {task_id}  "
            f"[dim]Log: {os.path.relpath(self.task_manager.get_log_path(task_id), self.task_manager.workspace)}[/dim]"
        )

        # 构建参数列表
        args = self._build_args(parsed)

        self.task_manager.append_log(task_id, f"开始执行: /{parsed.command} {parsed.raw_input}")

        # 构建环境变量，注入内嵌运行时路径
        extra_env = {
            "AIGUIBIN_TASK_ID": task_id,
            "AIGUIBIN_TASK_DIR": task_dir,
            "AIGUIBIN_OUTPUT_DIR": self.task_manager.get_output_dir(task_id),
            "AIGUIBIN_LOG_DIR": os.path.join(task_dir, "logs"),
            "AIGUIBIN_CLI_HOME": self.AIGUIBIN_CLI_HOME,
            "AIGUIBIN_WORKSPACE": self.task_manager.workspace,
        }

        # 注入 AIGUIBIN_BASH 和 AIGUIBIN_PYTHON 环境变量
        if self.runtime_detector:
            bash_path = self.runtime_detector.get_bash_path()
            python_path = self.runtime_detector.get_python_path()
            if bash_path:
                extra_env["AIGUIBIN_BASH"] = bash_path
            if python_path:
                extra_env["AIGUIBIN_PYTHON"] = python_path

        # 执行脚本
        def on_output(line, stream_type):
            if stream_type == "stdout":
                self.console.print(f"  {line}")
            else:
                self.console.print(f"  [dim yellow]{line}[/dim yellow]")
            self.task_manager.append_log(task_id, f"[{stream_type}] {line}")

        result = self.executor.execute(
            script_path=cmd_def.script,
            args=args,
            env_vars=extra_env,
            on_output=on_output,
        )

        # 记录结果
        if result.success:
            self.task_manager.update_status(task_id, "completed")
            self.task_manager.append_log(
                task_id, f"执行成功 (耗时 {result.duration:.2f}s)"
            )
            self.console.print(
                f"[bold green]Done[/bold green] [dim]({result.duration:.2f}s)[/dim]"
            )
        else:
            self.task_manager.update_status(task_id, "failed")
            if result.timed_out:
                self.task_manager.append_log(task_id, f"执行超时")
                self.console.print(f"[bold red]Timeout[/bold red]")
            else:
                self.task_manager.append_log(
                    task_id, f"执行失败 (exit code: {result.return_code})"
                )
                self.console.print(
                    f"[bold red]Failed[/bold red] [dim](exit code: {result.return_code})[/dim]"
                )
            if result.stderr:
                self.console.print(f"[dim red]{result.stderr[:500]}[/dim red]")

        return True

    def _build_args(self, parsed: ParsedCommand) -> list[str]:
        """构建脚本命令行参数"""
        args = list(parsed.positional_args)

        for key, value in parsed.kwargs.items():
            if isinstance(value, bool):
                args.append(f"--{key}" if value else f"--no-{key}")
            elif value is None:
                args.append(f"--{key}=None")
            else:
                args.append(f"--{key}={value}")

        for flag in parsed.flags:
            args.append(f"--{flag}")

        return args

    # ─── 内置命令 ───────────────────────────────────

    def _cmd_help(self, parsed: ParsedCommand) -> bool:
        """显示帮助信息"""
        self.console.print()
        self.console.print(
            Panel(
                "[bold]AIguibin Agent System[/bold] - 全局 Aiguibin 命令系统 v3.5\n\n"
                "用法: [cyan]/<命令>[/cyan] [参数...]\n\n"
                "参数格式:\n"
                "  [green]--key=value[/green]    键值对参数\n"
                "  [green]--flag[/green]         布尔标志（启用）\n"
                "  [green]--no-flag[/green]      布尔标志（禁用）\n"
                "  [green]arg1 arg2[/green]      位置参数\n"
                "  [green]-v[/green]             短标志\n\n"
                "Shell 命令:\n"
                "  [green]!ls -la[/green]        执行 shell 命令",
                title="Help",
                border_style="blue",
            )
        )

        # 内置命令
        builtin_table = Table(title="内置命令", show_header=True, header_style="bold cyan")
        builtin_table.add_column("命令", style="cyan")
        builtin_table.add_column("说明")
        builtin_items = [
            ("/help", "显示帮助信息"),
            ("/list", "列出所有已注册脚本"),
            ("/status", "查看最近任务状态"),
            ("/register", "注册新脚本  /register <name> <script> [desc]"),
            ("/unregister", "取消注册  /unregister <name>"),
            ("/reload", "重新加载配置"),
            ("/workspace", "查看当前工作空间信息"),
            ("/cd <path>", "切换工作空间目录"),
            ("/shell", "启动内嵌 Git Bash 交互式 Shell"),
            ("/install-pkg <pkg>", "通过 npm 全局安装包（需 Node.js）"),
            ("/env", "显示所有运行时路径信息"),
            ("/doctor", "诊断运行时完整性"),
            ("/exit", "退出系统"),
        ]
        for cmd, desc in builtin_items:
            builtin_table.add_row(cmd, desc)
        self.console.print(builtin_table)

        # 注册脚本
        commands = self.registry.list_commands()
        if commands:
            script_table = Table(title="已注册脚本", show_header=True, header_style="bold green")
            script_table.add_column("命令", style="cyan")
            script_table.add_column("脚本", style="green")
            script_table.add_column("说明")
            script_table.add_column("参数", style="dim")
            for cmd in commands:
                params_str = ", ".join(
                    f"{'*' if p.required else ''}{p.flag or p.name}"
                    for p in cmd.params
                )
                script_table.add_row(
                    f"/{cmd.name}", cmd.script, cmd.description, params_str or "-"
                )
            self.console.print(script_table)

        self.console.print()
        return True

    def _cmd_list(self, parsed: ParsedCommand) -> bool:
        """列出所有已注册脚本"""
        commands = self.registry.list_commands()
        if not commands:
            self.console.print("[yellow]暂无已注册脚本[/yellow]")
            self.console.print("使用 [cyan]/register[/cyan] 注册新脚本")
            return True

        table = Table(show_header=True, header_style="bold cyan")
        table.add_column("命令", style="cyan")
        table.add_column("脚本", style="green")
        table.add_column("说明")
        table.add_column("标签", style="dim")
        table.add_column("参数", style="dim")

        for cmd in commands:
            params_str = ", ".join(
                f"{'*' if p.required else ''}{p.flag or p.name}"
                for p in cmd.params
            )
            tags_str = ", ".join(cmd.tags)
            table.add_row(
                f"/{cmd.name}", cmd.script, cmd.description,
                tags_str or "-", params_str or "-"
            )

        self.console.print(table)
        return True

    def _cmd_status(self, parsed: ParsedCommand) -> bool:
        """查看最近任务状态"""
        tasks = self.task_manager.list_tasks()

        if not tasks:
            self.console.print("[yellow]暂无任务记录[/yellow]")
            return True

        table = Table(title="Recent Tasks", show_header=True, header_style="bold cyan")
        table.add_column("Task ID", style="cyan")
        table.add_column("命令", style="green")
        table.add_column("状态")
        table.add_column("创建时间", style="dim")

        for task in tasks:
            status = task.get("status", "unknown")
            status_style = {
                "completed": "[green]completed[/green]",
                "running": "[yellow]running[/yellow]",
                "failed": "[red]failed[/red]",
                "pending": "[dim]pending[/dim]",
            }.get(status, status)
            table.add_row(
                task.get("task_id", ""),
                f"/{task.get('command', '')}",
                status_style,
                task.get("created_at", "")[:19],
            )

        self.console.print(table)
        return True

    def _cmd_register(self, parsed: ParsedCommand) -> bool:
        """注册新脚本: /register <name> <script> [description]"""
        if len(parsed.positional_args) < 2:
            self.console.print("[bold red]用法:[/bold red] /register <name> <script> [description]")
            self.console.print("示例: /register mytool mytool.py \"我的工具\"")
            return True

        name = parsed.positional_args[0]
        script = parsed.positional_args[1]
        description = parsed.positional_args[2] if len(parsed.positional_args) > 2 else ""

        # 检查脚本文件是否存在
        script_path = os.path.join(self.executor.scripts_dir, script)
        if not os.path.exists(script_path):
            self.console.print(
                f"[yellow]警告:[/yellow] 脚本文件不存在: {script_path}"
            )
            self.console.print("注册继续，但执行时将报错")

        success = self.registry.register(name, script, description)
        if success:
            self.console.print(f"[bold green]已注册:[/bold green] /{name} -> {script}")
        else:
            self.console.print(
                f"[bold red]注册失败:[/bold red] 命令 /{name} 已存在"
            )
        return True

    def _cmd_unregister(self, parsed: ParsedCommand) -> bool:
        """取消注册: /unregister <name>"""
        if not parsed.positional_args:
            self.console.print("[bold red]用法:[/bold red] /unregister <name>")
            return True

        name = parsed.positional_args[0]
        success = self.registry.unregister(name)
        if success:
            self.console.print(f"[bold green]已取消注册:[/bold green] /{name}")
        else:
            self.console.print(f"[bold red]取消注册失败:[/bold red] 命令 /{name} 不存在")
        return True

    def _cmd_reload(self, parsed: ParsedCommand) -> bool:
        """重新加载配置"""
        self.registry.reload()
        self.console.print("[bold green]配置已重新加载[/bold green]")
        return True

    def _cmd_workspace(self, parsed: ParsedCommand) -> bool:
        """查看当前工作空间信息"""
        table = Table(show_header=True, header_style="bold cyan")
        table.add_column("项", style="cyan")
        table.add_column("值")
        table.add_row("Aiguibin Home", self.AIGUIBIN_CLI_HOME or "N/A")
        table.add_row("Workspace", self.task_manager.workspace)
        table.add_row("Tasks Dir", self.task_manager.tasks_dir)
        table.add_row("Scripts Dir", self.executor.scripts_dir)
        self.console.print(table)
        return True

    def _cmd_cd(self, parsed: ParsedCommand) -> bool:
        """切换工作空间: /cd <path>"""
        if not parsed.positional_args:
            self.console.print(f"[cyan]当前工作空间:[/cyan] {self.task_manager.workspace}")
            self.console.print("[dim]用法: /cd <path>[/dim]")
            return True

        target = parsed.positional_args[0]
        # 支持相对路径
        if not os.path.isabs(target):
            target = os.path.join(self.task_manager.workspace, target)
        target = os.path.abspath(target)

        if not os.path.isdir(target):
            self.console.print(f"[bold red]目录不存在:[/bold red] {target}")
            return True

        # 重新创建 TaskManager 指向新工作空间
        old_workspace = self.task_manager.workspace
        self.task_manager = TaskManager(target)
        self.console.print(
            f"[bold green]工作空间已切换:[/bold green]\n"
            f"  [dim]{old_workspace}[/dim]\n"
            f"  [dim]  -> {target}[/dim]"
        )
        return True

    def _cmd_shell(self, parsed: ParsedCommand) -> bool:
        """启动内嵌 Git Bash 交互式 Shell"""
        if not self.runtime_detector:
            self.console.print("[bold red]错误:[/bold red] RuntimeDetector 未初始化")
            return True

        bash_path = self.runtime_detector.get_bash_path()
        if not bash_path:
            self.console.print("[bold red]错误:[/bold red] 未找到 Bash（请运行 install.bat 安装 Git 或确保系统 Bash 可用）")
            return True

        git_home = self.runtime_detector.get_git_home()

        self.console.print(f"[cyan]启动 Shell:[/cyan] {bash_path}")
        if git_home:
            self.console.print(f"[dim]Git Home: {git_home}[/dim]")
        self.console.print("[dim]输入 exit 退出 Shell[/dim]")
        self.console.print()

        try:
            # 构建环境变量
            env = os.environ.copy()
            if git_home:
                # MSYSTEM=MSYS 兼容 Git Bash（基于 MSYS2 runtime）
                env["MSYSTEM"] = "MSYS"
                env["CHERE_INVOKING"] = "1"
                # 设置 HOME 为用户目录
                home_dir = os.path.join(git_home, "home", os.environ.get("USERNAME", "user"))
                env["HOME"] = home_dir

            # 启动交互式 Bash
            result = subprocess.run(
                [bash_path, "--login", "-i"],
                env=env,
                cwd=self.task_manager.workspace,
            )
            if result.returncode != 0:
                self.console.print(f"[dim]Shell 退出码: {result.returncode}[/dim]")
        except FileNotFoundError:
            self.console.print(f"[bold red]错误:[/bold red] Bash 路径无效: {bash_path}")
        except KeyboardInterrupt:
            self.console.print("\n[dim]Shell 已终止[/dim]")

        return True

    def _cmd_install_pkg(self, parsed: ParsedCommand) -> bool:
        """通过 npm 全局安装包: /install-pkg <package>"""
        if not self.runtime_detector:
            self.console.print("[bold red]错误:[/bold red] RuntimeDetector 未初始化")
            return True

        node_path = self.runtime_detector.get_node_path()
        if not node_path:
            self.console.print("[bold red]错误:[/bold red] Node.js 未安装，无法使用 npm")
            self.console.print("请先运行 [cyan]install.bat[/cyan] 安装 Node.js")
            return True

        if not parsed.positional_args:
            self.console.print("[bold red]用法:[/bold red] /install-pkg <package> [package2 ...]")
            self.console.print("示例: /install-pkg typescript eslint")
            return True

        packages = parsed.positional_args
        # npm.cmd 位于 node.exe 同目录下
        npm_path = os.path.join(os.path.dirname(node_path), "npm.cmd")
        pkg_list = " ".join(packages)

        self.console.print(f"[cyan]安装包:[/cyan] {pkg_list}")

        try:
            # 使用内嵌 Node.js 的 npm 全局安装
            result = subprocess.run(
                [npm_path, "install", "-g"] + packages,
                env=os.environ.copy(),
                cwd=self.task_manager.workspace,
            )
            if result.returncode == 0:
                self.console.print(f"[bold green]安装成功:[/bold green] {pkg_list}")
            else:
                self.console.print(f"[bold red]安装失败[/bold red] (exit code: {result.returncode})")
        except Exception as e:
            self.console.print(f"[bold red]执行失败:[/bold red] {e}")

        return True

    def _cmd_env(self, parsed: ParsedCommand) -> bool:
        """显示所有运行时路径信息"""
        if not self.runtime_detector:
            self.console.print("[bold red]错误:[/bold red] RuntimeDetector 未初始化")
            return True

        paths = self.runtime_detector.get_all_paths()
        status = self.runtime_detector.check_runtime()

        table = Table(title="运行时路径信息", show_header=True, header_style="bold cyan")
        table.add_column("项目", style="cyan")
        table.add_column("路径")
        table.add_column("来源")

        items = [
            ("AIGUIBIN_CLI_HOME", paths["AIGUIBIN_CLI_HOME"], ""),
            ("Python", paths["PYTHON"], paths["PYTHON_SOURCE"]),
            ("Bash", paths["BASH"], paths["BASH_SOURCE"]),
            ("Git Home", paths["GIT_HOME"], "embedded" if status.git_available else "none"),
            ("Node.js", paths["NODE"], paths["NODE_SOURCE"]),
        ]

        for name, path, source in items:
            # 根据来源着色
            if source == "embedded":
                source_style = "[green]embedded[/green]"
            elif source == "system":
                source_style = "[yellow]system[/yellow]"
            elif source == "none" or not path:
                source_style = "[red]none[/red]"
                path = path or "(未找到)"
            else:
                source_style = source
            table.add_row(name, path or "(未找到)", source_style)

        self.console.print(table)
        return True

    def _cmd_doctor(self, parsed: ParsedCommand) -> bool:
        """诊断运行时完整性"""
        if not self.runtime_detector:
            self.console.print("[bold red]错误:[/bold red] RuntimeDetector 未初始化")
            return True

        status = self.runtime_detector.check_runtime()

        self.console.print()
        self.console.print(
            Panel(
                "[bold]AIguibin Agent System v3.5 - 运行时诊断[/bold]",
                border_style="blue",
            )
        )

        table = Table(show_header=True, header_style="bold cyan")
        table.add_column("检查项", style="cyan")
        table.add_column("状态")
        table.add_column("详情")

        # Python 检查
        if status.python_available:
            table.add_row(
                "Python",
                "[green]OK[/green]",
                f"{status.python_path} ({status.python_source})",
            )
        else:
            table.add_row("Python", "[red]MISSING[/red]", "未找到可用的 Python 解释器")

        # Bash 检查
        if status.bash_available:
            table.add_row(
                "Bash",
                "[green]OK[/green]",
                f"{status.bash_path} ({status.bash_source})",
            )
        else:
            table.add_row("Bash", "[yellow]WARN[/yellow]", "未找到 Bash（.sh 脚本将无法执行）")

        # Git 检查
        if status.git_available:
            table.add_row(
                "Git",
                "[green]OK[/green]",
                status.git_home,
            )
        else:
            table.add_row(
                "Git",
                "[yellow]WARN[/yellow]",
                "Git 未安装（/shell 和 /install-pkg 不可用，运行 install.bat 安装）",
            )

        # Node.js 检查
        if status.node_available:
            table.add_row(
                "Node.js",
                "[green]OK[/green]",
                f"{status.node_path} ({status.node_source})",
            )
        else:
            table.add_row("Node.js", "[dim]--[/dim]", "未找到 Node.js（.js 脚本将无法执行）")

        self.console.print(table)

        # 总结
        issues = []
        if not status.python_available:
            issues.append("Python 不可用")
        if not status.bash_available:
            issues.append("Bash 不可用")
        if not status.git_available:
            issues.append("Git 未安装")
        if not status.node_available:
            issues.append("Node.js 不可用")

        self.console.print()
        if not issues:
            self.console.print("[bold green]所有运行时检查通过[/bold green]")
        else:
            self.console.print(f"[yellow]注意:[/yellow] {'、'.join(issues)}")
            if not status.git_available:
                self.console.print("[dim]提示: 运行 install.bat 安装 Git 和 Node.js[/dim]")

        self.console.print()
        return True

    def _cmd_exit(self, parsed: ParsedCommand) -> bool:
        """退出"""
        self.console.print("[bold]Bye![/bold]")
        return False

    # ===== Python 依赖管理命令 =====

    def _cmd_list_python(self, parsed: ParsedCommand) -> bool:
        """列出已安装的Python包"""
        if "python" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Python依赖管理器未初始化")
            return True

        try:
            manager = self.dep_managers["python"]
            packages = manager.list_installed()

            table = Table(show_header=True, header_style="bold cyan")
            table.add_column("包名", style="green")
            table.add_column("版本", style="yellow")

            for pkg in packages:
                table.add_row(pkg["name"], pkg["version"])

            self.console.print(f"\n[cyan]已安装 {len(packages)} 个Python包:[/cyan]")
            self.console.print(table)
            self.console.print()

        except Exception as e:
            self.console.print(f"[bold red]获取Python包列表失败:[/bold red] {e}")

        return True

    def _cmd_install_python(self, parsed: ParsedCommand) -> bool:
        """安装Python包"""
        if "python" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Python依赖管理器未初始化")
            return True

        manager = self.dep_managers["python"]

        # 检查是否从配置文件安装
        if "from-file" in parsed.flags:
            success, message = manager.install([], from_file=True)
            if success:
                self.console.print(f"[green]✓[/green] {message}")
            else:
                self.console.print(f"[red]✗[/red] {message}")
            return True

        # 从参数获取包名
        packages = parsed.positional_args
        if not packages:
            self.console.print("[yellow]用法:[/yellow] /install-python <package1> [package2...]")
            self.console.print("[yellow]或者:[/yellow] /install-python --from-file  # 从配置文件安装")
            return True

        upgrade = "upgrade" in parsed.flags

        self.console.print(f"[cyan]安装Python包: {', '.join(packages)}[/cyan]")
        success, message = manager.install(packages, upgrade=upgrade)

        if success:
            self.console.print(f"[green]✓[/green] {message}")
        else:
            self.console.print(f"[red]✗[/red] {message}")

        return True

    def _cmd_update_python(self, parsed: ParsedCommand) -> bool:
        """更新Python包"""
        if "python" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Python依赖管理器未初始化")
            return True

        manager = self.dep_managers["python"]
        packages = parsed.positional_args
        update_all = "all" in parsed.flags

        if update_all or not packages:
            self.console.print("[cyan]检查并更新所有过时的Python包...[/cyan]")
            success, message = manager.update()
        else:
            self.console.print(f"[cyan]更新Python包: {', '.join(packages)}[/cyan]")
            success, message = manager.update(packages)

        if success:
            self.console.print(f"[green]✓[/green] {message}")
        else:
            self.console.print(f"[red]✗[/red] {message}")

        return True

    def _cmd_uninstall_python(self, parsed: ParsedCommand) -> bool:
        """卸载Python包"""
        if "python" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Python依赖管理器未初始化")
            return True

        packages = parsed.positional_args
        if not packages:
            self.console.print("[yellow]用法:[/yellow] /uninstall-python <package1> [package2...]")
            return True

        manager = self.dep_managers["python"]
        self.console.print(f"[cyan]卸载Python包: {', '.join(packages)}[/cyan]")

        success, message = manager.uninstall(packages)
        if success:
            self.console.print(f"[green]✓[/green] {message}")
        else:
            self.console.print(f"[red]✗[/red] {message}")

        return True

    def _cmd_export_python(self, parsed: ParsedCommand) -> bool:
        """导出当前安装的Python依赖到配置文件"""
        if "python" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Python依赖管理器未初始化")
            return True

        manager = self.dep_managers["python"]
        self.console.print("[cyan]导出当前Python依赖到配置文件...[/cyan]")

        success, message = manager.export_dependencies()
        if success:
            self.console.print(f"[green]✓[/green] {message}")
            self.console.print(f"[dim]配置文件: {manager.config_file}[/dim]")
        else:
            self.console.print(f"[red]✗[/red] {message}")

        return True

    # ===== Node.js 依赖管理命令 =====

    def _cmd_list_node(self, parsed: ParsedCommand) -> bool:
        """列出已安装的Node.js包"""
        if "node" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Node.js依赖管理器未初始化")
            return True

        try:
            manager = self.dep_managers["node"]
            global_only = "global" in parsed.flags

            packages = manager.list_installed(global_only=global_only)

            table = Table(show_header=True, header_style="bold cyan")
            table.add_column("包名", style="green")
            table.add_column("版本", style="yellow")

            for pkg in packages:
                table.add_row(pkg["name"], pkg["version"])

            scope = "全局" if global_only else "本地"
            self.console.print(f"\n[cyan]已安装 {len(packages)} 个{scope}Node.js包:[/cyan]")
            self.console.print(table)
            self.console.print()

        except Exception as e:
            self.console.print(f"[bold red]获取Node.js包列表失败:[/bold red] {e}")

        return True

    def _cmd_install_node(self, parsed: ParsedCommand) -> bool:
        """安装Node.js包"""
        if "node" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Node.js依赖管理器未初始化")
            return True

        packages = parsed.positional_args
        if not packages:
            self.console.print("[yellow]用法:[/yellow] /install-node [--global] <package1> [package2...]")
            return True

        manager = self.dep_managers["node"]
        global_install = "global" in parsed.flags
        save = "save" in parsed.flags
        save_dev = "save-dev" in parsed.flags

        scope = "全局" if global_install else "本地"
        self.console.print(f"[cyan]安装{scope}Node.js包: {', '.join(packages)}[/cyan]")

        success, message = manager.install(packages, global_install, save, save_dev)
        if success:
            self.console.print(f"[green]✓[/green] {message}")
        else:
            self.console.print(f"[red]✗[/red] {message}")

        return True

    def _cmd_update_node(self, parsed: ParsedCommand) -> bool:
        """更新Node.js包"""
        if "node" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Node.js依赖管理器未初始化")
            return True

        manager = self.dep_managers["node"]
        packages = parsed.positional_args
        global_install = "global" in parsed.flags

        scope = "全局" if global_install else "本地"

        if packages:
            self.console.print(f"[cyan]更新{scope}Node.js包: {', '.join(packages)}[/cyan]")
        else:
            self.console.print(f"[cyan]更新所有{scope}Node.js包[/cyan]")

        success, message = manager.update(packages if packages else None, global_install)
        if success:
            self.console.print(f"[green]✓[/green] {message}")
        else:
            self.console.print(f"[red]✗[/red] {message}")

        return True

    def _cmd_uninstall_node(self, parsed: ParsedCommand) -> bool:
        """卸载Node.js包"""
        if "node" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] Node.js依赖管理器未初始化")
            return True

        packages = parsed.positional_args
        if not packages:
            self.console.print("[yellow]用法:[/yellow] /uninstall-node [--global] <package1> [package2...]")
            return True

        manager = self.dep_managers["node"]
        global_install = "global" in parsed.flags
        scope = "全局" if global_install else "本地"

        self.console.print(f"[cyan]卸载{scope}Node.js包: {', '.join(packages)}[/cyan]")

        success, message = manager.uninstall(packages, global_install)
        if success:
            self.console.print(f"[green]✓[/green] {message}")
        else:
            self.console.print(f"[red]✗[/red] {message}")

        return True

    # ===== Shell 工具管理命令 =====

    def _cmd_list_tools(self, parsed: ParsedCommand) -> bool:
        """列出已安装的Shell工具"""
        if "tools" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] 工具管理器未初始化")
            return True

        try:
            manager = self.dep_managers["tools"]
            tools = manager.list_tools()

            table = Table(show_header=True, header_style="bold cyan")
            table.add_column("工具名", style="green")
            table.add_column("路径", style="yellow")
            table.add_column("大小", style="cyan")

            for tool in tools:
                table.add_row(tool["name"], tool["path"], tool["size"])

            self.console.print(f"\n[cyan]已安装 {len(tools)} 个自定义工具:[/cyan]")
            self.console.print(table)
            self.console.print()

            if not tools:
                self.console.print("[dim]使用 /add-tool 添加工具[/dim]")

        except Exception as e:
            self.console.print(f"[bold red]获取工具列表失败:[/bold red] {e}")

        return True

    def _cmd_add_tool(self, parsed: ParsedCommand) -> bool:
        """添加工具"""
        if "tools" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] 工具管理器未初始化")
            return True

        args = parsed.positional_args
        if len(args) < 2:
            self.console.print("[yellow]用法:[/yellow] /add-tool <source> <tool_name>")
            self.console.print("[yellow]  <source>: 本地文件路径或下载URL")
            self.console.print("[yellow]  <tool_name>: 工具名称（可选）")
            return True

        source = args[0]
        tool_name = args[1] if len(args) > 1 else None
        is_url = source.startswith("http://") or source.startswith("https://")

        manager = self.dep_managers["tools"]
        if is_url:
            self.console.print(f"[cyan]从网络下载工具: {source}[/cyan]")
        else:
            self.console.print(f"[cyan]从本地添加工具: {source}[/cyan]")

        success, message = manager.add_tool(source, tool_name, is_url)
        if success:
            self.console.print(f"[green]✓[/green] {message}")
        else:
            self.console.print(f"[red]✗[/red] {message}")

        return True

    def _cmd_remove_tool(self, parsed: ParsedCommand) -> bool:
        """移除工具"""
        if "tools" not in self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] 工具管理器未初始化")
            return True

        tool_names = parsed.positional_args
        if not tool_names:
            self.console.print("[yellow]用法:[/yellow] /remove-tool <tool_name1> [tool_name2...]")
            return True

        manager = self.dep_managers["tools"]
        for tool_name in tool_names:
            self.console.print(f"[cyan]移除工具: {tool_name}[/cyan]")
            success, message = manager.remove_tool(tool_name)
            if success:
                self.console.print(f"[green]✓[/green] {message}")
            else:
                self.console.print(f"[red]✗[/red] {message}")

        return True

    # ===== 依赖配置管理命令 =====

    def _cmd_dep_config(self, parsed: ParsedCommand) -> bool:
        """查看依赖配置"""
        if not self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] 依赖管理器未初始化")
            return True

        self.console.print("\n[bold cyan]=== 依赖配置信息 ===[/bold cyan]\n")

        # Python配置
        if "python" in self.dep_managers:
            python_config = self.dep_managers["python"].get_config_info()
            if python_config:
                self.console.print("[bold green]Python 依赖配置:[/bold green]")
                self.console.print(f"  Python版本: {python_config.get('python_version', 'N/A')}")
                deps = python_config.get('dependencies', [])
                required_deps = [d for d in deps if d.get('required', False)]
                optional_deps = [d for d in deps if not d.get('required', False)]
                self.console.print(f"  核心依赖: {len(required_deps)} 个")
                self.console.print(f"  可选依赖: {len(optional_deps)} 个")
                self.console.print()

        # Node.js配置
        if "node" in self.dep_managers:
            node_config = self.dep_managers["node"].get_config_info()
            if node_config:
                self.console.print("[bold green]Node.js 依赖配置:[/bold green]")
                self.console.print(f"  Node版本: {node_config.get('node_version', 'N/A')}")
                self.console.print(f"  NPM版本: {node_config.get('npm_version', 'N/A')}")
                global_packages = node_config.get('global_packages', {})
                local_packages = node_config.get('local_packages', {})
                self.console.print(f"  全局包: {len(global_packages)} 个")
                self.console.print(f"  本地包: {len(local_packages)} 个")
                self.console.print()

        # Shell工具配置
        if "tools" in self.dep_managers:
            tools_config = self.dep_managers["tools"].get_config_info()
            if tools_config:
                self.console.print("[bold green]Shell 工具配置:[/bold green]")
                tools = tools_config.get('tools', [])
                self.console.print(f"  配置的工具: {len(tools)} 个")

                tool_groups = tools_config.get('tool_groups', {})
                if tool_groups:
                    self.console.print(f"  工具组: {len(tool_groups)} 个")
                    for group_name, group_info in tool_groups.items():
                        self.console.print(f"    - {group_name}: {group_info.get('description', 'N/A')}")
                self.console.print()

        self.console.print("[dim]配置文件目录: config/dependencies/[/dim]")
        return True

    def _cmd_dep_sync(self, parsed: ParsedCommand) -> bool:
        """同步依赖（根据配置文件安装）"""
        if not self.dep_managers:
            self.console.print("[bold red]错误:[/bold red] 依赖管理器未初始化")
            return True

        check_only = "check-only" in parsed.flags
        self.console.print("[cyan]同步依赖...[/cyan]\n")

        # 同步Python依赖
        if "python" in self.dep_managers:
            self.console.print("[bold]Python 依赖:[/bold]")
            if check_only:
                self.console.print("  (仅检查模式，不实际安装)")
            else:
                success, message = self.dep_managers["python"].install([], from_file=True)
                if success:
                    self.console.print(f"  [green]✓[/green] {message}")
                else:
                    self.console.print(f"  [red]✗[/red] {message}")
            self.console.print()

        # 同步Node.js依赖
        if "node" in self.dep_managers:
            self.console.print("[bold]Node.js 依赖:[/bold]")
            if check_only:
                self.console.print("  (仅检查模式，不实际安装)")
            else:
                # 这里可以实现从配置文件同步的逻辑
                self.console.print("  [dim]Node.js配置同步功能开发中...[/dim]")
            self.console.print()

        self.console.print("[green]依赖同步完成[/green]")
        return True
