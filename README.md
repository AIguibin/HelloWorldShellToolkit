# AIguibinCLI - 本地 Aiguibin 命令系统 完整开发文档

> **版本**: v3.5  
> **日期**: 2026-06-22  
> **项目地址**: `E:\WorkSpace\HelloWorldWorkBuddy\aiguibin-agent-terminal\`  
> **建议安装路径**: `D:\aiguibin-agent-terminal`

---

## 30 秒快速开始

> 📖 **完整安装指引**：参见 [docs/QUICKSTART.md](docs/QUICKSTART.md)

### 分发包说明

| 包名 | 体积 | 适用场景 | 是否需联网 |
|------|------|---------|-----------|
| `AIguibinCLI-v3.5-lite.zip` | ~1 MB | 网络畅通、追求最小下载 | ✅ 首次需联网 |
| `AIguibinCLI-v3.5-full.zip` | ~150 MB | 离线环境、企业内网 | ❌ 完全离线 |

### 安装步骤（3 步完成）

```
① 解压 → ② 双击 install.bat → ③ 重开终端验证
```

1. **解压** ZIP 到任意目录（推荐 `D:\AIguibinCLI`）
   - ⚠️ **禁止路径包含中文或空格**（否则 cmd.exe 编码崩溃）

2. **双击** `install.bat`
   - lite 包：自动下载 Python/Git/Node.js + 配置环境变量（约 3-5 分钟）
   - full 包：跳过下载，仅配置环境变量（约 2 秒）

3. **重新打开终端**，执行验证：
   ```batch
   aiguibin /hello
   ```
   看到欢迎信息即安装成功。

### 首次使用

```batch
aiguibin              # 进入交互式 CLI
aiguibin > /help      # 查看所有命令
aiguibin > /list      # 查看已注册脚本
aiguibin > /doctor    # 诊断运行时状态
aiguibin > /exit      # 退出
```

### 卸载

```batch
D:\AIguibinCLI\uninstall.bat    # 或者直接删除目录
```

---

## 目录

1. [项目概述](#1-项目概述)
2. [开发历程与迭代思路](#2-开发历程与迭代思路)
3. [项目结构详解](#3-项目结构详解)
4. [核心代码逻辑深度解析](#4-核心代码逻辑深度解析)
5. [数据流与调用链](#5-数据流与调用链)
6. [安装系统详解](#6-安装系统详解)
7. [使用说明与教程](#7-使用说明与教程)
8. [扩展开发指南](#8-扩展开发指南)
9. [迁移与部署说明](#9-迁移与部署说明)
10. [错误复盘与踩坑记录](#10-错误复盘与踩坑记录)
11. [开源准备清单](#11-开源准备清单)

---

## 1. 项目概述

### 1.1 AIguibinCLI 是什么

AIguibinCLI 是一个**全局命令行 Aiguibin 系统**，核心理念是：

```
/命令 → 自动路由到对应脚本 → 执行并输出结果
```

类似 Claude Code 的命令行体验——程序安装在固定目录，在任意工作空间执行 `aiguibin /命令`。

### 1.2 核心特性

| 特性 | 说明 |
|------|------|
| **`/命令` 调度** | 输入 `/hello`、`/build` 等命令自动路由到对应脚本 |
| **多语言脚本** | 支持 `.py` / `.sh` / `.bat` / `.ps1` / `.js` 等 |
| **内嵌运行时** | Git 便携版 (Git Bash) + Python Embeddable + Node.js便携版内嵌到安装目录，零依赖启动 |
| **依赖管理** | 🆕 统一管理 Python、Node.js、Shell 工具依赖，支持配置文件驱动的自动化安装 |
| **便携可移植** | 整个目录拷贝到新电脑即可运行，无需安装任何依赖 |
| **中国镜像源** | Git/Node.js 从 npmmirror 镜像下载，Python 从清华镜像下载，秒级完成 |
| **参数解析** | 支持 `--key=value`、`--flag`、`--no-flag`、位置参数 |
| **任务管理** | 每次执行自动创建任务目录，含配置、日志、输出 |

### 1.3 设计哲学

```
安装目录 (AIGUIBIN_CLI_HOME)  → 程序本体、配置、应用数据、内嵌运行时（可移植）
工作空间 (Workspace)           → 任务输出、工作上下文（跟随用户）
```

**目录结构详解**：

```
D:\AIguibinCLI\                           ← 安装目录 (AIGUIBIN_CLI_HOME)
├── aiguibin.py                           ← 主入口
├── config/                               ← 配置文件
│   ├── registry.yaml                     ← 脚本注册表
│   ├── runtime-versions.json             ← 版本号缓存
│   └── dependencies/                     ← 🆕 依赖配置目录
│       ├── python-dependencies.yaml      ← Python 依赖配置
│       ├── node-dependencies.json        ← Node.js 依赖配置
│       └── shell-tools.yaml              ← Shell 工具配置
├── .agent/                               ← 🆕 应用数据目录
│   ├── .aiguibin_history                 ← 🆕 命令历史记录
│   └── logs/                             ← 🆕 应用级日志
│       ├── app.log                       ← 主应用日志
│       ├── bootstrap.log                 ← 引导脚本日志
│       └── dependencies.log              ← 🆕 依赖操作日志
├── tools/                                ← 🆕 自定义工具目录
│   ├── binaries/                         ← 可执行二进制文件
│   ├── python/                           ← Python 自定义工具
│   ├── nodejs/                           ← Node.js 自定义工具
│   └── shell/                            ← Shell 自定义脚本
├── core/, scripts/, bin/, git/, node/, python/  ← 程序文件

E:\MyProject\                             ← 工作空间 (Workspace)
└── .aiguibin\                            ← 任务输出
    └── tasks\                            ← 仅包含任务执行结果
        └── task_20250622_123456\
            ├── config.json
            ├── logs\execution.log
            └── outputs\
```

**关键原则**：
- 安装目录的所有东西都是绿色的，整体可拷贝
- `.agent/` 存放应用级数据（配置、历史、日志），不属于工作产出
- `config/dependencies/` 管理依赖配置，支持自动化安装
- `tools/` 存放用户自定义工具，支持扩展功能
- 工作空间的 `.aiguibin/tasks/` 是任务产物，不随程序迁移
- 代码中**零硬编码路径**，一切基于 `AIGUIBIN_CLI_HOME` 和 `AIGUIBIN_AGENT_DIR` 动态计算

---

## 2. 开发历程与迭代思路

### 2.1 v1.0 — 基础 Aiguibin 系统

**起点**：用户需要一个本地 Aiguibin 系统，支持 `/命令` 调用不同脚本并传递参数。

**核心思路**：构建一个命令解析 → 注册表查找 → 脚本执行 的管线。

```
用户输入 "/hello --name=Alice"
    ↓
CommandParser 解析 → {command: "hello", kwargs: {name: "Alice"}}
    ↓
ScriptRegistry 查找 → hello.py
    ↓
ScriptExecutor 执行 → python scripts/hello.py --name=Alice
    ↓
