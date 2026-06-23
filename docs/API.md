# AIguibinCLI API 接口文档

## 概述

AIguibinCLI 提供了命令行接口和编程接口两种方式使用。

## 命令行接口

### 基础命令

#### `/help`
显示帮助信息和可用命令列表。

```bash
aiguibin /help
```

#### `/list`
列出所有注册的脚本命令。

```bash
aiguibin /list
```

#### `/status`
查看最近的任务状态。

```bash
aiguibin /status
```

#### `/workspace`
显示当前工作空间信息。

```bash
aiguibin /workspace
```

#### `/cd <path>`
切换工作目录。

```bash
aiguibin /cd D:\MyProject
```

### 系统命令

#### `/env`
显示所有运行时环境变量和路径信息。

```bash
aiguibin /env
```

#### `/doctor`
诊断运行时完整性，检查 Python、Git、Node.js 状态。

```bash
aiguibin /doctor
```

#### `/shell`
启动内嵌 Git Bash 交互式 Shell。

```bash
aiguibin /shell
```

### 脚本管理命令

#### `/register <name> <script> <description>`
动态注册新脚本命令。

```bash
aiguibin /register mytool mytool.py "我的工具"
```

#### `/unregister <name>`
取消注册脚本命令。

```bash
aiguibin /unregister mytool
```

#### `/reload`
重新加载脚本注册表配置。

```bash
aiguibin /reload
```

### 依赖管理命令

#### Python 依赖管理

```bash
# 列出已安装的包
/list-python

# 安装包
/install-python <package>
/install-python --from-file

# 更新包
/update-python <package>
/update-python --all

# 卸载包
/uninstall-python <package>

# 导出依赖
/export-python
```

#### Node.js 依赖管理

```bash
# 列出已安装的包
/list-node
/list-node --global

# 安装包
/install-node <package>
/install-node --global <package>

# 更新包
/update-node <package>

# 卸载包
/uninstall-node <package>
/uninstall-node --global <package>
```

#### Shell 工具管理

```bash
# 列出工具
/list-tools

# 添加工具
/add-tool <url> <name>
/add-tool --local <path> <name>

# 移除工具
/remove-tool <name>
```

#### 统一管理

```bash
# 查看依赖配置
/dep-config

# 同步依赖
/dep-sync
/dep-sync --check-only
```

### 退出命令

```bash
/exit
/quit
```

## 编程接口

### 模块接口

#### 1. CommandParser

```python
from core.command_parser import CommandParser

parser = CommandParser()
parsed = parser.parse("/hello --name=World --verbose")

# ParsedCommand 属性
parsed.command              # "hello"
parsed.kwargs               # {"name": "World"}
parsed.flags                # {"verbose"}
parsed.positional_args      # []
```

#### 2. ScriptRegistry

```python
from core.registry import ScriptRegistry

registry = ScriptRegistry(config_path, scripts_dir)

# 注册命令
registry.register("mytool", "mytool.py", "我的工具")

# 查询命令
cmd_def = registry.get("mytool")

# 参数验证
valid, errors = registry.validate_params(cmd_def, kwargs, flags, args)

# 保存配置
registry._save()
```

#### 3. TaskManager

```python
from core.task_manager import TaskManager

task_manager = TaskManager(workspace)

# 创建任务
task_id = task_manager.create_task("hello", {"name": "World"})

# 更新状态
task_manager.update_task_status(task_id, "completed")

# 记录日志
task_manager.append_log(task_id, "执行完成")

# 获取任务路径
task_dir = task_manager.get_task_dir(task_id)
output_dir = task_manager.get_output_dir(task_id)
```

#### 4. ScriptExecutor

```python
from core.executor import ScriptExecutor

executor = ScriptExecutor(scripts_dir, AIGUIBIN_CLI_HOME)

# 执行脚本
result = executor.execute(
    script="hello.py",
    args=["--name=World"],
    task_id=task_id,
    task_dir=task_dir,
    workspace=workspace
)

# ExecutionResult 属性
result.success         # True/False
result.return_code     # 0/非0
result.stdout          # 标准输出
result.stderr          # 错误输出
result.duration        # 执行时间（秒）
```

