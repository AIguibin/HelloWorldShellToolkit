#!/usr/bin/env python3
"""
依赖管理模块

支持 Python、Node.js 和 Shell 工具的安装、更新、卸载和查询
遵循 AIguibinCLI 的架构规范：
- 使用 RuntimeDetector 的回退策略
- 日志写入 .agent/logs/
- 配置文件使用 YAML/JSON 格式
- 统一的错误处理和日志记录
"""

import os
import subprocess
import json
import yaml
import shutil
from typing import List, Dict, Optional, Tuple
from pathlib import Path
from datetime import datetime


class DependencyManager:
    """依赖管理器基类"""

    def __init__(self, aiguibin_home: str, agent_dir: str):
        self.aiguibin_home = aiguibin_home
        self.agent_dir = agent_dir
        self.config_dir = os.path.join(aiguibin_home, "config")
        self.deps_config_dir = os.path.join(self.config_dir, "dependencies")
        self.tools_dir = os.path.join(aiguibin_home, "tools")

        # 确保目录存在
        os.makedirs(self.deps_config_dir, exist_ok=True)
        os.makedirs(self.tools_dir, exist_ok=True)
        os.makedirs(os.path.join(self.tools_dir, "binaries"), exist_ok=True)
        os.makedirs(os.path.join(self.tools_dir, "python"), exist_ok=True)
        os.makedirs(os.path.join(self.tools_dir, "nodejs"), exist_ok=True)
        os.makedirs(os.path.join(self.tools_dir, "shell"), exist_ok=True)

        # 日志文件
        self.log_file = os.path.join(self.agent_dir, "logs", "dependencies.log")

    def _log(self, level: str, message: str) -> None:
        """记录依赖操作日志"""
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(f"[{timestamp}] [{level}] {message}\n")
        except Exception:
            pass  # 日志写入失败不影响主流程