TaskManager 记录 → 创建 task_xxx/ 目录
```

**v1.0 产出的 6 个核心模块**：

| 模块 | 职责 |
|------|------|
| `command_parser.py` | 解析 `/命令` 格式，提取命令名、键值对、布尔标志、位置参数 |
| `registry.py` | 从 YAML 加载脚本注册表，支持动态注册/取消注册/持久化 |
| `task_manager.py` | 每次执行创建任务目录，含 config.json + logs/ + outputs/ |
| `executor.py` | 子进程执行脚本，实时捕获 stdout/stderr，支持超时控制 |
| `dispatcher.py` | 路由命令：内置命令 → 注册脚本 → 未知命令提示 |
| `aiguibin.py` | 交互式 CLI 入口，readline 历史/补全，单次执行模式 |

### 2.2 v2.0 — 全局命令行工具

**需求**：像 Claude Code 一样，程序装在 D 盘，在其他工作空间执行。

**核心改造**：分离「安装目录」与「工作空间」。

```
之前: python aiguibin.py /hello        → 只能在项目目录执行
之后: aiguibin /hello                   → 在任意目录执行
```

**实现方式**：
- `bin/aiguibin.bat` — Windows 全局入口，设置 `AIGUIBIN_CLI_HOME` 后调用 `aiguibin.py`
- `install.bat` — 创建 venv + 安装依赖 + 配置 PATH + 设置 `AIGUIBIN_CLI_HOME` 环境变量
- `uninstall.bat` — 清理环境
- 任务目录从 `AIGUIBIN_CLI_HOME/.aiguibin/tasks/` 改为 `<workspace>/.aiguibin/tasks/`
- 新增 `/workspace` 和 `/cd` 命令

### 2.3 v2.5 — 多语言脚本支持

**需求**：支持 `.sh` / `.bat` / `.ps1` / `.js` 脚本。

**实现方式**：
- `executor.py` 根据扩展名自动选择解释器
- 新增 4 种语言示例脚本
- 发现 Windows shebang `python3` 解析到 Microsoft Store 别名 → 改为扩展名优先

### 2.4 v3.0 — MSYS2 内嵌集成（历史版本）

**需求**：嵌入 MSYS2 到安装目录，实现「开箱即用、零依赖、全功能」。

**核心思路**：
- MSYS2 自解压包 `.sfx.exe` 是绿色安装，解压即用
- Python Embeddable 也是单目录绿色安装
- 三级回退：内嵌 → 宿主机 → 报错

**新增**：
- `core/runtime.py` — 运行时检测与路径管理（RuntimeDetector）
- `/shell`, `/install-pkg`, `/env`, `/doctor` 内置命令
- `install.bat` 12步全自动安装（MSYS2 + Python + 清华镜像 + PATH）

> ⚠️ **v3.5 已移除 MSYS2**，改用 Git 便携版 + Node.js，详见 2.5 节。

### 2.5 v3.5 — Git 便携版 + Node.js 内嵌（当前版本）

**需求**：MSYS2 (306MB) 无法安装包且体积臃肿，实际只用 `usr/bin/bash.exe`(2.4MB)。决定移除 MSYS2，改用 Git 便携版（自带 Git Bash）+ Node.js 便携版，启动逻辑借鉴 Claude Code CLI 的 Python 引导模式。

**核心思路**：
- Git 便携版 (~60MB) 替代 MSYS2 (306MB)，自带 Git Bash（基于 MSYS2 runtime，完全兼容）
- 新增 Node.js 22.x 便携版 (~35MB)，让 `/install-pkg` 改用 npm
- 首次启动自动检测并下载缺失组件（bootstrap.py）
- 体积减少 70%（306MB → ~95MB）

**新增**：
- `core/bootstrap.py` — 自动从 npmmirror 查询最新版本并下载 Git + Node.js 的引导脚本
- 版本号缓存到 `config/runtime-versions.json`（7天 TTL）

**变更**：
- `core/runtime.py` — `msys2_available` → `git_available`，`get_msys_home()` → `get_git_home()`
- `core/dispatcher.py` — `/shell` 启动 Git Bash，`/install-pkg` 改用 npm
- `bin/aiguibin.bat` — 新增 bootstrap.py 调用，设置 `AIGUIBIN_NODE` 环境变量
- `install.bat` — 重写 14 步（Python + PortableGit + Node.js）
- `scripts/setup_msys.py` — 已删除
- `msys64/` 目录 — 已删除（释放 306MB）

---

## 3. 项目结构详解

```
AIguibinCLI/                              ← AIGUIBIN_CLI_HOME（安装目录）
├── aiguibin.py                           ← 主入口（交互式 CLI + 单次执行模式）
├── requirements.txt                   ← Python 依赖声明
├── install.bat                        ← 🔥 12步全自动安装脚本
├── uninstall.bat                      ← 卸载脚本
│
├── bin/
│   ├── aiguibin.bat                      ← 🔥 CMD 入口脚本
│   ├── aiguibin.ps1                      ← 🔥 PowerShell 入口脚本
│   └── aiguibin                       ← 🔥 Bash 入口脚本（Git Bash）
│
├── config/
│   ├── registry.yaml                 ← 脚本注册表配置
│   └── runtime-versions.json         ← 🆕 Git/Node.js 版本号缓存（7天TTL）
│
├── core/                              ← 🔥 核心模块（9 个文件）
│   ├── __init__.py
│   ├── command_parser.py             ← 命令解析器
│   ├── registry.py                   ← 脚本注册机制
│   ├── task_manager.py               ← 任务目录管理
│   ├── executor.py                   ← 脚本执行引擎
│   ├── dispatcher.py                 ← 命令调度器
│   ├── runtime.py                    ← 运行时检测与路径管理
│   ├── bootstrap.py                  ← 🆕 自动下载 Git + Node.js 引导脚本
│   └── dependency_manager.py         ← 🆕 依赖管理模块
│
├── scripts/                           ← 内置脚本
│   ├── hello.py                      ← 示例：Python 脚本
│   ├── build.py                      ← 示例：构建项目
│   ├── deploy.py                     ← 示例：部署
│   ├── sysinfo.py                     ← 示例：系统信息
│   ├── diskinfo.py                   ← 示例：磁盘空间
│   ├── gitinfo.sh                    ← 示例：Bash 脚本
│   ├── ping.ps1                      ← 示例：PowerShell 脚本
│   ├── npmcheck.js                   ← 示例：Node.js 脚本
│   ├── aiguibin-compare-excel.py     ← 🆕 Excel 并排对比工具
│   ├── aiguibin-link-remote-repo.sh  ← 🆕 远程仓库关联脚本
│   └── dependency_examples.py        ← 🆕 依赖管理示例
│
├── git/                              ← 🆕 内嵌 Git 便携版（替代 MSYS2）
│   ├── usr/bin/bash.exe              ← Git Bash 核心
│   ├── bin/git.exe                   ← Git 本体
│   └── ...
│
├── node/                             ← 🆕 内嵌 Node.js 22.x 便携版
│   ├── node.exe                      ← Node.js 运行时
│   ├── npm.cmd                       ← npm 包管理器
│   └── ...
│
├── python/                            ← 内嵌 Python 3.13.3 Embeddable
│   ├── python.exe                    ← Python 解释器
│   ├── python313._pth                ← Python 路径配置（已修改，启用 pip）
│   ├── python313.zip                 ← 标准库
│   ├── Lib/site-packages/            ← 第三方包（rich, pyyaml, pyreadline3, openpyxl）
│   ├── Scripts/pip.exe               ← pip
│   └── ...
│
├── docs/                               ← 🆕 完整文档系统
│   ├── README.md                       ← 文档中心索引
│   ├── QUICKSTART.md                   ← 快速开始指南
│   ├── DEV_GUIDELINES.md               ← 🆕 开发规范文档
│   ├── ARCHITECTURE.md                 ← 🆕 架构设计文档
│   ├── API.md                          ← 🆕 API 接口文档
│   ├── DEPENDENCIES.md                 ← 🆕 依赖管理详细文档
│   ├── CHANGELOG.md                    ← 🆕 版本变更日志
│   └── CONTRIBUTING.md                 ← 🆕 贡献指南
│
├── tools/                              ← 🆕 自定义工具目录
│   ├── binaries/                       ← 可执行二进制文件
│   ├── python/                         ← Python 自定义工具
│   ├── nodejs/                         ← Node.js 自定义工具
│   └── shell/                          ← Shell 自定义脚本
│
├── dist/                               ← 🆕 构建产物目录
└── build.py                            ← 🆕 打包脚本（Python 版，简单可靠）
```

### 3.1 运行时在工作空间的产物

```
E:\MyProject\                          ← 用户工作空间
└── .aiguibin/
    └── tasks/
        └── task_20260615_143022/
            ├── config.json            ← 任务配置（命令、参数、状态）
            ├── logs/
            │   └── execution.log      ← 执行日志
            └── outputs/               ← 脚本输出文件
                └── hello_result.txt