#### 5. RuntimeDetector

```python
from core.runtime import RuntimeDetector

detector = RuntimeDetector(AIGUIBIN_CLI_HOME)

# 获取运行时路径
python_path = detector.get_python_path()
bash_path = detector.get_bash_path()
node_path = detector.get_node_path()
git_home = detector.get_git_home()

# 检查运行时状态
status = detector.check_runtime()
status.python_available   # True/False
status.bash_available     # True/False
status.git_available      # True/False
status.node_available     # True/False

# 构建 PATH 环境变量
path_env = detector.build_path_env()
```

#### 6. Dispatcher

```python
from core.dispatcher import Dispatcher

dispatcher = Dispatcher(
    registry=registry,
    task_manager=task_manager,
    executor=executor,
    console=console,
    AIGUIBIN_CLI_HOME=AIGUIBIN_CLI_HOME,
    AIGUIBIN_AGENT_DIR=AIGUIBIN_AGENT_DIR
)

# 调度命令
parsed = parser.parse("/hello --name=World")
continue_running = dispatcher.dispatch(parsed)
```

#### 7. DependencyManager

```python
from core.dependency_manager import create_dependency_managers

managers = create_dependency_managers(
    aiguibin_home=AIGUIBIN_CLI_HOME,
    agent_dir=AIGUIBIN_AGENT_DIR
)

# Python 依赖管理
python_mgr = managers["python"]
packages = python_mgr.list_installed()
success, message = python_mgr.install(["requests"])
success, message = python_mgr.update()
success, message = python_mgr.uninstall(["requests"])

# Node.js 依赖管理
node_mgr = managers["node"]
packages = node_mgr.list_installed(global_only=True)
success, message = node_mgr.install(["typescript"], global_install=True)
success, message = node_mgr.update(None, global_install=True)
success, message = node_mgr.uninstall(["typescript"], global_install=True)

# Shell 工具管理
tool_mgr = managers["tools"]
tools = tool_mgr.list_tools()
success, message = tool_mgr.add_tool("https://github.com/...", "tool.exe")
success, message = tool_mgr.remove_tool("tool.exe")
```

### 环境变量接口

#### 系统环境变量

```python
import os

# 安装目录
AIGUIBIN_CLI_HOME = os.environ.get("AIGUIBIN_CLI_HOME", "")

# 应用数据目录
AIGUIBIN_AGENT_DIR = os.environ.get("AIGUIBIN_AGENT_DIR", "")

# 自定义任务目录（可选）
AIGUIBIN_TASKS_DIR = os.environ.get("AIGUIBIN_TASKS_DIR", "")
```

#### 运行时环境变量（注入到脚本）

```python
# 脚本内部可用的环境变量
task_id = os.environ.get("AIGUIBIN_TASK_ID")
task_dir = os.environ.get("AIGUIBIN_TASK_DIR")
output_dir = os.environ.get("AIGUIBIN_OUTPUT_DIR")
workspace = os.environ.get("AIGUIBIN_WORKSPACE")
bash_path = os.environ.get("AIGUIBIN_BASH")
python_path = os.environ.get("AIGUIBIN_PYTHON")
```

### 扩展接口

#### 添加新内置命令

```python
class Dispatcher:
    def __init__(self, ...):
        # 注册新命令
        self._builtins = {
            # 现有命令
            "my-command": self._cmd_my_command,
        }
    
    def _cmd_my_command(self, parsed: ParsedCommand) -> bool:
        """我的自定义命令"""
        try:
            # 参数处理
            if not parsed.positional_args:
                self.console.print("[yellow]用法:[/yellow] /my-command <args>")
                return True
            
            # 业务逻辑
            result = self._process_my_command(parsed.positional_args)
            
            # 输出结果
            self.console.print(f"[green]✓[/green] {result}")
            return True
            
        except Exception as e:
            self.console.print(f"[red]✗[/red] {e}")
            return True
```

