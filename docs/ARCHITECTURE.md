# AIguibinCLI 架构设计文档

## 概述

AIguibinCLI 是一个本地命令行 Aiguibin 系统，采用模块化架构设计，支持多语言脚本执行、依赖管理和内嵌运行时。

## 核心架构

### 架构分层

```
┌─────────────────────────────────────────────────────┐
│                    用户接口层                        │
│  • 交互式 CLI (AiguibinCLI)                         │
│  • 单次执行模式 (run_single)                        │
│  • 命令行参数解析 (CommandParser)                   │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│                    命令调度层                        │
│  • 内置命令路由 (Dispatcher)                        │
│  • 脚本注册管理 (ScriptRegistry)                    │
│  • 命令验证和参数检查                               │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│                    执行引擎层                        │
│  • 脚本执行 (ScriptExecutor)                        │
│  • 运行时检测 (RuntimeDetector)                     │
│  • 任务管理 (TaskManager)                           │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│                    基础设施层                        │
│  • 内嵌运行时 (Python, Node.js, Git Bash)          │
│  • 依赖管理 (DependencyManager)                     │
│  • 配置管理 (YAML/JSON 配置文件)                    │
└─────────────────────────────────────────────────────┘
```

## 核心模块设计

### 1. 主入口模块 (aiguibin.py)

**职责**：程序入口、模式选择、组件初始化

**关键功能**：
- 路径常量定义
- 交互式/单次执行模式路由
- 组件工厂函数
- 应用日志记录

**架构原则**：
- 单一职责：只负责启动和路由
- 依赖注入：通过工厂函数传递依赖
- 配置优先：从环境变量和文件读取配置

### 2. 命令解析模块 (command_parser.py)

**职责**：解析用户输入为结构化命令对象

**核心类**：
```python
class CommandParser:
    def parse(self, command_str: str) -> ParsedCommand
```

**解析规则**：
- `/command` → 命令名
- `--key=value` → 键值对参数
- `--flag` → 布尔标志
- 位置参数 → 列表

**扩展点**：
- 自定义参数类型转换
- 新的命令格式支持
- 参数验证规则

### 3. 脚本注册模块 (registry.py)

**职责**：管理命令到脚本的映射关系

**核心类**：
```python
class ScriptRegistry:
    def register(self, name: str, script: str, description: str)
    def get(self, name: str) -> CommandDef
    def validate_params(self, cmd_def: CommandDef, ...) -> Tuple[bool, List[str]]
```

**配置格式**：
```yaml
commands:
  - name: hello
    script: hello.py
    description: 问候世界
    params: []
```

**动态特性**：
- 运行时注册新命令
- 持久化到 YAML 文件
- 支持命令热重载

### 4. 任务管理模块 (task_manager.py)

**职责**：管理任务生命周期和目录结构

**核心类**：
```python
class TaskManager:
    def create_task(self, command: str, args: dict) -> str
    def update_task_status(self, task_id: str, status: str)
    def append_log(self, task_id: str, message: str)
```

**任务目录结构**：
```
<workspace>/.aiguibin/tasks/task_YYYYMMDD_HHMMSS/
├── config.json           # 任务配置
├── logs/
│   └── execution.log     # 执行日志
└── outputs/               # 脚本输出
```

**状态流转**：
`pending` → `running` → `completed` / `failed`

### 5. 脚本执行模块 (executor.py)

**职责**：执行脚本并管理子进程

**核心类**：
```python
class ScriptExecutor:
    def execute(self, script: str, args: List[str], ...) -> ExecutionResult
```

**执行流程**：
1. 解释器检测（扩展名优先）
2. 环境变量注入
3. PATH 构建（内嵌运行时优先）
4. 子进程创建
5. 实时输出捕获
6. 超时控制

**环境变量注入**：
- AIGUIBIN_TASK_ID
- AIGUIBIN_TASK_DIR
- AIGUIBIN_OUTPUT_DIR
- AIGUIBIN_WORKSPACE
- AIGUIBIN_BASH
- AIGUIBIN_PYTHON
- AIGUIBIN_NODE

### 6. 命令调度模块 (dispatcher.py)

**职责**：路由命令到对应处理器

**核心类**：
```python
class Dispatcher:
    def dispatch(self, parsed: ParsedCommand) -> bool
```

**调度优先级**：
1. 内置命令（help, list, install-python 等）
2. 注册脚本（hello, build, deploy 等）
3. 未知命令提示

**内置命令分类**：
- 信息类：help, list, status, env, doctor
- 操作类：register, unregister, reload, cd, workspace
- 系统类：shell, install-pkg, exit
- 依赖类：list-python, install-node, add-tool 等