```

### 3.2 文件职责速查

| 文件 | 行数 | 核心类/函数 | 一句话描述 |
|------|------|------------|-----------|
| `aiguibin.py` | ~357 | `AiguibinCLI`, `main()` | 入口，启动交互式 CLI 或单次执行 |
| `core/command_parser.py` | ~123 | `CommandParser.parse()` | 解析 `/cmd --key=val arg1` 格式 |
| `core/registry.py` | ~200 | `ScriptRegistry`, `CommandDef`, `ParamDef` | 从 YAML 加载脚本定义，动态注册 |
| `core/task_manager.py` | ~123 | `TaskManager` | 每次执行创建任务目录，记录状态 |
| `core/executor.py` | ~310 | `ScriptExecutor`, `_detect_interpreter()` | 子进程执行脚本，自动选择解释器 |
| `core/dispatcher.py` | ~1068 | `Dispatcher` | 路由命令到内置处理器或注册脚本 |
| `core/runtime.py` | ~232 | `RuntimeDetector`, `RuntimeStatus` | 检测内嵌/系统运行时，构建 PATH |
| `bin/aiguibin.bat` | ~44 | - | CMD 入口，查找 Python 并启动 |
| `bin/aiguibin.ps1` | ~55 | - | PowerShell 入口，同上逻辑 |
| `bin/aiguibin` | ~85 | - | Bash 入口（Git Bash），含路径转换 |
| `install.bat` | ~302 | - | 14 步全自动安装 |

---

## 4. 核心代码逻辑深度解析

### 4.1 启动流程

**多 Shell 入口**：AIguibinCLI 提供 3 个入口脚本，功能完全等价，适配不同终端：

```
用户执行: aiguibin /hello --name=Alice
    ↓
┌──────────────────────────────────────────────────────────┐
│ 入口脚本（根据当前 Shell 自动选择）                         │
│                                                          │
│  CMD             → bin/aiguibin.bat                         │
│  PowerShell      → bin/aiguibin.ps1                         │
│  Git Bash           → bin/aiguibin (bash)                      │
│                                                          │
│  三者逻辑一致:                                            │
│    1. 解析 AIGUIBIN_CLI_HOME = 脚本所在目录的上级                  │
│    2. 查找 Python (内嵌 → .venv → 系统)                   │
│    3. 设置 AIGUIBIN_BASH / AIGUIBIN_PYTHON 环境变量             │
│    4. exec python aiguibin.py $@                            │
└──────────────────────────────────────────────────────────┘
    ↓
[aiguibin.py - main()]
    workspace = resolve_workspace()     → 解析工作空间
    args 有内容? → run_single()       → 单次执行模式
    args 为空?  → AiguibinCLI().run()    → 交互式模式
    ↓
[aiguibin.py - create_components()]
    runtime_detector = RuntimeDetector(AIGUIBIN_CLI_HOME)
    registry = ScriptRegistry(config, scripts_dir)
    executor = ScriptExecutor(scripts_dir, AIGUIBIN_CLI_HOME=AIGUIBIN_CLI_HOME)
    dispatcher = Dispatcher(registry, task_manager, executor, console, AIGUIBIN_CLI_HOME)
    parser = CommandParser()
```

### 4.2 命令解析 (command_parser.py)

**输入格式**：
```
/hello --name=Alice --verbose arg1 arg2 -v
```

**解析规则**（按 token 遍历）：

| Token 模式 | 解析结果 | 示例 |
|------------|---------|------|
| `/xxx` | 命令名（去掉 `/`） | `/hello` → `command="hello"` |
| `--key=value` | 键值对 | `--name=Alice` → `kwargs={"name": "Alice"}` |
| `--key value` | 键值对（下一 token 不是 `-` 开头） | `--name Alice` → 同上 |
| `--flag` | 布尔标志（启用） | `--verbose` → `flags={"verbose"}` |
| `--no-flag` | 布尔标志（禁用） | `--no-verbose` → flags 中不含 `verbose` |
| `-x` | 短标志 | `-v` → `flags={"v"}` |
| 其他 | 位置参数 | `arg1` → `positional_args=["arg1"]` |

**自动类型转换** (`_auto_convert`)：
- `"true"` / `"false"` → `bool`
- `"none"` / `"null"` → `None`
- `"42"` → `int`
- `"3.14"` → `float`
- 其他 → `str`

### 4.3 脚本注册 (registry.py)

**YAML 配置格式**：
```yaml
commands:
  - name: hello              # /hello 命令名
    script: hello.py         # scripts/ 下的脚本文件
    description: 向世界问好
    tags: [demo, greeting]
    params:
      - name: name           # 参数名
        type: string          # 类型: string/int/float/bool/choice
        required: false       # 是否必填
        default: World        # 默认值
        description: 问候对象
        flag: name            # CLI flag 名（--name）
```

**运行时动态注册**：
```python
# /register mytool mytool.py "我的工具"
registry.register("mytool", "mytool.py", "我的工具")
# → 持久化到 registry.yaml
```

**参数校验**：
- 必填参数缺失 → 报错
- choice 类型值不在允许范围 → 报错

### 4.4 运行时检测 (runtime.py)

**三级回退策略**：

```
内嵌路径（AIGUIBIN_CLI_HOME 下）→ shutil.which()（宿主机 PATH）→ None
```

**RuntimeDetector 核心方法**：

| 方法 | 内嵌路径 | 系统回退 |
|------|---------|---------|
| `get_python_path()` | `AIGUIBIN_CLI_HOME/python/python.exe` | `sys.executable` |
| `get_bash_path()` | `AIGUIBIN_CLI_HOME/git/usr/bin/bash.exe` | `shutil.which("bash")` |
| `get_node_path()` | `AIGUIBIN_CLI_HOME/node/node.exe` | `shutil.which("node")` |
| `get_git_home()` | `AIGUIBIN_CLI_HOME/git/` | None |

**PATH 构建** (`build_path_env`)：

```
内嵌 Python 目录;
内嵌 Git usr/bin;
内嵌 Git bin;
内嵌 Node.js 目录;
系统 PATH
```

**用途**：子进程执行时注入这个 PATH，确保脚本优先使用内嵌工具。

### 4.5 脚本执行 (executor.py)

**解释器选择逻辑** (`_detect_interpreter`)：

```
扩展名 .py  → RuntimeDetector.get_python_path() → 内嵌 Python / sys.executable
扩展名 .sh  → RuntimeDetector.get_bash_path()   → 内嵌 Bash / 系统 bash
扩展名 .js  → RuntimeDetector.get_node_path()    → 内嵌 Node / 系统 node
扩展名 .bat → cmd /c
扩展名 .ps1 → powershell -ExecutionPolicy Bypass -File
其他        → 读 shebang → 内嵌 Bash / 直接执行
```

**⚠️ 重要设计决策**：扩展名检测优先于 shebang。

原因：Windows 上 `#!/usr/bin/env python3` 的 `python3` 会被解析到 Microsoft Store 别名，导致打开 Microsoft Store 而非执行 Python。