class PythonDependencyManager(DependencyManager):
    """Python 依赖管理器"""

    def __init__(self, aiguibin_home: str, agent_dir: str, python_path: Optional[str] = None):
        super().__init__(aiguibin_home, agent_dir)
        self.python_path = python_path or os.path.join(aiguibin_home, "python", "python.exe")
        self.site_packages = os.path.join(aiguibin_home, "python", "Lib", "site-packages")
        self.config_file = os.path.join(self.deps_config_dir, "python-dependencies.yaml")
        self.requirements_file = os.path.join(self.deps_config_dir, "requirements.txt")

    def list_installed(self) -> List[Dict[str, str]]:
        """列出已安装的包"""
        try:
            self._log("INFO", "获取已安装的Python包列表")
            result = subprocess.run(
                [self.python_path, "-m", "pip", "list", "--format=json"],
                capture_output=True, text=True, check=True
            )
            packages = json.loads(result.stdout)
            return [{"name": pkg["name"], "version": pkg["version"]} for pkg in packages]
        except Exception as e:
            self._log("ERROR", f"获取已安装包失败: {e}")
            raise RuntimeError(f"获取已安装包失败: {e}")

    def install(self, packages: List[str], upgrade: bool = False, from_file: bool = False) -> Tuple[bool, str]:
        """安装包"""
        try:
            if from_file:
                return self._install_from_requirements()
            else:
                cmd = [self.python_path, "-m", "pip", "install"]
                if upgrade:
                    cmd.append("--upgrade")
                cmd.append("--target")
                cmd.append(self.site_packages)
                cmd.extend(packages)

                self._log("INFO", f"安装Python包: {', '.join(packages)}")
                result = subprocess.run(cmd, capture_output=True, text=True)

                if result.returncode == 0:
                    self._log("INFO", f"成功安装Python包: {', '.join(packages)}")
                    return True, "安装成功"
                else:
                    self._log("ERROR", f"安装失败: {result.stderr}")
                    return False, result.stderr
        except Exception as e:
            self._log("ERROR", f"安装过程异常: {e}")
            return False, str(e)

    def _install_from_requirements(self) -> Tuple[bool, str]:
        """从配置文件安装"""
        if not os.path.exists(self.config_file):
            return False, f"配置文件不存在: {self.config_file}"

        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)

            # 提取核心依赖
            core_deps = []
            for dep in config.get('dependencies', []):
                if dep.get('required', False):
                    pkg_name = dep['name']
                    version = dep.get('version', '')
                    core_deps.append(f"{pkg_name}{version}")

            if not core_deps:
                return True, "没有需要安装的核心依赖"

            cmd = [self.python_path, "-m", "pip", "install", "-r", "-", "--target", self.site_packages]
            result = subprocess.run(cmd, input="\n".join(core_deps), capture_output=True, text=True)

            if result.returncode == 0:
                self._log("INFO", f"从配置文件成功安装: {', '.join(core_deps)}")
                return True, f"从配置文件成功安装 {len(core_deps)} 个包"
            else:
                self._log("ERROR", f"从配置文件安装失败: {result.stderr}")
                return False, result.stderr
        except Exception as e:
            self._log("ERROR", f"从配置文件安装异常: {e}")
            return False, str(e)

    def uninstall(self, packages: List[str]) -> Tuple[bool, str]:
        """卸载包"""
        try:
            cmd = [self.python_path, "-m", "pip", "uninstall", "-y"]
            cmd.extend(packages)

            self._log("INFO", f"卸载Python包: {', '.join(packages)}")
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                self._log("INFO", f"成功卸载Python包: {', '.join(packages)}")
                return True, "卸载成功"
            else:
                self._log("ERROR", f"卸载失败: {result.stderr}")
                return False, result.stderr
        except Exception as e:
            self._log("ERROR", f"卸载过程异常: {e}")
            return False, str(e)

    def update(self, packages: Optional[List[str]] = None) -> Tuple[bool, str]:
        """更新包"""
        try:
            if packages:
                # 更新指定包
                return self.install(packages, upgrade=True)
            else:
                # 更新所有包（过时包）
                self._log("INFO", "检查过时的包...")
                result = subprocess.run(
                    [self.python_path, "-m", "pip", "list", "--outdated", "--format=json"],
                    capture_output=True, text=True
                )

                if result.returncode == 0:
                    outdated = json.loads(result.stdout)
                    if outdated:
                        package_names = [pkg['name'] for pkg in outdated]
                        self._log("INFO", f"发现 {len(package_names)} 个过时的包")
                        return self.install(package_names, upgrade=True)
                    else:
                        return True, "所有包都是最新的"
                else:
                    return False, "检查过时包失败"
        except Exception as e:
            self._log("ERROR", f"更新过程异常: {e}")
            return False, str(e)

    def export_dependencies(self) -> Tuple[bool, str]:
        """导出当前安装的依赖到配置文件"""
        try:
            installed = self.list_installed()

            # 读取现有配置
            config = {}
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config = yaml.safe_load(f) or {}

            # 更新dependencies部分
            config['dependencies'] = []
            for pkg in installed:
                config['dependencies'].append({
                    'name': pkg['name'],
                    'version': f"=={pkg['version']}",
                    'required': True,
                    'description': f"Exported at {datetime.now().strftime('%Y-%m-%d')}"
                })

            # 保存配置
            with open(self.config_file, 'w', encoding='utf-8') as f:
                yaml.dump(config, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

            self._log("INFO", f"成功导出 {len(installed)} 个包到配置文件")
            return True, f"成功导出 {len(installed)} 个包到配置文件"
        except Exception as e:
            self._log("ERROR", f"导出依赖失败: {e}")
            return False, str(e)

    def get_config_info(self) -> Dict:
        """获取配置信息"""
        if os.path.exists(self.config_file):
            with open(self.config_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f) or {}
        return {}


class NodeDependencyManager(DependencyManager):
    """Node.js 依赖管理器"""

    def __init__(self, aiguibin_home: str, agent_dir: str, node_path: Optional[str] = None):
        super().__init__(aiguibin_home, agent_dir)
        self.node_home = node_path or os.path.join(aiguibin_home, "node")
        self.npm_cmd = os.path.join(self.node_home, "npm.cmd")
        self.node_modules = os.path.join(self.node_home, "node_modules")
        self.config_file = os.path.join(self.deps_config_dir, "node-dependencies.json")

    def list_installed(self, global_only: bool = False) -> List[Dict[str, str]]:
        """列出已安装的包"""
        try:
            cmd = [self.npm_cmd, "list", "-g", "--json", "--depth=0"] if global_only else \
                  [self.npm_cmd, "list", "--json", "--depth=0"]

            self._log("INFO", f"获取已安装的Node.js包列表 (全局={global_only})")
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode != 0:
                return []

            data = json.loads(result.stdout)
            dependencies = data.get("dependencies", {})

            packages = [{"name": name, "version": info.get("version", "unknown")}
                       for name, info in dependencies.items()]
            return packages
        except Exception as e:
            self._log("ERROR", f"获取已安装包失败: {e}")
            return []

    def install(self, packages: List[str], global_install: bool = False,
                save: bool = True, save_dev: bool = False) -> Tuple[bool, str]:
        """安装包"""
        try:
            cmd = [self.npm_cmd, "install"]

            if global_install:
                cmd.extend(["-g", "--prefix", self.node_home])
            else:
                if save:
                    cmd.append("--save")
                if save_dev:
                    cmd.append("--save-dev")

            cmd.extend(packages)

            self._log("INFO", f"安装Node.js包: {', '.join(packages)} (全局={global_install})")
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                self._log("INFO", f"成功安装Node.js包: {', '.join(packages)}")
                return True, "安装成功"
            else:
                self._log("ERROR", f"安装失败: {result.stderr}")
                return False, result.stderr
        except Exception as e:
            self._log("ERROR", f"安装过程异常: {e}")
            return False, str(e)

    def uninstall(self, packages: List[str], global_install: bool = False) -> Tuple[bool, str]:
        """卸载包"""
        try:
            cmd = [self.npm_cmd, "uninstall"]
            if global_install:
                cmd.extend(["-g", "--prefix", self.node_home])
            cmd.extend(packages)

            self._log("INFO", f"卸载Node.js包: {', '.join(packages)} (全局={global_install})")
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                self._log("INFO", f"成功卸载Node.js包: {', '.join(packages)}")
                return True, "卸载成功"
            else:
                self._log("ERROR", f"卸载失败: {result.stderr}")
                return False, result.stderr
        except Exception as e:
            self._log("ERROR", f"卸载过程异常: {e}")
            return False, str(e)

    def update(self, packages: Optional[List[str]] = None, global_install: bool = False) -> Tuple[bool, str]:
        """更新包"""
        try:
            cmd = [self.npm_cmd, "update"]
            if global_install:
                cmd.extend(["-g", "--prefix", self.node_home])
            if packages:
                cmd.extend(packages)

            self._log("INFO", f"更新Node.js包 (全局={global_install})")
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode == 0:
                self._log("INFO", "更新成功")
                return True, "更新成功"
            else:
                self._log("ERROR", f"更新失败: {result.stderr}")
                return False, result.stderr
        except Exception as e:
            self._log("ERROR", f"更新过程异常: {e}")
            return False, str(e)

    def get_config_info(self) -> Dict:
        """获取配置信息"""
        if os.path.exists(self.config_file):
            with open(self.config_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {}


class ToolManager(DependencyManager):
    """Shell 工具和二进制文件管理器"""

    def __init__(self, aiguibin_home: str, agent_dir: str):
        super().__init__(aiguibin_home, agent_dir)
        self.binaries_dir = os.path.join(self.tools_dir, "binaries")
        self.config_file = os.path.join(self.deps_config_dir, "shell-tools.yaml")

    def list_tools(self) -> List[Dict[str, str]]:
        """列出自定义工具"""
        tools = []
        if os.path.exists(self.binaries_dir):
            for item in os.listdir(self.binaries_dir):
                path = os.path.join(self.binaries_dir, item)
                if os.path.isfile(path):
                    tools.append({
                        "name": item,
                        "path": path,
                        "size": f"{os.path.getsize(path)} bytes"
                    })
        return tools

    def add_tool(self, source: str, tool_name: Optional[str] = None, is_url: bool = False) -> Tuple[bool, str]:
        """添加工具（复制或下载）"""
        try:
            if is_url:
                return self._download_tool(source, tool_name or os.path.basename(source))
            elif os.path.isfile(source):
                # 本地文件
                name = tool_name or os.path.basename(source)
                dest = os.path.join(self.binaries_dir, name)
                shutil.copy2(source, dest)
                self._log("INFO", f"工具已添加: {dest}")
                return True, f"工具已添加: {dest}"
            else:
                return False, "源文件不存在"
        except Exception as e:
            self._log("ERROR", f"添加工具失败: {e}")
            return False, str(e)

    def _download_tool(self, url: str, tool_name: str) -> Tuple[bool, str]:
        """下载工具"""
        try:
            import urllib.request
            dest = os.path.join(self.binaries_dir, tool_name)

            self._log("INFO", f"开始下载工具: {tool_name} 从 {url}")

            def progress_hook(count, block_size, total_size):
                if total_size > 0:
                    percent = int(count * block_size * 100 / total_size)
                    print(f"\r下载中: {percent}%", end="", flush=True)

            urllib.request.urlretrieve(url, dest, progress_hook)
            print()  # 换行

            self._log("INFO", f"工具已下载: {dest}")
            return True, f"工具已下载: {dest}"
        except Exception as e:
            self._log("ERROR", f"下载工具失败: {e}")
            return False, str(e)

    def remove_tool(self, tool_name: str) -> Tuple[bool, str]:
        """移除工具"""
        try:
            path = os.path.join(self.binaries_dir, tool_name)
            if os.path.exists(path):
                os.remove(path)
                self._log("INFO", f"工具已移除: {tool_name}")
                return True, f"工具已移除: {tool_name}"
            else:
                return False, f"工具不存在: {tool_name}"
        except Exception as e:
            self._log("ERROR", f"移除工具失败: {e}")
            return False, str(e)

    def get_config_info(self) -> Dict:
        """获取配置信息"""
        if os.path.exists(self.config_file):
            with open(self.config_file, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f) or {}
        return {}

    def get_tool_groups(self) -> Dict:
        """获取工具组信息"""
        config = self.get_config_info()
        return config.get("tool_groups", {})


def create_dependency_managers(aiguibin_home: str, agent_dir: str,
                              python_path: Optional[str] = None,
                              node_path: Optional[str] = None) -> Dict[str, DependencyManager]:
    """创建所有依赖管理器"""
    return {
        "python": PythonDependencyManager(aiguibin_home, agent_dir, python_path),
        "node": NodeDependencyManager(aiguibin_home, agent_dir, node_path),
        "tools": ToolManager(aiguibin_home, agent_dir)
    }