### 7. 运行时检测模块 (runtime.py)

**职责**：检测和管理内嵌/系统运行时

**核心类**：
```python
class RuntimeDetector:
    def get_python_path(self) -> str | None
    def get_bash_path(self) -> str | None
    def get_node_path(self) -> str | None
    def build_path_env(self) -> str
    def check_runtime(self) -> RuntimeStatus
```

**三级回退策略**：
```
内嵌路径 → 系统路径 → None
```

**PATH 构建顺序**：
1. 内嵌 Python 目录
2. 内嵌 Git usr/bin 目录
3. 内嵌 Git bin 目录
4. 内嵌 Node.js 目录
5. 系统 PATH

### 8. 依赖管理模块 (dependency_manager.py)

**职责**：统一管理 Python、Node.js、Shell 工具依赖

**核心类**：
```python
class DependencyManager:  # 基类
class PythonDependencyManager(DependencyManager)
class NodeDependencyManager(DependencyManager)
class ToolManager(DependencyManager)
```

**配置驱动**：
- Python: `config/dependencies/python-dependencies.yaml`
- Node.js: `config/dependencies/node-dependencies.json`
- Shell: `config/dependencies/shell-tools.yaml`

**功能特性**：
- 安装/卸载/更新/查询
- 配置文件同步
- 操作日志记录
- 版本冲突检测

### 9. 引导模块 (bootstrap.py)

**职责**：自动下载缺失的运行时组件

**核心功能**：
- 版本查询（npmmirror API）
- Git 下载和验证
- Node.js 下载和验证
- 版本缓存（7天TTL）

**下载流程**：
1. 查询版本号（优先缓存）
2. 检查本地文件
3. 下载压缩包
4. 解压到指定目录
5. 清理临时文件

## 数据流设计

### 1. 命令执行流程

```
用户输入 → CommandParser → Dispatcher
                          ↓
                    命令路由判断
                          ↓
         ┌────────────────┴────────────────┐
         ↓                                  ↓
    内置命令处理                        注册脚本执行
         ↓                                  ↓
    直接处理逻辑                      TaskManager 创建任务
         ↓                                  ↓
    结果输出                          ScriptExecutor 执行
                                             ↓
                                     实时输出捕获
                                             ↓
                                     TaskManager 更新状态
```

### 2. 依赖管理流程

```
用户输入命令 → Dispatcher 路由 → DependencyManager
                                             ↓
                                    配置文件读取
                                             ↓
                                    运行时检测
                                             ↓
                                    包管理器调用
                                  (pip/npm/下载工具)
                                             ↓
                                    结果处理和日志记录
```

### 3. 环境变量流程

```
启动时环境设置
    ↓
aiguibin.py 定义常量
    ↓
install.bat 设置系统环境变量
    ↓
运行时环境变量构建
    ↓
注入到子进程
    ↓
脚本内部使用环境变量
```

## 配置管理设计

### 配置文件层次

```
┌─────────────────────────────────────┐
│   用户环境变量 (最高优先级)          │
│   AIGUIBIN_WORKSPACE                 │
│   AIGUIBIN_TASKS_DIR                 │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│   应用配置文件                       │
│   config/registry.yaml              │
│   config/dependencies/*.yaml        │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│   运行时缓存配置                     │
│   config/runtime-versions.json     │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│   代码默认值 (最低优先级)            │
└─────────────────────────────────────┘
```

### 配置热重载

```python
# /reload 命令实现
def _cmd_reload(self, parsed: ParsedCommand) -> bool:
    """重新加载配置文件"""
    try:
        self.registry.load()
        self.console.print("[green]✓[/green] 配置已重新加载")
        return True
    except Exception as e:
        self.console.print(f"[red]✗[/red] 重新加载失败: {e}")
        return True
```

## 错误处理设计

### 错误层次

```
┌─────────────────────────────────────┐
│   用户输入错误                       │
│   参数错误、命令不存在               │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│   配置错误                           │
│   配置文件缺失、格式错误             │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│   运行时错误                         │
│   脚本执行失败、运行时缺失           │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│   系统错误                           │
│   文件权限、网络问题                 │
└─────────────────────────────────────┘
```

### 错误处理策略

1. **友好提示**：用户可理解的错误信息
2. **日志记录**：详细错误信息记录到日志
3. **优雅降级**：错误不影响核心功能
4. **恢复建议**：提供修复建议

## 扩展性设计

### 1. 新命令扩展

```python
# 在 dispatcher.py 中添加
def _cmd_new_command(self, parsed: ParsedCommand) -> bool:
    """新命令描述"""
    # 实现
    return True

# 注册命令
self._builtins = {
    # ...
    "new-command": self._cmd_new_command,
}
```

