"""
运行时检测与路径管理模块

v3.5 Git 便携版内嵌支持:
  - 检测内嵌 Python / Git Bash / Node.js
  - 构建子进程 PATH（内嵌路径优先）
  - 提供运行时完整性诊断

路径回退策略:
  内嵌路径 → shutil.which() 查宿主机 → None
"""

import os
import shutil
import sys
from dataclasses import dataclass


@dataclass
class RuntimeStatus:
    """运行时检测状态"""
    python_available: bool = False
    python_path: str = ""
    python_source: str = ""   # "embedded" | "system" | "none"
    bash_available: bool = False
    bash_path: str = ""
    bash_source: str = ""     # "embedded" | "system" | "none"
    git_available: bool = False
    git_home: str = ""
    node_available: bool = False
    node_path: str = ""
    node_source: str = ""     # "embedded" | "system" | "none"


class RuntimeDetector:
    """
    运行时检测器

    负责检测可用的解释器与运行时环境，
    遵循「内嵌 → 宿主机 → None」的回退策略。

    Args:
        AIGUIBIN_CLI_HOME: Aiguibin 安装根目录（AIGUIBIN_CLI_HOME）
    """

    def __init__(self, AIGUIBIN_CLI_HOME: str):
        self.AIGUIBIN_CLI_HOME = os.path.abspath(AIGUIBIN_CLI_HOME)

    def get_bash_path(self) -> str | None:
        """
        获取 Bash 可执行路径

        回退顺序:
          1. AIGUIBIN_CLI_HOME/git/usr/bin/bash.exe（内嵌 Git Bash）
          2. shutil.which("bash")（宿主机）
          3. None
        """
        # 内嵌 Git Bash
        embedded_bash = os.path.join(self.AIGUIBIN_CLI_HOME, "git", "usr", "bin", "bash.exe")
        if os.path.isfile(embedded_bash):
            return embedded_bash

        # 宿主机 bash
        system_bash = shutil.which("bash")
        if system_bash:
            return system_bash

        return None

    def get_python_path(self) -> str | None:
        """
        获取 Python 可执行路径

        回退顺序:
          1. AIGUIBIN_CLI_HOME/python/python.exe（内嵌 Python）
          2. sys.executable（当前 Python）
          3. None
        """
        # 内嵌 Python
        embedded_python = os.path.join(self.AIGUIBIN_CLI_HOME, "python", "python.exe")
        if os.path.isfile(embedded_python):
            return embedded_python

        # 当前解释器
        if sys.executable and os.path.isfile(sys.executable):
            return sys.executable

        return None

    def get_node_path(self) -> str | None:
        """
        获取 Node.js 可执行路径

        回退顺序:
          1. AIGUIBIN_CLI_HOME/node/node.exe（内嵌 Node.js）
          2. shutil.which("node")（宿主机）
          3. None
        """
        # 内嵌 Node.js
        embedded_node = os.path.join(self.AIGUIBIN_CLI_HOME, "node", "node.exe")
        if os.path.isfile(embedded_node):
            return embedded_node

        # 宿主机 node
        system_node = shutil.which("node")
        if system_node:
            return system_node

        return None

    def get_git_home(self) -> str | None:
        """
        获取 Git 便携版根目录

        仅当 AIGUIBIN_CLI_HOME/git/usr/bin/bash.exe 存在时返回，
        否则返回 None。
        """
        git_home = os.path.join(self.AIGUIBIN_CLI_HOME, "git")
        bash_path = os.path.join(git_home, "usr", "bin", "bash.exe")
        if os.path.isfile(bash_path):
            return git_home
        return None

    def check_runtime(self) -> RuntimeStatus:
        """
        执行完整的运行时检测

        Returns:
            RuntimeStatus 包含所有检测到的运行时信息
        """
        status = RuntimeStatus()

        # Python 检测
        python_path = self.get_python_path()
        if python_path:
            status.python_available = True
            status.python_path = python_path
            embedded_python = os.path.join(self.AIGUIBIN_CLI_HOME, "python", "python.exe")
            status.python_source = "embedded" if python_path == embedded_python else "system"
        else:
            status.python_source = "none"

        # Bash 检测
        bash_path = self.get_bash_path()
        if bash_path:
            status.bash_available = True
            status.bash_path = bash_path
            embedded_bash = os.path.join(self.AIGUIBIN_CLI_HOME, "git", "usr", "bin", "bash.exe")
            status.bash_source = "embedded" if bash_path == embedded_bash else "system"
        else:
            status.bash_source = "none"

        # Git 检测
        git_home = self.get_git_home()
        if git_home:
            status.git_available = True
            status.git_home = git_home

        # Node.js 检测
        node_path = self.get_node_path()
        if node_path:
            status.node_available = True
            status.node_path = node_path
            embedded_node = os.path.join(self.AIGUIBIN_CLI_HOME, "node", "node.exe")
            status.node_source = "embedded" if node_path == embedded_node else "system"
        else:
            status.node_source = "none"

        return status

    def get_all_paths(self) -> dict[str, str]:
        """
        获取所有路径信息

        Returns:
            字典，包含所有检测到的路径及 AIGUIBIN_CLI_HOME
        """
        status = self.check_runtime()
        return {
            "AIGUIBIN_CLI_HOME": self.AIGUIBIN_CLI_HOME,
            "PYTHON": status.python_path or "",
            "PYTHON_SOURCE": status.python_source,
            "BASH": status.bash_path or "",
            "BASH_SOURCE": status.bash_source,
            "GIT_HOME": status.git_home or "",
            "NODE": status.node_path or "",
            "NODE_SOURCE": status.node_source,
        }

    def build_path_env(self) -> str:
        """
        构建子进程 PATH 环境变量

        将内嵌运行时目录前置到系统 PATH 之前，
        确保子进程优先使用内嵌的解释器。

        Returns:
            适合设为 PATH 环境变量的字符串
        """
        # 收集需要前置的内嵌路径目录
        prepend_dirs: list[str] = []

        # 内嵌 Python 目录
        embedded_python_dir = os.path.join(self.AIGUIBIN_CLI_HOME, "python")
        if os.path.isfile(os.path.join(embedded_python_dir, "python.exe")):
            prepend_dirs.append(embedded_python_dir)

        # 内嵌 Git 各子目录
        git_home = self.get_git_home()
        if git_home:
            # usr/bin 包含 bash 等核心工具
            usr_bin = os.path.join(git_home, "usr", "bin")
            if os.path.isdir(usr_bin):
                prepend_dirs.append(usr_bin)
            # bin 包含 git 本体
            git_bin = os.path.join(git_home, "bin")
            if os.path.isdir(git_bin):
                prepend_dirs.append(git_bin)

        # 内嵌 Node.js 目录
        embedded_node_dir = os.path.join(self.AIGUIBIN_CLI_HOME, "node")
        if os.path.isfile(os.path.join(embedded_node_dir, "node.exe")):
            prepend_dirs.append(embedded_node_dir)

        # 组合 PATH: 内嵌路径 + 系统 PATH
        current_path = os.environ.get("PATH", "")
        if prepend_dirs:
            new_path = ";".join(prepend_dirs) + ";" + current_path
        else:
            new_path = current_path

        return new_path