**环境变量注入**（脚本可通过 `os.environ` 获取）：

| 环境变量 | 值 | 说明 |
|---------|-----|------|
| `AIGUIBIN_CLI_HOME` | 安装目录 | 程序根目录 |
| `AIGUIBIN_BASH` | 内嵌 Bash 路径 | 脚本中可调用 |
| `AIGUIBIN_PYTHON` | 内嵌 Python 路径 | 脚本中可调用 |
| `AIGUIBIN_TASK_ID` | `task_YYYYMMDD_HHMMSS` | 当前任务 ID |
| `AIGUIBIN_TASK_DIR` | 任务目录 | 含 config.json, logs/, outputs/ |
| `AIGUIBIN_OUTPUT_DIR` | 输出目录 | 脚本写产出文件 |
| `AIGUIBIN_WORKSPACE` | 工作空间 | 用户当前目录 |
| `PATH` | 内嵌路径 + 系统 PATH | 内嵌工具优先 |

**子进程执行流程**：
```
1. 构建命令（解释器 + 脚本 + 参数）
2. 复制 os.environ + 注入 AIGUIBIN_* 变量
3. 用 RuntimeDetector.build_path_env() 构建 PATH
4. subprocess.Popen 执行
5. 双线程读取 stdout/stderr（实时回调）
6. 超时 kill / 正常退出
7. 返回 ExecutionResult(success, return_code, stdout, stderr, duration)
```

### 4.6 命令调度 (dispatcher.py)

**调度优先级**：
```
1. 内置命令（help, list, status, register, ...）→ 直接处理
2. 注册脚本（hello, build, deploy, ...）          → ScriptExecutor 执行
3. 未知命令                                       → 提示 /help
```

**内置命令清单**：

| 命令 | 方法 | 说明 |
|------|------|------|
| `/help` | `_cmd_help()` | 显示帮助面板 + 内置命令表 + 注册脚本表 |
| `/list` | `_cmd_list()` | 列出所有注册脚本 |
| `/status` | `_cmd_status()` | 查看最近任务状态 |
| `/register` | `_cmd_register()` | 动态注册新脚本 |
| `/unregister` | `_cmd_unregister()` | 取消注册 |
| `/reload` | `_cmd_reload()` | 重新加载 registry.yaml |
| `/workspace` | `_cmd_workspace()` | 查看工作空间信息 |
| `/cd <path>` | `_cmd_cd()` | 切换工作空间 |
| `/shell` | `_cmd_shell()` | 启动内嵌 Git Bash |
| `/install-pkg` | `_cmd_install_pkg()` | npm 全局安装包 |
| `/env` | `_cmd_env()` | 显示运行时路径 |
| `/doctor` | `_cmd_doctor()` | 诊断运行时完整性 |
| `/exit` | `_cmd_exit()` | 退出 |

**脚本执行流程** (`_execute_script`)：
```
1. 参数校验（registry.validate_params）
2. 创建任务（task_manager.create_task）
3. 构建参数列表（_build_args）
4. 注入环境变量（AIGUIBIN_* + AIGUIBIN_BASH + AIGUIBIN_PYTHON）
5. executor.execute() 执行脚本
6. 更新任务状态（completed / failed）
7. 输出执行结果（耗时、退出码）
```

### 4.7 任务管理 (task_manager.py)

**任务目录结构**：
```
<workspace>/.aiguibin/tasks/task_20260615_143022/
├── config.json            ← {task_id, command, args, status, workspace, created_at}
├── logs/
│   └── execution.log     ← [timestamp] 日志行
└── outputs/               ← 脚本输出文件
```

**状态流转**：`pending` → `running` → `completed` / `failed`

**关键环境变量** `AIGUIBIN_TASKS_DIR`：可通过环境变量自定义任务目录位置。

### 4.8 python313._pth 详解

这是 Python Embeddable 的路径配置文件，**决定了 Python 搜索模块的路径**：

```ini
python313.zip           ← 标准库（压缩包形式）
.                       ← 当前目录
Lib\site-packages       ← 第三方包目录（必须手动添加）

# Enable site module for pip support
import site             ← 启用 site 模块（必须添加，否则 pip 不可用）
```

**⚠️ 原始 _pth 没有 `Lib\site-packages` 和 `import site`**，必须手动修改。

**⚠️ 不要用 PowerShell 写此文件**：`Set-Content -Encoding UTF8` 会加 BOM，导致 Python 解析失败。用 `cmd echo >` 写入。

---

## 5. 数据流与调用链

### 5.1 交互式模式

```
┌─────────────────────────────────────────────────────┐
│ 用户输入: /hello --name=Alice                       │
└──────────────────────┬──────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────┐
│ CommandParser.parse()                                │
│   → ParsedCommand(                                   │
│       command="hello",                                │
│       kwargs={"name": "Alice"},                       │
│       flags=set(),                                    │
│       positional_args=[]                              │
│     )                                                 │
└──────────────────────┬───────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────┐
│ Dispatcher.dispatch(parsed)                          │
│   1. "hello" 不是内置命令 → 跳过                     │
│   2. registry.get("hello") → CommandDef              │
│   3. validate_params() → OK                           │
│   4. _execute_script(cmd_def, parsed)                │
└──────────────────────┬───────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────┐
│ _execute_script()                                    │
│   1. task_manager.create_task("hello", {...})         │
│      → task_20260615_143022/                          │
│   2. _build_args(parsed) → ["--name=Alice"]          │
│   3. 注入环境变量 AIGUIBIN_*                             │
│   4. executor.execute("hello.py", args, env)         │
└──────────────────────┬───────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────┐
│ ScriptExecutor.execute()                             │
│   1. _detect_interpreter("hello.py") → [python.exe]  │
│   2. 构建 command: [python.exe, hello.py, --name=...] │
│   3. 注入 PATH (内嵌优先)                             │
│   4. subprocess.Popen() 执行                         │
│   5. 双线程读取 stdout/stderr                         │
│   6. 返回 ExecutionResult                            │
└──────────────────────┬───────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────┐
│ Dispatcher 输出结果                                   │
│   ✅ Done (0.15s)                                    │
└──────────────────────────────────────────────────────┘
```

### 5.2 单次执行模式

```
aiguibin /hello --name=Alice
    ↓
bin/aiguibin.bat
    ↓ SET AIGUIBIN_CLI_HOME, AIGUIBIN_PYTHON
python.exe aiguibin.py /hello --name=Alice
    ↓
main() → args 非空 → run_single()
    ↓
create_components() → dispatcher.dispatch(parser.parse("/hello --name=Alice"))
    ↓ （同上交互式流程）
```

---

## 6. 安装系统详解

### 6.1 install.bat 14 步流程