#### 添加新脚本类型支持

```python
class ScriptExecutor:
    def _detect_interpreter(self, script: str) -> List[str]:
        """检测脚本解释器"""
        ext = os.path.splitext(script)[1].lower()
        
        # 现有类型
        if ext == ".py":
            return [self.runtime_detector.get_python_path()]
        elif ext == ".sh":
            return [self.runtime_detector.get_bash_path()]
        # ... 更多类型
        
        # 新类型（例如：Rust）
        elif ext == ".rs":
            rust_path = self.runtime_detector.get_rust_path()
            if rust_path:
                return [rust_path, "run", script]
        
        # 默认处理
        return []
```

#### 添加新依赖管理器

```python
class MyDependencyManager(DependencyManager):
    """自定义依赖管理器"""
    
    def __init__(self, aiguibin_home: str, agent_dir: str):
        super().__init__(aiguibin_home, agent_dir)
        self.config_file = os.path.join(self.deps_config_dir, "my-deps.json")
    
    def install(self, packages: List[str]) -> Tuple[bool, str]:
        """安装包"""
        try:
            # 安装逻辑
            self._log("INFO", f"安装包: {', '.join(packages)}")
            return True, "安装成功"
        except Exception as e:
            self._log("ERROR", f"安装失败: {e}")
            return False, str(e)

# 在工厂函数中注册
def create_dependency_managers(aiguibin_home: str, agent_dir: str, ...):
    return {
        # 现有管理器
        "python": PythonDependencyManager(...),
        "node": NodeDependencyManager(...),
        "tools": ToolManager(...),
        # 新管理器
        "my-type": MyDependencyManager(aiguibin_home, agent_dir),
    }
```

## 配置文件接口

### 脚本注册表 (config/registry.yaml)

```yaml
commands:
  - name: hello
    script: hello.py
    description: 问候世界
    tags: [demo, greeting]
    params:
      - name: name
        type: string
        required: false
        default: World
        description: 问候对象
        flag: name
```

### Python 依赖配置 (config/dependencies/python-dependencies.yaml)

```yaml
python_version: "3.13"
site_packages_path: "python/Lib/site-packages"
dependencies:
  - name: rich
    version: ">=13.0.0"
    required: true
    description: Terminal UI
    tags: [core, ui]
```

### Node.js 依赖配置 (config/dependencies/node-dependencies.json)

```json
{
  "node_version": "22.0.0",
  "global_packages": {
    "typescript": {
      "version": "^5.0.0",
      "description": "TypeScript compiler",
      "required": true
    }
  }
}
```

### Shell 工具配置 (config/dependencies/shell-tools.yaml)

```yaml
tools:
  - name: ripgrep
    description: Fast file search tool
    windows_binary: "rg.exe"
    download_url: "https://github.com/..."
    version: "14.0.3"
    path: "tools/binaries/"
```

## 数据结构

### ParsedCommand

```python
@dataclass
class ParsedCommand:
    command: str                    # 命令名
    kwargs: Dict[str, str]         # 键值对参数
    flags: Set[str]                 # 布尔标志
    positional_args: List[str]      # 位置参数
```

### CommandDef

```python
@dataclass
class CommandDef:
    name: str                       # 命令名
    script: str                     # 脚本文件
    description: str                # 描述
    tags: List[str]                 # 标签
    params: List[ParamDef]          # 参数定义
```

### ExecutionResult

```python
@dataclass
class ExecutionResult:
    success: bool                   # 是否成功
    return_code: int                # 返回码
    stdout: str                     # 标准输出
    stderr: str                     # 错误输出
    duration: float                 # 执行时间（秒）
```

### RuntimeStatus

```python
@dataclass
class RuntimeStatus:
    python_available: bool
    python_path: str | None
    python_source: str
    
    bash_available: bool
    bash_path: str | None
    bash_source: str
    
    git_available: bool
    git_home: str | None
    
    node_available: bool
    node_path: str | None
    node_source: str
```

