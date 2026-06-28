# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概览

AIguibin Agent 系统 v3.5.1 — 一个本地 CLI 代理，内嵌运行时（Python、Git Bash、Node.js）。用户通过 `/command --key=value --flag arg` 语法调用命令，这些命令可以是内置处理器，也可以是用户注册的脚本，由系统自动检测解释器并执行。

## 常用命令

```bash
# 直接执行（非交互式测试单个命令）
python aiguibin.py /hello --name=World

# 交互式 CLI（启动 REPL）
python aiguibin.py

# 构建可分发的 ZIP 包（精简版 lite + 完整版 full）
python build.py

# 全新安装（下载 Python 内嵌版、PortableGit、Node.js、pip 包）
install.bat

# 卸载（清理 PATH、环境变量）
uninstall.bat
```

在 REPL 中，以 `!` 开头的输入作为 shell 命令执行（使用内嵌 Git Bash）：`!ls -la`。

## 启动流程

`aiguibin.bat` → Bootstrap → `aiguibin.py`

1. **`aiguibin.bat`**：解析 `AIGUIBIN_CLI_HOME`，设置 `AIGUIBIN_BASH`/`AIGUIBIN_PYTHON`/`AIGUIBIN_NODE` 环境变量，Python 优先级为 内嵌 → .venv → 系统
2. **`core/bootstrap.py`**：如内嵌 Python 存在则被调用，检测并自动从 npmmirror 下载缺失的 PortableGit 和 Node.js（版本号缓存 7 天到 `config/runtime-versions.json`）
3. **`aiguibin.py`**：入口，创建组件并启动交互式 REPL 或执行单次命令

## 架构

### 调度链路

`aiguibin.py` → `CommandParser` → `Dispatcher` (三级路由) → `ScriptExecutor`/`TaskManager`

### 三级路由（Dispatcher）

1. **内置命令** — 硬编码在 `self._builtins` 字典中，每个对应一个 `_cmd_<name>` 方法
2. **注册脚本** — 从 `ScriptRegistry` (config/registry.yaml) 查找，参数校验通过后由 `ScriptExecutor` 执行
3. **未知命令** — 返回错误，提示 `/help`

内置命令包括：
- 基础：`/help`, `/list`, `/status`, `/register`, `/unregister`, `/reload`, `/exit`
- 工作空间：`/workspace`, `/cd <path>`
- 运行时：`/shell`（内嵌 Git Bash）、`/env`、`/doctor`、`/install-pkg`（npm 全局安装）
- Python 依赖：`/list-python`, `/install-python`, `/update-python`, `/uninstall-python`, `/export-python`
- Node.js 依赖：`/list-node`, `/install-node`, `/update-node`, `/uninstall-node`
- Shell 工具：`/list-tools`, `/add-tool`, `/remove-tool`
- 依赖配置：`/dep-config`, `/dep-sync`

### 核心模块

**CommandParser**（`core/command_parser.py`）：将 `/cmd --key=value --flag --no-flag positional` 解析为 `ParsedCommand` 数据类，包含 `command`、`kwargs`(dict)、`flags`(set) 和 `positional_args`(list)。支持 `--key=value`、`--key value`、`--flag`/`--no-flag`、`-x` 短标志。自动类型转换：`"true"`/`"false"`→bool，数字→int/float，`"none"`→None。

**ScriptRegistry**（`core/registry.py`）：从 `config/registry.yaml` 加载命令→脚本映射。支持运行时 `/register` 并持久化回 YAML。参数校验：必填参数优先从命名参数满足，未满足的按定义顺序从位置参数映射。数据结构：`CommandDef`（含 `ParamDef` 列表）、`ParamDef`（name/type/required/default/choices/flag）。