```
[0/12] 确定安装目录
       SET INSTALL_DIR = %~dp0 （脚本所在目录）

[1/12] 校验路径
       检查空格、中文字符（findstr）

[2/12] 设置 AIGUIBIN_CLI_HOME 环境变量
       [Environment]::SetEnvironmentVariable('AIGUIBIN_CLI_HOME', '...', 'User')

[3/12] 下载 Python Embeddable
       URL: https://mirrors.tuna.tsinghua.edu.cn/python/3.13.3/python-3.13.3-embed-amd64.zip
       跳过: python/python.exe 已存在

[4/12] 解压 Python
       方式: PowerShell Expand-Archive
       产出: python/ 目录

[5/12] 配置 python313._pth
       写入: python313.zip / . / Lib\site-packages / import site
       方式: cmd echo >> （不用 PowerShell，避免 BOM）

[6/12] 安装 pip
       下载: https://bootstrap.pypa.io/get-pip.py
       执行: python/python.exe get-pip.py

[7/12] 安装 Python 依赖
       命令: python/python.exe -m pip install rich pyyaml pyreadline3 openpyxl --target "python/Lib/site-packages"
       ⚠️ --target 确保安装到本地，不依赖用户级 site-packages

[8/14] 下载 PortableGit
       URL: https://registry.npmmirror.com/-/binary/git-for-windows/v2.54.0.windows.1/PortableGit-2.54.0-64-bit.7z.exe
       跳过: git/usr/bin/bash.exe 已存在

[9/14] 解压 PortableGit
       命令: PortableGit-*.7z.exe -y -o<INSTALL_DIR>\git
       产出: git/ 目录

[10/14] 下载 Node.js 便携版
        URL: https://registry.npmmirror.com/-/binary/node/v22.0.0/node-v22.0.0-win-x64.zip
        跳过: node/node.exe 已存在

[11/14] 解压 Node.js
        方式: PowerShell Expand-Archive + Move-Item（扁平化到 node/）
        产出: node/ 目录

[12/14] 配置 PATH
        将 bin/ 加入用户 PATH
        将 .PS1 加入 PATHEXT

清理: 删除 .7z.exe / .zip / get-pip.py
```

### 6.2 依赖管理系统

**v3.5 新增功能**：统一的依赖管理系统，支持 Python、Node.js 和 Shell 工具的安装、更新、卸载和查询。

#### 6.2.1 配置文件

依赖配置存放在 `config/dependencies/` 目录：

- **python-dependencies.yaml**: Python 依赖配置
- **node-dependencies.json**: Node.js 依赖配置
- **shell-tools.yaml**: Shell 工具配置

#### 6.2.2 命令行接口

**Python 依赖管理**：
```batch
# 列出已安装的包
/list-python                    # 表格显示包名、版本

# 安装包
/install-python <package>       # 安装到内嵌 Python
/install-python --from-file     # 从配置文件安装

# 更新包
/update-python <package>        # 更新指定包
/update-python --all            # 更新所有包

# 卸载包
/uninstall-python <package>     # 卸载指定包

# 导出依赖
/export-python                  # 导出当前安装到配置文件
```

**Node.js 依赖管理**：
```batch
# 列出已安装的包
/list-node                      # 显示全局和本地包
/list-node --global             # 仅显示全局包

# 安装包
/install-node <package>         # 本地安装
/install-node --global <package> # 全局安装

# 更新包
/update-node <package>          # 更新指定包
/update-node --global           # 更新所有全局包

# 卸载包
/uninstall-node <package>       # 卸载指定包
```

**Shell 工具管理**：
```batch
# 列出工具
/list-tools                     # 显示已安装的工具

# 添加工具
/add-tool <url> <name>          # 从网络下载
/add-tool --local <path> <name> # 从本地添加

# 移除工具
/remove-tool <name>             # 移除指定工具
```

**统一管理命令**：
```batch
# 配置管理
/dep-config                     # 查看依赖配置

# 同步依赖
/dep-sync                       # 根据配置文件同步安装
/dep-sync --check-only          # 仅检查差异
```

#### 6.2.3 日志和监控

所有依赖操作记录到 `.agent/logs/dependencies.log`，包含：
- 操作时间戳
- 操作类型（安装/卸载/更新）
- 包/工具名称
- 操作结果
- 错误信息（如果失败）

### 6.3 aiguibin.bat Python 查找优先级

```
1. AIGUIBIN_CLI_HOME\python\python.exe       ← 内嵌 Python（推荐）
2. AIGUIBIN_CLI_HOME\.venv\Scripts\python.exe ← venv Python
3. python                              ← 系统 PATH 中的 Python
```

### 6.4 内嵌 Python vs 系统 Python

| 特性 | 内嵌 Python | 系统 Python |
|------|------------|------------|
| 路径 | `AIGUIBIN_CLI_HOME\python\python.exe` | `C:\Python313\python.exe` |
| 标准库 | `python313.zip`（压缩） | `Lib\` 目录 |
| 第三方包 | `Lib\site-packages\` | 用户级/系统级 site-packages |
| pip | 通过 `get-pip.py` 注入 | 自带 |
| 隔离性 | ✅ 完全隔离 | ❌ 可能与系统冲突 |
| 便携性 | ✅ 随目录迁移 | ❌ 依赖安装位置 |

---

## 7. 使用说明与教程

### 7.1 首次安装

```batch
# 1. 解压 AIguibinCLI/ 到 D:\AIguibinCLI\
# 2. 双击 install.bat
# 3. 等待安装完成（约 2-5 分钟）
# 4. 重新打开终端
```

### 7.2 多 Shell 入口

Aiguibin 支持 3 种终端入口，安装后 `aiguibin` 命令在所有终端通用：

| 终端 | 入口文件 | 启动方式 | 说明 |
|------|---------|---------|------|
| **CMD** | `bin/aiguibin.bat` | `aiguibin` | 默认入口，Windows 自带 |
| **PowerShell** | `bin/aiguibin.ps1` | `aiguibin` 或 `aiguibin.ps1` | install.bat 自动添加 `.PS1` 到 PATHEXT |
| **Git Bash** | `bin/aiguibin` | `aiguibin` | 无扩展名，bash 直接执行 |
| **Git Bash** | `bin/aiguibin` | `aiguibin` | 内嵌 Git Bash 终端也可调用 |

**各终端使用示例**：

```batch
# CMD
aiguibin /hello --name=CMD

# PowerShell
aiguibin /hello --name=PowerShell
# 或者显式调用
aiguibin.ps1 /hello --name=PowerShell

# Git Bash
aiguibin /hello --name=GitBash
```

**⚠️ Bash 入口注意事项**：
- Git Bash 中使用 `cygpath -w` 将路径转为 Windows 格式（内嵌 Python 需要）
- 设置 `MSYS_NO_PATHCONV=1` 防止 Git Bash 自动将 `/env` 等命令参数转为路径
- 如遇路径问题，请确认 `cygpath` 命令可用（Git Bash 默认自带）

### 7.3 交互式使用

```batch
# 启动交互式 CLI
aiguibin

# 进入后：
aiguibin [MyProject] > /help          # 查看帮助
aiguibin [MyProject] > /list          # 列出所有命令
aiguibin [MyProject] > /hello         # 执行脚本
aiguibin [MyProject] > /hello --name=Agent
aiguibin [MyProject] > /sysinfo       # 系统信息
aiguibin [MyProject] > /env           # 运行时路径
aiguibin [MyProject] > /doctor        # 诊断
aiguibin [MyProject] > /shell         # 打开内嵌 Bash
aiguibin [MyProject] > !ls -la        # 执行 shell 命令
aiguibin [MyProject] > /cd D:\Other   # 切换工作空间
aiguibin [MyProject] > /exit          # 退出
```

### 7.4 单次执行（非交互式）

```batch
aiguibin /hello --name=World
aiguibin /sysinfo --section=python
aiguibin /gitinfo
aiguibin /diskinfo
aiguibin /doctor
```

### 7.5 Excel 并排对比（/compare-excel）

以 A.xlsx 为基准，左右并排展示两个 Excel 文件的差异，差异单元格标记为黄色背景+红色加粗：

```batch
# 基本用法：自动检测关键列
aiguibin /compare-excel A.xlsx B.xlsx

# 指定关键列
aiguibin /compare-excel A.xlsx B.xlsx --key-col=工号

# 自动检测唯一列
aiguibin /compare-excel A.xlsx B.xlsx --auto-key

