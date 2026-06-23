"""
脚本执行引擎 - 动态加载并执行脚本

v3.5 内嵌运行时支持:
  - .py   → RuntimeDetector 优先检测内嵌 Python
  - .sh   → RuntimeDetector 优先检测内嵌 Git Bash
  - .js   → RuntimeDetector 优先检测内嵌 Node.js
  - 无扩展名 → 尝试内嵌 Bash 执行
  - 注入 AIGUIBIN_BASH, AIGUIBIN_PYTHON 环境变量
  - 使用 RuntimeDetector.build_path_env() 构建 PATH

核心能力:
  - 实时捕获 stdout / stderr
  - 记录执行时长与退出码
  - 支持超时控制
  - 通过回调函数实时反馈执行状态
"""

import os
import platform
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Callable

from .runtime import RuntimeDetector


@dataclass
class ExecutionResult:
    """脚本执行结果"""
    success: bool = False
    return_code: int = -1
    stdout: str = ""
    stderr: str = ""
    duration: float = 0.0
    timed_out: bool = False


# ─── 解释器映射 ──────────────────────────────────

def _detect_interpreter(script_path: str, AIGUIBIN_CLI_HOME: str = "") -> list[str]:
    """
    根据脚本扩展名检测解释器

    优先使用 RuntimeDetector 检测内嵌路径，
    回退到系统默认解释器。

    Args:
        script_path: 脚本文件路径
        AIGUIBIN_CLI_HOME: Aiguibin 安装目录，用于内嵌运行时检测

    Returns:
        命令前缀列表，如 ["python", "script.py"] 或 ["bash", "script.sh"]
    """
    ext = os.path.splitext(script_path)[1].lower()

    # 创建 RuntimeDetector 用于内嵌路径检测
    detector = RuntimeDetector(AIGUIBIN_CLI_HOME) if AIGUIBIN_CLI_HOME else None

    # 按扩展名映射，优先使用内嵌运行时
    if ext == ".py":
        if detector:
            python_path = detector.get_python_path()
            if python_path:
                return [python_path]
        # 回退到当前 Python 解释器
        return [sys.executable]

    if ext == ".sh":
        if detector:
            bash_path = detector.get_bash_path()
            if bash_path:
                return [bash_path]
        return ["bash"]

    if ext == ".js":
        if detector:
            node_path = detector.get_node_path()
            if node_path:
                return [node_path]
        return ["node"]

    # .bat / .cmd / .ps1 不变
    interpreter_map = {
        ".bat": ["cmd", "/c"],
        ".cmd": ["cmd", "/c"],
        ".ps1": ["powershell", "-ExecutionPolicy", "Bypass", "-File"],
        ".ts":  ["npx", "ts-node"],
        ".rb":  ["ruby"],
        ".go":  ["go", "run"],
        ".lua": ["lua"],
        ".pl":  ["perl"],
    }
    if ext in interpreter_map:
        return interpreter_map[ext]

    # 无扩展名 → 检查 shebang
    shebang = _read_shebang(script_path)
    if shebang:
        return _parse_shebang(shebang)

    # 无扩展名 → 尝试内嵌 Bash 执行
    if detector:
        bash_path = detector.get_bash_path()
        if bash_path:
            return [bash_path]

    # 最终回退：直接执行
    return []


def _read_shebang(script_path: str) -> str | None:
    """读取脚本第一行的 shebang"""
    try:
        with open(script_path, "r", encoding="utf-8", errors="replace") as f:
            first_line = f.readline(256).strip()
        if first_line.startswith("#!"):
            return first_line[2:].strip()
    except Exception:
        pass
    return None


def _parse_shebang(shebang: str) -> list[str]:
    """解析 shebang 为命令列表"""
    parts = shebang.split()
    if not parts:
        return []

    # /usr/bin/env 形式
    if parts[0].endswith("/env") and len(parts) > 1:
        return parts[1:]

    # 直接路径 /usr/bin/python3
    interpreter = os.path.basename(parts[0])
    return [interpreter] + parts[1:]