**ScriptExecutor**（`core/executor.py`）：解释器检测按扩展名映射（`.py`→Python、`.sh`→Bash、`.js`→Node、`.bat`/`.cmd`→cmd、`.ps1`→PowerShell），无扩展名时先读 shebang 行，再回退到内嵌 Bash。优先使用 `RuntimeDetector` 内嵌路径。使用线程并行读取 stdout/stderr，支持超时控制。返回 `ExecutionResult`（success/return_code/stdout/stderr/duration/timed_out）。

**RuntimeDetector**（`core/runtime.py`）：回退链：内嵌路径（`AIGUIBIN_CLI_HOME/python/`、`git/`、`node/`）→ `shutil.which()` / `sys.executable` → `None`。`build_path_env()` 将内嵌目录前置到 PATH。返回 `RuntimeStatus` 数据类。

**TaskManager**（`core/task_manager.py`）：在 `<workspace>/.aiguibin/tasks/task_<timestamp>/` 下创建结构化任务目录，包含 `config.json`、`logs/execution.log` 和 `outputs/`。任务状态：pending → running → completed/failed。可通过 `AIGUIBIN_TASKS_DIR` 环境变量覆盖默认任务目录。

**DependencyManager**（`core/dependency_manager.py`）：三个管理器 — `PythonDependencyManager`（pip 操作，支持从 `config/dependencies/python-dependencies.yaml` 安装）、`NodeDependencyManager`（npm 操作，支持全局/本地）、`ToolManager`（二进制工具管理，支持本地复制和 URL 下载）。

**Bootstrap**（`core/bootstrap.py`）：使用 npmmirror API 查询最新版本，自动下载 PortableGit（.7z.exe 自解压）和 Node.js（zip 扁平化解压）到 `AIGUIBIN_CLI_HOME`。版本缓存 7 天。

### 构建产物

`python build.py` 生成两种 ZIP 包：
- **lite**：不含 python/git/node 运行时（需运行 install.bat 下载）
- **full**：包含所有运行时，开箱即用

排除规则：`.git`、`.agent`、`__pycache__`、`dist`、`.pyc`/`.pyo` 等。

## 关键约定

- **注入到脚本子进程的环境变量**：`AIGUIBIN_TASK_ID`、`AIGUIBIN_TASK_DIR`、`AIGUIBIN_OUTPUT_DIR`、`AIGUIBIN_LOG_DIR`、`AIGUIBIN_WORKSPACE`、`AIGUIBIN_CLI_HOME`、`AIGUIBIN_BASH`、`AIGUIBIN_PYTHON`。脚本应使用这些变量，而不是硬编码路径。
- **脚本存放在 `scripts/` 目录下**，注册的命令在 `config/registry.yaml` 中指向它们。注册脚本的相对路径相对于 `scripts/` 解析（`ScriptExecutor.scripts_dir`）。
- **应用数据**（历史记录、日志）存放在 `AIGUIBIN_CLI_HOME` 下的 `.agent/` 目录中。历史文件为 `.agent/.aiguibin_history`，日志在 `.agent/logs/` 下（`app.log`、`bootstrap.log`、`dependencies.log`）。
- **任务输出**存放在当前工作空间下的 `.aiguibin/tasks/` 目录中，可通过 `AIGUIBIN_TASKS_DIR` 覆盖。
- **工作空间**默认为 `cwd`，可通过 `--workspace` 或 `AIGUIBIN_WORKSPACE` 环境变量覆盖。REPL 中可通过 `/cd` 切换。
- **参数**在 registry.yaml 中使用 `flag` 字段将 CLI `--flag` 映射到具名参数。位置参数用于填充未被具名 flag 满足的必选参数。
- **REPL 中的 `!` 前缀**执行 shell 命令，优先使用内嵌 Git Bash（设置 `MSYSTEM=MSYS`、`CHERE_INVOKING=1`），回退到系统 shell。
- **依赖**：`rich`、`pyyaml`、`pyreadline3`（Windows）、`openpyxl`、`xlrd==1.2.0`。