# 指定输出路径
aiguibin /compare-excel A.xlsx B.xlsx --output=result.xlsx

# 指定对比的 Sheet（逗号分隔）
aiguibin /compare-excel A.xlsx B.xlsx --sheets=Sheet1,Sheet2

# 组合使用
aiguibin /compare-excel A.xlsx B.xlsx --key-col=Name --output=diff.xlsx --auto-key
```

**参数说明**：

| 参数 | 说明 | 示例 |
|------|------|------|
| `file_a` `file_b` | 位置参数：两个 Excel 文件路径 | `A.xlsx B.xlsx` |
| `--output` | 输出文件路径 | `--output=result.xlsx` |
| `--key-col` | 手动指定关键列名或列字母 | `--key-col=工号` 或 `--key-col=B` |
| `--auto-key` | 自动检测值唯一的列作为关键列 | `--auto-key` |
| `--sheets` | 指定对比的 Sheet（逗号分隔） | `--sheets=Sheet1,Sheet2` |

### 7.6 通过 npm 安装包

```batch
# 在 aiguibin 交互式模式中：
aiguibin [MyProject] > /install-pkg git vim curl
aiguibin [MyProject] > /install-pkg make gcc

# 或直接用内嵌 Bash：
aiguibin [MyProject] > /shell
$ /install-pkg typescript
$ exit
```

### 7.7 注册自定义脚本

**方式一：命令行注册**

```batch
aiguibin [MyProject] > /register mytool mytool.py "我的工具"
```

**方式二：编辑 YAML 文件**

编辑 `config/registry.yaml`：

```yaml
commands:
  - name: mytool
    script: mytool.py
    description: 我的自定义工具
    tags: [custom]
    params:
      - name: input
        type: string
        required: true
        description: 输入文件
        flag: input
```

然后执行 `/reload` 或重启。

---

## 8. 扩展开发指南

### 8.1 添加新的 Python 脚本

**步骤**：

1. 在 `scripts/` 下创建脚本文件

```python
#!/usr/bin/env python3
"""
/mycommand - 我的命令

用法:
  /mycommand --input=file.txt
"""

import argparse
import os
import sys

def main():
    parser = argparse.ArgumentParser(description="我的命令")
    parser.add_argument("--input", required=True, help="输入文件")
    args = parser.parse_args()

    # 获取 Aiguibin 注入的环境变量
    task_id = os.environ.get("AIGUIBIN_TASK_ID", "N/A")
    output_dir = os.environ.get("AIGUIBIN_OUTPUT_DIR", ".")

    print(f"Task: {task_id}")
    print(f"Input: {args.input}")

    # 在输出目录生成结果
    result_path = os.path.join(output_dir, "result.txt")
    with open(result_path, "w", encoding="utf-8") as f:
        f.write(f"Processed: {args.input}\n")
    print(f"Result: {result_path}")

if __name__ == "__main__":
    main()
```

2. 在 `config/registry.yaml` 中注册

```yaml
- name: mycommand
  script: mycommand.py
  description: 我的命令
  tags: [custom]
  params:
    - name: input
      type: string
      required: true
      description: 输入文件
      flag: input
```

3. 测试

```batch
aiguibin /mycommand --input=test.txt
```

### 8.2 添加 Bash 脚本

```bash
#!/usr/bin/env bash
# /myscript - 我的 Bash 脚本

AIGUIBIN_OUTPUT_DIR="${AIGUIBIN_OUTPUT_DIR:-.}"
AIGUIBIN_WORKSPACE="${AIGUIBIN_WORKSPACE:-.}"

echo "Workspace: $AIGUIBIN_WORKSPACE"
echo "Output: $AIGUIBIN_OUTPUT_DIR"

# 在输出目录生成结果
echo "Done at $(date)" > "$AIGUIBIN_OUTPUT_DIR/myscript_result.txt"
```

**关键点**：
- Bash 脚本通过内嵌 Git Bash 执行，有完整的 GNU 工具链
- 环境变量 `AIGUIBIN_OUTPUT_DIR`、`AIGUIBIN_WORKSPACE` 等会自动注入
- 注册时 `script: myscript.sh`，扩展名决定解释器

### 8.3 添加新的内置命令

在 `core/dispatcher.py` 中：

```python
# 1. 在 __init__ 的 self._builtins 中注册
self._builtins = {
    # ... 已有命令
    "mycommand": self._cmd_mycommand,
}

# 2. 实现处理方法
def _cmd_mycommand(self, parsed: ParsedCommand) -> bool:
    """我的内置命令"""
    self.console.print("[cyan]执行我的命令...[/cyan]")
    # ... 逻辑
    return True  # True = 继续运行, False = 退出
```

### 8.4 添加新的运行时检测

在 `core/runtime.py` 的 `RuntimeDetector` 中：

```python
def get_rust_path(self) -> str | None:
    """获取 Rust/Cargo 路径"""
    # 内嵌路径
    embedded_node = os.path.join(self.AIGUIBIN_CLI_HOME, "node", "node.exe")
    if os.path.isfile(embedded_rust):
        return embedded_rust
    # 系统回退
    return shutil.which("cargo")
```

### 8.5 修改 Python Embeddable 版本

1. 修改 `install.bat` 中的 URL：
   - 清华镜像：`https://mirrors.tuna.tsinghua.edu.cn/python/<版本>/python-<版本>-embed-amd64.zip`
2. 修改 `python313._pth` 为对应版本的 `python<版本号去掉点>._pth`
3. 修改 `requirements.txt` 中的依赖版本

---

## 9. 迁移与部署说明

### 9.1 整包迁移（推荐）

```batch
# 1. 将整个 AIguibinCLI/ 目录复制到新电脑
xcopy /E /I D:\AIguibinCLI \\NewPC\D$\AIguibinCLI

# 2. 在新电脑上运行 install.bat（仅更新环境变量和 PATH）
#    install.bat 会检测已有组件并跳过

# 3. 重新打开终端
```

### 9.2 目录迁移（同电脑）

```batch
# 1. 移动目录
move D:\AIguibinCLI E:\Tools\AIguibinCLI

# 2. 重新运行 install.bat
#    它会更新 AIGUIBIN_CLI_HOME 环境变量和 PATH

# 3. 重新打开终端
```

### 9.3 重新打包分发

**精简包**（~150MB）：
```
AIguibinCLI/
├── aiguibin.py, core/, scripts/, config/, bin/
├── install.bat, uninstall.bat, requirements.txt
├── git/                ← Git 便携版基础
└── python/              ← Python Embeddable + 依赖
```

**源码包**（~1MB）：
```
AIguibinCLI/
├── aiguibin.py, core/, scripts/, config/, bin/
├── install.bat, uninstall.bat, requirements.txt
└── (不含 git/、node/ 和 python/)
```
用户运行 `install.bat` 后自动下载。

### 9.4 路径自适应机制

**代码层面**：所有路径基于 `AIGUIBIN_CLI_HOME` 动态计算：
```python
AIGUIBIN_CLI_HOME = os.path.dirname(os.path.abspath(__file__))  # aiguibin.py
# 或
AIGUIBIN_CLI_HOME = os.environ.get("AIGUIBIN_CLI_HOME")                 # 子进程
```

**Git Bash 层面**：Git 便携版的路径映射基于 `git/etc/fstab`，会根据实际安装位置自动调整。

**环境变量层面**：`install.bat` 每次运行都会更新 `AIGUIBIN_CLI_HOME` 环境变量。

### 9.5 跨平台说明

当前仅支持 Windows。如需支持 Linux/macOS：