### 2. 新脚本类型扩展

```python
# 在 executor.py 中添加
def _detect_interpreter(self, script: str) -> List[str]:
    """检测脚本解释器"""
    ext = os.path.splitext(script)[1].lower()
    
    # 新脚本类型
    if ext == ".rs":
        return [self.runtime_detector.get_rust_path()]
    
    # ... 现有逻辑
```

### 3. 新依赖类型扩展

```python
# 在 dependency_manager.py 中添加
class NewDependencyManager(DependencyManager):
    """新依赖管理器"""
    
    def install(self, packages: List[str]) -> Tuple[bool, str]:
        # 实现安装逻辑
        pass

# 在工厂函数中添加
def create_dependency_managers(...):
    return {
        # ...
        "new_type": NewDependencyManager(...),
    }
```

## 性能优化设计

### 1. 延迟加载

```python
# 模块延迟加载
def get_runtime_detector():
    if not hasattr(self, '_runtime_detector'):
        self._runtime_detector = RuntimeDetector(AIGUIBIN_CLI_HOME)
    return self._runtime_detector
```

### 2. 缓存机制

```python
# 版本信息缓存
def get_versions():
    cache_file = "config/runtime-versions.json"
    if os.path.exists(cache_file):
        # 检查缓存是否过期
        # 返回缓存版本
    # 下载新版本
```

### 3. 并发执行

```python
# 批量操作并发执行
from concurrent.futures import ThreadPoolExecutor

def install_packages(packages):
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(install, pkg) for pkg in packages]
        results = [f.result() for f in futures]
```

## 安全性设计

### 1. 输入验证

```python
# 路径验证
def validate_path(path: str) -> bool:
    """验证路径安全性"""
    # 检查路径遍历攻击
    # 检查特殊字符
    # 检查路径长度
```

### 2. 安全配置

```python
# YAML 安全加载
with open(file_path, 'r') as f:
    data = yaml.safe_load(f)  # 不是 yaml.load(f)
```

### 3. 权限管理

```python
# 文件权限检查
def check_write_permission(path: str) -> bool:
    """检查写入权限"""
    if os.path.exists(path):
        return os.access(path, os.W_OK)
    return os.access(os.path.dirname(path), os.W_OK)
```

## 监控和调试

### 1. 日志系统

```
.agent/logs/
├── app.log              # 主应用日志
├── bootstrap.log        # 引导日志
├── dependencies.log     # 依赖操作日志
└── module_name.log      # 模块日志（可选）
```

### 2. 诊断命令

```bash
# 运行时诊断
/doctor                  # 检查所有运行时

# 环境变量查看
/env                     # 显示所有环境变量

# 依赖状态
/dep-config             # 查看依赖配置
/list-python            # 查看Python包
/list-node              # 查看Node.js包
```

## 版本迭代设计

### 版本号规则

```
v{major}.{minor}.{patch}

major: 重大架构变更（不向后兼容）
minor: 新功能添加（向后兼容）
patch: Bug修复和小改进

示例：
v3.0 → v3.0.1 (bug fix)
v3.0 → v3.1 (new features)
v3.0 → v4.0 (breaking changes)
```

### 兼容性策略

1. **向后兼容**：新版本支持旧配置
2. **迁移路径**：提供迁移脚本
3. **废弃警告**：提前通知废弃功能
4. **渐进升级**：允许分阶段升级

## 部署架构

### 安装流程

```
install.bat (14步)
    ↓
1. 环境验证
2. 设置环境变量
3. 创建目录结构
4. 下载运行时
5. 配置PATH
6. 清理临时文件
```

### 目录结构

```
可移植安装目录：
- 程序文件：aiguibin.py, core/, scripts/
- 运行时：python/, node/, git/
- 配置：config/, .agent/
- 工具：tools/

工作目录：
- 任务输出：.aiguibin/tasks/
- 用户文件：用户工作区
```

## 技术债务和改进方向

### 当前技术债务

1. **测试覆盖率**：缺乏单元测试
2. **错误处理**：部分异常处理不够完善
3. **文档完善度**：部分文档需要更新

### 改进方向

1. **性能优化**：启动时间优化、内存优化
2. **功能扩展**：更多脚本语言支持
3. **用户体验**：更好的错误提示、进度显示
4. **开发体验**：更好的调试工具、开发模式

---

**架构原则总结**：
- **模块化**：高内聚、低耦合
- **可扩展**：易于添加新功能
- **可维护**：清晰的代码结构
- **可移植**：完整的独立部署