class ScriptExecutor:
    """脚本执行引擎"""

    def __init__(self, scripts_dir: str, timeout: int = 300, AIGUIBIN_CLI_HOME: str = ""):
        """
        Args:
            scripts_dir: 脚本根目录
            timeout: 默认超时时间（秒），0 表示不限
            AIGUIBIN_CLI_HOME: Aiguibin 安装目录，用于内嵌运行时检测
        """
        self.scripts_dir = scripts_dir
        self.timeout = timeout
        self.AIGUIBIN_CLI_HOME = AIGUIBIN_CLI_HOME

    def execute(
        self,
        script_path: str,
        args: list[str] | None = None,
        env_vars: dict[str, str] | None = None,
        cwd: str | None = None,
        timeout: int | None = None,
        on_output: Callable[[str, str], None] | None = None,
    ) -> ExecutionResult:
        """
        执行脚本

        Args:
            script_path: 脚本路径（绝对路径或相对于 scripts_dir）
            args: 命令行参数列表
            env_vars: 额外环境变量
            cwd: 工作目录
            timeout: 本次超时时间（秒），None 使用默认值
            on_output: 实时输出回调 (line, stream_type)，stream_type 为 'stdout' 或 'stderr'

        Returns:
            ExecutionResult 执行结果
        """
        # 解析脚本完整路径
        if not os.path.isabs(script_path):
            script_path = os.path.join(self.scripts_dir, script_path)

        if not os.path.exists(script_path):
            return ExecutionResult(
                success=False,
                stderr=f"脚本文件不存在: {script_path}",
            )

        # 构建命令（自动检测解释器）
        command = self._build_command(script_path, args)

        # 构建环境变量
        env = os.environ.copy()
        if env_vars:
            env.update(env_vars)

        # 注入内嵌运行时环境变量
        if self.AIGUIBIN_CLI_HOME:
            detector = RuntimeDetector(self.AIGUIBIN_CLI_HOME)
            bash_path = detector.get_bash_path()
            python_path = detector.get_python_path()
            if bash_path:
                env["AIGUIBIN_BASH"] = bash_path
            if python_path:
                env["AIGUIBIN_PYTHON"] = python_path

            # 使用 RuntimeDetector 构建子进程 PATH
            env["PATH"] = detector.build_path_env()

        # 确保中文输出
        env["PYTHONIOENCODING"] = "utf-8"
        # 让 shell 脚本也能获取 AIGUIBIN 环境变量
        for key, value in (env_vars or {}).items():
            env[key] = value

        effective_timeout = timeout if timeout is not None else self.timeout

        # 执行
        result = ExecutionResult()
        start_time = time.time()

        try:
            # .bat/.cmd 在 Windows 上需要 shell=True
            use_shell = platform.system() == "Windows" and script_path.lower().endswith((".bat", ".cmd"))

            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=env,
                cwd=cwd,
                encoding="utf-8",
                errors="replace",
                shell=use_shell,
            )

            stdout_lines: list[str] = []
            stderr_lines: list[str] = []

            # 逐行读取输出
            import threading

            def read_stream(stream, lines, stream_type):
                for line in stream:
                    line = line.rstrip("\n").rstrip("\r")
                    lines.append(line)
                    if on_output:
                        on_output(line, stream_type)

            stdout_thread = threading.Thread(
                target=read_stream, args=(process.stdout, stdout_lines, "stdout")
            )
            stderr_thread = threading.Thread(
                target=read_stream, args=(process.stderr, stderr_lines, "stderr")
            )
            stdout_thread.daemon = True
            stderr_thread.daemon = True
            stdout_thread.start()
            stderr_thread.start()

            # 等待完成或超时
            try:
                process.wait(timeout=effective_timeout or None)
            except subprocess.TimeoutExpired:
                process.kill()
                result.timed_out = True
                # 关闭进程流以触发读取线程退出
                process.stdout.close()
                process.stderr.close()

            # 等待读取线程完成（最多 5 秒）
            stdout_thread.join(timeout=5)
            stderr_thread.join(timeout=5)

            # 检查线程是否仍在运行（daemon 线程不会阻塞程序退出）
            if stdout_thread.is_alive() or stderr_thread.is_alive():
                # 由于线程是 daemon 的，它们会在程序退出时自动清理
                # 这里仅记录，不影响结果
                pass

            result.return_code = process.returncode
            result.stdout = "\n".join(stdout_lines)
            result.stderr = "\n".join(stderr_lines)
            result.success = (process.returncode == 0)

        except FileNotFoundError as e:
            result.success = False
            result.stderr = f"命令执行失败: {e}"
        except Exception as e:
            result.success = False
            result.stderr = f"执行异常: {e}"

        result.duration = time.time() - start_time
        return result

    def _build_command(self, script_path: str, args: list[str] | None = None) -> list[str]:
        """
        构建执行命令（自动检测解释器）

        支持的脚本类型:
          .py   → 内嵌 Python / 当前解释器
          .sh   → 内嵌 Bash / 系统 Bash
          .bat  → cmd /c script.bat [args]
          .ps1  → powershell -File script.ps1 [args]
          .js   → 内嵌 Node / 系统 Node
          其他   → 尝试内嵌 Bash 或直接执行
        """
        interpreter = _detect_interpreter(script_path, self.AIGUIBIN_CLI_HOME)
        command = interpreter + [script_path]
        if args:
            command.extend(args)

        # Windows 下 .bat/.cmd 必须通过 cmd /c 执行
        # 但参数需要合并为一个字符串传给 shell
        if platform.system() == "Windows" and script_path.lower().endswith((".bat", ".cmd")):
            # 构建单条命令字符串
            cmd_str = " ".join(f'"{a}"' if " " in a else a for a in command)
            return ["cmd", "/c", cmd_str]

        return command