1. `bin/aiguibin` — 已有 Unix 入口脚本框架
2. `install.sh` — 需编写等效的 Shell 安装脚本
3. Git 便携版 — Linux/macOS 不需要 Git 便携版（自带 Bash）
4. Python Embeddable — Linux/macOS 用 venv 替代
5. `runtime.py` — 需调整路径检测逻辑

---

## 10. 错误复盘与踩坑记录

### 10.1 install.bat UTF-8 编码崩溃

**现象**：双击 `install.bat`，cmd.exe 直接报语法错误退出。

**根因**：
- install.bat 用 UTF-8 编码保存
- Windows cmd.exe 默认使用 GBK (code page 936)
- 文件中的中文注释和 Box-drawing 字符（`━`）在 GBK 下被解析为乱码
- 乱码中恰好出现 `|`、`<`、`>` 等 shell 特殊字符，导致语法错误

**修复**：所有 `.bat` 文件改用纯 ASCII 编码，中文注释改为英文，Box-drawing 字符改为 `=`。

**教训**：Windows batch 文件**必须**使用系统默认编码（GBK）或纯 ASCII。绝不能用 UTF-8。

### 10.2 PowerShell Invoke-WebRequest 下载二进制文件损坏

**现象**：
- Python Embeddable ZIP 下载后解压失败
- 文件大小 3.7MB（应为 ~10.4MB）
- `zipfile.ZipFile` 报 `BadZipFile`

**根因**：
- PowerShell `Invoke-WebRequest` 在某些环境下会损坏二进制文件
- 可能是 TLS 握手、代理、或编码转换问题

**修复**：
1. ~~尝试 `WebClient.DownloadFile`~~ → 同样损坏
2. ~~尝试 Python `urllib.request.urlretrieve`~~ → 可以但极慢（python.org 海外服务器）
3. ✅ **改用清华镜像** + `Invoke-WebRequest` → 5 秒完成，文件完整

**教训**：
- 下载大文件优先用国内镜像
- `Invoke-WebRequest` 下载后**必须验证文件完整性**（大小、ZIP 头）
- install.bat 中已改为清华镜像 URL

### 10.3 MSYS2 下载 URL 404（v3.0 历史问题，v3.5 已改用 Git 便携版）

**现象**：`msys2-base-x86_64-latest.sfx.exe` 下载 404。

**根因**：清华镜像没有 `*-latest.sfx.exe` 文件，需要用日期版本号。

**修复**：URL 改为 `msys2-base-x86_64-20260611.sfx.exe`。

**教训**：镜像站的文件名格式可能与官方不同，必须先检查目录列表。

### 10.4 Windows shebang `python3` 解析到 Microsoft Store

**现象**：`.py` 脚本的 shebang `#!/usr/bin/env python3` 执行时打开 Microsoft Store。

**根因**：Windows 10+ 注册了 `python3` 和 `python` 的 AppExecution 别名，指向 Microsoft Store。

**修复**：扩展名检测优先于 shebang。在 `_detect_interpreter()` 中，先按 `.py` 扩展名查找解释器，不再依赖 shebang。

**教训**：Windows 上**永远不要依赖 shebang** 选择 Python 解释器。

### 10.5 PowerShell 写 UTF-8 BOM 导致 _pth 解析失败

**现象**：`python313._pth` 被 PowerShell `Set-Content -Encoding UTF8` 写入后，Python 无法解析。

**根因**：PowerShell 的 `-Encoding UTF8` 在 Windows PowerShell 5.1 中会添加 UTF-8 BOM（0xEF 0xBB 0xBF）。Python 读取 `_pth` 文件时，BOM 被当作路径的一部分，导致路径无效。

**修复**：改用 `cmd echo >` 写入文件。cmd 的 `echo` 不加 BOM。

```batch
>"%PTH_FILE%" echo python313.zip
>>"%PTH_FILE%" echo .
>>"%PTH_FILE%" echo Lib\site-packages
>>"%PTH_FILE%" echo.
>>"%PTH_FILE%" echo import site
```

**教训**：在 Windows 上写配置文件，**永远不要用 PowerShell 的 Set-Content/Out-File**，除非你能确保不会产生 BOM。

### 10.6 pip 安装到用户级 site-packages

**现象**：`pip install` 后包安装到了 `C:\Users\AIguibin\AppData\Roaming\Python\Python313\site-packages`，而非内嵌 Python 的 `Lib\site-packages`。

**根因**：Python Embeddable 的 `import site` 启用了用户 site-packages 目录，`pip install` 默认安装到用户目录。

**修复**：
1. `_pth` 中添加 `Lib\site-packages` 路径
2. `pip install` 使用 `--target "AIGUIBIN_CLI_HOME\python\Lib\site-packages"` 强制安装到本地

**教训**：Embeddable Python 的便携性需要**严格控制包的安装位置**，`--target` 是关键。

### 10.7 SET /P 在非交互式模式下阻塞

**现象**：`install.bat` 在自动化脚本中运行时卡住不退出。

**根因**：`SET /P` 等待用户输入，在非交互式模式下无法输入。

**修复**：删除所有 `SET /P` 交互式提示，改为自动继续或 `pause` 仅在最终报告处。

### 10.8 PowerShell $Host 保留变量

**现象**：`ping.ps1` 中 `$Host` 变量值不正确。

**根因**：`$Host` 是 PowerShell 自动变量，代表宿主信息，不是自定义变量。

**修复**：参数名从 `$Host` 改为 `$Target`。

**教训**：PowerShell 有大量保留变量（`$Host`, `$PID`, `$PSBoundParameters` 等），命名时需避开。

### 10.9 Git Bash/MSYS2 路径转换导致命令参数错误

**现象**：在 Git Bash 中执行 `aiguibin /env`，输出 `未知命令: /E:/.../env`。

**根因**：Git Bash（基于 MSYS2 runtime）会自动将以 `/` 开头的参数从 Unix 路径转换为 Windows 路径。因此 `/env` 被误判为路径，转换成 `E:\...\env`，传给 aiguibin.py 后命令名变成了路径。

**修复**：在 Bash 入口脚本中设置 `MSYS_NO_PATHCONV=1`，禁止 Git Bash 自动转换路径参数。

```bash
if $IS_WINDOWS; then
    export MSYS_NO_PATHCONV=1
fi
```

**教训**：在 MSYS2/Git Bash 中调用 Windows 程序时，**必须注意路径自动转换问题**。所有以 `/` 开头的参数都可能被转换。用 `MSYS_NO_PATHCONV=1` 全局禁用，或用 `MSYS2_ARG_CONV_EXCL=//env` 逐个排除。

### 10.10 Git Bash 路径格式不兼容内嵌 Python

**现象**：在 Git Bash 中运行 `aiguibin /env`，报错 `can't open file 'e:\\e\\WorkSpace\\...'`。

**根因**：Git Bash 中 `AIGUIBIN_CLI_HOME` 的值是 Unix 格式 `/e/WorkSpace/...`，传给内嵌 Windows Python 后，Python 无法识别此路径格式，且 Git Bash 的自动转换将 `/e/` 解析为 `e:\e\`（双重转义）。

**修复**：使用 `cygpath -w` 将 Unix 路径转换为 Windows 路径后再传给 Python。

```bash
if $IS_WINDOWS && command -v cygpath &>/dev/null; then
    AIGUIBIN_CLI_HOME_FWD="$(cygpath -w "$AIGUIBIN_CLI_HOME")"
else
    AIGUIBIN_CLI_HOME_FWD="$AIGUIBIN_CLI_HOME"