## 错误处理

### 异常类型

```python
# 核心异常
class AIguibinCLIError(Exception):
    """基础异常类"""
    pass

class CommandNotFoundError(AIguibinCLIError):
    """命令不存在异常"""
    pass

class ParameterValidationError(AIguibinCLIError):
    """参数验证失败异常"""
    pass

class ScriptExecutionError(AIguibinCLIError):
    """脚本执行异常"""
    pass

class DependencyError(AIguibinCLIError):
    """依赖管理异常"""
    pass

class RuntimeError(AIguibinCLIError):
    """运行时异常"""
    pass
```

### 错误处理模式

```python
try:
    result = operation()
except CommandNotFoundError as e:
    console.print(f"[red]命令不存在:[/red] {e}")
except ParameterValidationError as e:
    console.print(f"[red]参数错误:[/red] {e}")
except ScriptExecutionError as e:
    console.print(f"[red]执行失败:[/red] {e}")
except DependencyError as e:
    console.print(f"[red]依赖错误:[/red] {e}")
except RuntimeError as e:
    console.print(f"[red]运行时错误:[/red] {e}")
except Exception as e:
    console.print(f"[red]未知错误:[/red] {e}")
```

## 最佳实践

### 1. 命令开发

```python
def _cmd_my_command(self, parsed: ParsedCommand) -> bool:
    """标准命令模板"""
    # 1. 参数验证
    if not parsed.positional_args:
        self.console.print("[yellow]用法:[/yellow] /my-command <args>")
        return True
    
    # 2. 业务逻辑
    try:
        result = self._do_something(parsed.positional_args)
        
        # 3. 输出结果
        self.console.print(f"[green]✓[/green] {result}")
        return True
        
    except Exception as e:
        # 4. 错误处理
        self.console.print(f"[red]✗[/red] 操作失败: {e}")
        return True
```

### 2. 脚本开发

```python
#!/usr/bin/env python3
"""
标准脚本模板
"""

import os
import sys
import argparse

def main():
    # 1. 参数处理
    parser = argparse.ArgumentParser(description="脚本描述")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", default="output.txt")
    args = parser.parse_args()
    
    # 2. 环境变量
    task_id = os.environ.get("AIGUIBIN_TASK_ID", "N/A")
    output_dir = os.environ.get("AIGUIBIN_OUTPUT_DIR", ".")
    
    # 3. 业务逻辑
    try:
        # 执行操作
        result = process(args.input)
        
        # 4. 输出结果
        result_path = os.path.join(output_dir, args.output)
        with open(result_path, 'w', encoding='utf-8') as f:
            f.write(result)
        
        print(f"✓ Result: {result_path}")
        
    except Exception as e:
        print(f"✗ Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
```

### 3. 模块开发

```python
"""
标准模块模板
"""

from typing import Dict, List, Optional, Tuple
from datetime import datetime

class MyModule:
    """模块描述"""
    
    def __init__(self, config_path: str):
        """初始化"""
        self.config_path = config_path
        self.config = self._load_config()
    
    def _load_config(self) -> Dict:
        """加载配置"""
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f) or {}
        except Exception as e:
            return {}
    
    def do_something(self, args: List[str]) -> Tuple[bool, str]:
        """核心方法"""
        try:
            # 业务逻辑
            return True, "操作成功"
        except Exception as e:
            return False, str(e)
```

## 版本兼容性

### v3.5 API 兼容性

- ✅ 所有 v3.0 API 保持兼容
- ✅ 新增依赖管理接口
- ✅ 扩展环境变量支持
- ✅ 增强日志系统

### 向后兼容保证

1. **命令接口**：所有现有命令保持不变
2. **模块接口**：核心模块 API 保持稳定
3. **配置格式**：现有配置文件格式兼容
4. **环境变量**：现有环境变量保持不变

---

**使用建议**：
1. 优先使用命令行接口进行日常操作
2. 编程接口用于扩展开发和自动化
3. 遵循接口规范确保兼容性
4. 查看源码了解详细实现