fi
```

**教训**：在 Git Bash 中调用 Windows 程序时，**必须手动转换路径为 Windows 格式**，不能依赖 Git Bash 的自动转换（因为自动转换可能产生双重转义）。

---

## 11. 开源准备清单

### 11.1 必须完成

- [ ] **LICENSE 文件**：选择开源协议（推荐 MIT）
- [ ] **README.md**：项目介绍、安装、使用、截图
- [ ] **.gitignore**：排除 `git/`、`node/`、`python/`、`*.7z.exe`、`*.zip`、`__pycache__/`
- [ ] **CONTRIBUTING.md**：贡献指南
- [ ] **CHANGELOG.md**：版本变更记录
- [ ] **确认 .gitignore 已更新**：忽略 git/、node/、python/、dist/ 等大文件
- [ ] **清理 PortableGit-*.7z.exe 和 node-*-win-x64.zip**：安装包不应在源码中
- [ ] **敏感信息检查**：确保无硬编码密码、Token、个人路径

### 11.2 建议完成

- [ ] **单元测试**：至少覆盖 command_parser、registry
- [ ] **CI/CD**：GitHub Actions 自动测试
- [ ] **多语言 README**：英文 + 中文
- [ ] **安装视频/动图**：GIF 演示安装和使用
- [ ] **PyPI 发布**：`pip install AIguibinCLI`（如果合适）

### 11.3 .gitignore 建议

```gitignore
# 运行时（install.bat / bootstrap.py 自动下载）
git/
node/
python/
.venv/

# 安装包（不应提交）
*.sfx.exe
*.zip

# Python
__pycache__/
*.pyc
*.pyo
*.egg-info/

# 任务产物
.aiguibin/

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
```

### 11.4 开源协议选择

| 协议 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| MIT | 最宽松，商用友好 | 无专利保护 | ⭐⭐⭐ |
| Apache 2.0 | 宽松 + 专利保护 | 协议较长 | ⭐⭐ |
| GPL 3.0 | 衍生作品必须开源 | 商用限制 | ⭐ |

推荐 **MIT**：简单、友好、适合工具类项目。

### 11.5 版本号规范

采用语义化版本（Semantic Versioning）：

```
v3.5.1
 │ │ │
 │ │ └── Patch: Bug 修复
 │ └──── Minor: 新功能（向后兼容）
 └────── Major: 重大变更（不向后兼容）
```

当前版本为 `v3.5.1`。

---

## 附录 A: 环境变量速查

| 环境变量 | 设置位置 | 值 | 用途 |
|---------|---------|-----|------|
| `AIGUIBIN_CLI_HOME` | install.bat / aiguibin.bat | 安装目录绝对路径 | 程序根目录 |
| `AIGUIBIN_BASH` | aiguibin.bat / executor.py | 内嵌 Bash 路径 | 脚本中调用 Bash |
| `AIGUIBIN_PYTHON` | aiguibin.bat / executor.py | 内嵌 Python 路径 | 脚本中调用 Python |
| `AIGUIBIN_WORKSPACE` | dispatcher.py | 当前工作目录 | 脚本感知工作空间 |
| `AIGUIBIN_TASK_ID` | dispatcher.py | `task_YYYYMMDD_HHMMSS` | 任务标识 |
| `AIGUIBIN_TASK_DIR` | dispatcher.py | 任务目录路径 | 任务文件读写 |
| `AIGUIBIN_OUTPUT_DIR` | dispatcher.py | 任务输出目录 | 脚本产出存放 |
| `AIGUIBIN_LOG_DIR` | dispatcher.py | 任务日志目录 | 日志写入 |
| `AIGUIBIN_TASKS_DIR` | 用户设置 | 自定义任务目录 | 覆盖默认任务路径 |
| `PYTHONIOENCODING` | executor.py | `utf-8` | 确保 Python 中文输出 |
| `MSYSTEM` | dispatcher.py | `MSYS` | Git Bash/MSYS2 兼容环境标识 |
| `CHERE_INVOKING` | dispatcher.py | `1` | Bash 保持当前目录 |
| `MSYS_NO_PATHCONV` | bin/aiguibin | `1` | 禁止 Git Bash/MSYS2 路径自动转换 |

## 附录 B: 依赖包说明

| 包 | 版本 | 用途 | 安装位置 |
|----|------|------|---------|
| `rich` | >=13.0.0 | 终端 UI（表格、面板、颜色） | `python/Lib/site-packages/` |
| `pyyaml` | >=6.0 | YAML 配置解析 | `python/Lib/site-packages/` |
| `pyreadline3` | >=3.4.1 | Windows readline 支持 | `python/Lib/site-packages/` |
| `openpyxl` | >=3.1.0 | Excel 读写操作（/compare-excel 依赖） | `python/Lib/site-packages/` |

## 附录 C: npmmirror 镜像配置

**Git 便携版下载源**：
```
https://registry.npmmirror.com/-/binary/git-for-windows/
```

**Node.js 便携版下载源**：
```
https://registry.npmmirror.com/-/binary/node/latest-v22.x/
```

**Python Embeddable 下载源**（清华镜像）：
```
https://mirrors.tuna.tsinghua.edu.cn/python/3.13.3/python-3.13.3-embed-amd64.zip
```

**版本号缓存**：`config/runtime-versions.json`（7天 TTL，bootstrap.py 自动更新）

## 附录 D: 快速故障排查

| 症状 | 可能原因 | 排查命令 |
|------|---------|---------|
| `aiguibin` 命令找不到 | PATH 未配置 | 运行 install.bat 或手动加 PATH |
| `/shell` 报错 | Git 未安装 | 运行 install.bat 或 bootstrap.py |
| Python 脚本报 ModuleNotFoundError | 依赖未安装 | `python/python.exe -m pip list` |
| Bash 脚本报 command not found | Node.js 未安装 | 运行 install.bat 或 bootstrap.py |
| 中文乱码 | 控制台编码 | `chcp 65001` 或检查终端 UTF-8 设置 |
| `aiguibin /doctor` 全红 | 未运行 install.bat | 运行 install.bat |
| `python313._pth` 无效 | PowerShell BOM 污染 | 用 cmd echo 重新写入 |
| Git Bash 中 `/env` 变成路径 | 路径自动转换 | 确认 `MSYS_NO_PATHCONV=1` 已设置 |
| Git Bash 报路径错误 | Unix 路径未转换 | 确认 `cygpath` 可用 |
| MSYS2 中 `/env` 变成路径 | 路径自动转换 | 确认 `MSYS_NO_PATHCONV=1` 已设置 |
| PowerShell `aiguibin` 不识别 | .PS1 不在 PATHEXT | 运行 install.bat 或手动添加 `.PS1` |

## 附录 E: 命令变更对比（v3.0 → v3.5）

| 命令 | v3.0 (MSYS2) | v3.5 (Git + Node.js) |
|------|-------------|---------------------|
| `/shell` | 启动 MSYS2 Bash | 启动 Git Bash |
| `/install-pkg` | pacman 安装包 | npm 全局安装包 |
| `/env` | 显示 MSYS2 Home | 显示 Git Home |
| `/doctor` | 检查 MSYS2 | 检查 Git |
| `/setup_msys` | 初始化 MSYS2 | ❌ 已移除 |

## 附录 F: Git Bash 兼容性速查

Git Bash 基于 MSYS2 runtime，以下机制完全兼容（无需修改）：

| 特性 | 说明 |
|------|------|
| `MSYS_NO_PATHCONV=1` | 防止 Git Bash 将 `/env` 等参数转为 Windows 路径 |
| `cygpath -w` | Git Bash 自带，路径格式转换 |
| `OSTYPE == "msys"` | Git Bash 的 OSTYPE 同样是 "msys" |
| `MSYSTEM=MSYS` | Git Bash 兼容此环境变量 |
| `--login -i` | 交互式 Shell 启动参数 |
