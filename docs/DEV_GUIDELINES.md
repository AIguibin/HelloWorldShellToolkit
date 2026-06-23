# AIguibinCLI 项目开发规范文档

基于项目架构分析和历史对话，整理出完整的开发准则和规范，用于指导后续的项目版本迭代、命令增加和脚本开发。

## 🏗️ 项目架构规范

### 核心设计原则
```
安装目录 (AIGUIBIN_CLI_HOME)  → 程序本体、配置、应用数据、内嵌运行时（可移植）
应用数据目录 (.agent/)        → 历史记录、日志（非工作产出）
工作空间 (Workspace)          → 任务输出、工作上下文（跟随用户）
```

**关键原则**：
- **零硬编码路径**：所有路径基于 `AIGUIBIN_CLI_HOME` 和 `AIGUIBIN_AGENT_DIR` 动态计算
- **职责分离**：程序文件、配置、数据、输出各司其职
- **可移植性**：整个目录拷贝即可迁移
- **向后兼容**：新功能不影响现有功能

### 路径常量规范
```python
# 必须在文件顶部定义路径常量
AIGUIBIN_CLI_HOME = os.path.dirname(os.path.abspath(__file__))  # 安装目录
AIGUIBIN_AGENT_DIR = os.path.join(AIGUIBIN_CLI_HOME, ".agent")  # 应用数据目录
CONFIG_DIR = os.path.join(AIGUIBIN_CLI_HOME, "config")          # 配置目录
```

## 📁 目录结构规范

### 完整目录结构
```
D:\AIguibinCLI\                              # AIGUIBIN_CLI_HOME
├── aiguibin.py                             # 主入口（保持不变）
├── requirements.txt                        # Python 依赖声明
├── install.bat                             # 安装脚本（14步+）
├── uninstall.bat                           # 卸载脚本
│
├── docs/                                   # 项目文档目录
│   ├── DEV_GUIDELINES.md           # 开发规范文档（本文件）
│   ├── DEPENDENCIES.md                      # 依赖管理详细文档
│   ├── QUICKSTART.md                       # 快速开始指南
│   ├── ARCHITECTURE.md                     # 架构设计文档（待创建）
│   ├── API.md                              # API 接口文档（待创建）
│   ├── CHANGELOG.md                        # 版本变更日志（待创建）
│   └── CONTRIBUTING.md                     # 贡献指南（待创建）
│
├── bin/                                    # Shell 入口脚本
│   ├── aiguibin.bat                        # CMD 入口
│   ├── aiguibin.ps1                        # PowerShell 入口
│   └── aiguibin                            # Bash 入口
│
├── config/                                 # 配置文件
│   ├── registry.yaml                       # 脚本注册表（核心）
│   ├── runtime-versions.json               # 版本缓存（7天TTL）
│   └── dependencies/                       # 依赖配置目录
│       ├── python-dependencies.yaml        # Python 依赖
│       ├── node-dependencies.json          # Node.js 依赖
│       └── shell-tools.yaml                # Shell 工具配置
│
├── .agent/                                 # 应用数据目录
│   ├── .aiguibin_history                   # 命令历史（readline）
│   └── logs/                               # 应用日志
│       ├── app.log                         # 主应用日志
│       ├── bootstrap.log                   # 引导脚本日志
│       └── dependencies.log                # 依赖操作日志
│
├── core/                                   # 核心模块
│   ├── __init__.py
│   ├── command_parser.py                   # 命令解析器
│   ├── registry.py                         # 脚本注册机制
│   ├── task_manager.py                     # 任务目录管理
│   ├── executor.py                         # 脚本执行引擎
│   ├── dispatcher.py                       # 命令调度器
│   ├── runtime.py                          # 运行时检测与路径管理
│   ├── bootstrap.py                        # 自动下载引导脚本
│   └── dependency_manager.py               # 依赖管理模块
│
├── scripts/                                # 用户脚本（业务逻辑）
│   ├── hello.py                            # 示例：Python 脚本
│   ├── build.py                            # 示例：构建项目
│   └── dependency_examples.py              # 依赖管理示例
│
├── tools/                                  # 自定义工具目录
│   ├── binaries/                           # 可执行二进制文件
│   ├── python/                             # Python 自定义工具
│   ├── nodejs/                             # Node.js 自定义工具
│   └── shell/                              # Shell 自定义脚本
│
├── git/                                    # 内嵌 Git 便携版
├── node/                                   # 内嵌 Node.js 便携版
└── python/                                 # 内嵌 Python Embeddable
```

## 🔧 开发规范

### 1. 核心模块开发规范

#### 文件结构模板
```python
#!/usr/bin/env python3
"""
模块功能描述

版本历史:
  v3.5.1 - 新增功能描述

架构原则:
  - 使用 RuntimeDetector 的回退策略
  - 日志写入 .agent/logs/
  - 配置文件使用 YAML/JSON 格式
"""

import os
import sys
from typing import Dict, List, Optional, Tuple
from datetime import datetime

# 路径常量（如果需要）
AIGUIBIN_CLI_HOME = os.path.dirname(os.path.abspath(__file__))
AIGUIBIN_AGENT_DIR = os.path.join(AIGUIBIN_CLI_HOME, ".agent")

class ClassName:
    """类描述"""
    
    def __init__(self, param1: str, param2: Optional[str] = None):
        """初始化"""
        self.param1 = param1
        self.param2 = param2 or "default_value"
        self.log_file = os.path.join(AIGUIBIN_AGENT_DIR, "logs", "module_name.log")
        
        # 确保日志目录存在
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)
    
    def method_name(self, args: List[str]) -> Tuple[bool, str]:
        """方法描述
        
        Returns:
            Tuple[bool, str]: (success, message)
        """
        try:
            # 业务逻辑
            return True, "操作成功"
        except Exception as e:
            self._log("ERROR", f"操作失败: {e}")
            return False, str(e)
    
    def _log(self, level: str, message: str) -> None:
        """记录模块日志"""
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(f"[{timestamp}] [{level}] {message}\n")
        except Exception:
            pass  # 日志写入失败不影响主流程
```

### 2. 命令开发规范

#### 命令命名规范
- **格式**：`/verb` 或 `/verb-noun`
- **风格**：小写，用连字符分隔
- **示例**：`/help`, `/list-python`, `/install-node`, `/add-tool`

#### 内置命令开发模板
```python
def _cmd_command_name(self, parsed: ParsedCommand) -> bool:
    """命令描述
    
    Args:
        parsed: 解析后的命令对象
        
    Returns:
        bool: True = 继续运行, False = 退出
    """
    # 参数检查
    if not parsed.positional_args:
        self.console.print("[yellow]用法:[/yellow] /command-name <args>")
        return True
    
    # 业务逻辑
    try:
        # 执行操作
        self.console.print("[green]✓[/green] 操作成功")
        return True
    except Exception as e:
        self.console.print(f"[red]✗[/red] 操作失败: {e}")
        return True
```

#### 命令注册规范
```python
# 在 Dispatcher.__init__ 中注册
self._builtins = {
    # 现有命令
    "help": self._cmd_help,
    "list": self._cmd_list,
    
    # 新命令按字母顺序添加
    "your-new-command": self._cmd_your_new_command,
}
```

### 3. 脚本开发规范

#### Python 脚本模板
```python
#!/usr/bin/env python3
"""
/your-command - 命令描述

用法:
  /your-command --input=file.txt --output=result.txt

环境变量:
  - AIGUIBIN_CLI_HOME: 安装目录
  - AIGUIBIN_AGENT_DIR: 应用数据目录
  - AIGUIBIN_TASK_ID: 任务ID
  - AIGUIBIN_TASK_DIR: 任务目录
  - AIGUIBIN_OUTPUT_DIR: 输出目录
  - AIGUIBIN_WORKSPACE: 工作目录
  - AIGUIBIN_BASH: Bash 路径
  - AIGUIBIN_PYTHON: Python 路径
"""

import os
import sys
import argparse
from datetime import datetime


def main():
    parser = argparse.ArgumentParser(description="命令描述")
    parser.add_argument("--input", required=True, help="输入文件")
    parser.add_argument("--output", default="output.txt", help="输出文件")
    parser.add_argument("--verbose", action="store_true", help="详细输出")
    
    args = parser.parse_args()
    
    # 获取环境变量
    task_id = os.environ.get("AIGUIBIN_TASK_ID", "N/A")
    task_dir = os.environ.get("AIGUIBIN_TASK_DIR", ".")
    output_dir = os.environ.get("AIGUIBIN_OUTPUT_DIR", ".")
    workspace = os.environ.get("AIGUIBIN_WORKSPACE", ".")
    
    print(f"Task ID: {task_id}")
    print(f"Workspace: {workspace}")
    print(f"Input: {args.input}")
    print(f"Output: {os.path.join(output_dir, args.output)}")
    
    # 业务逻辑
    if args.verbose:
        print(f"[{datetime.now()}] Processing {args.input}...")
    
    # 在输出目录生成结果
    result_path = os.path.join(output_dir, args.output)
    with open(result_path, "w", encoding="utf-8") as f:
        f.write(f"Processed: {args.input}\n")
        f.write(f"Timestamp: {datetime.now()}\n")
    
    print(f"✓ Result: {result_path}")


if __name__ == "__main__":
    main()
```

#### Bash 脚本模板
```bash
#!/usr/bin/env bash
# /your-command - 命令描述

# 获取环境变量
AIGUIBIN_TASK_ID="${AIGUIBIN_TASK_ID:-N/A}"
AIGUIBIN_OUTPUT_DIR="${AIGUIBIN_OUTPUT_DIR:-.}"
AIGUIBIN_WORKSPACE="${AIGUIBIN_WORKSPACE:-.}"

# 参数检查
if [ $# -lt 1 ]; then
    echo "用法: /your-command <input_file> [output_file]"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-output.txt}"

echo "Task ID: $AIGUIBIN_TASK_ID"
echo "Workspace: $AIGUIBIN_WORKSPACE"
echo "Input: $INPUT_FILE"
echo "Output: $AIGUIBIN_OUTPUT_DIR/$OUTPUT_FILE"

# 业务逻辑
echo "[$(date)] Processing $INPUT_FILE..." >&2

# 在输出目录生成结果
RESULT_PATH="$AIGUIBIN_OUTPUT_DIR/$OUTPUT_FILE"
echo "Processed: $INPUT_FILE" > "$RESULT_PATH"
echo "Timestamp: $(date)" >> "$RESULT_PATH"

echo "✓ Result: $RESULT_PATH"
```

#### Node.js 脚本模板
```javascript
#!/usr/bin/env node
/**
 * /your-command - 命令描述
 *
 * 用法:
 *   aiguibin /your-command --input=file.txt --output=result.txt
 *
 * 环境变量:
 *   - AIGUIBIN_CLI_HOME: 安装目录
 *   - AIGUIBIN_AGENT_DIR: 应用数据目录
 *   - AIGUIBIN_TASK_ID: 任务ID
 *   - AIGUIBIN_TASK_DIR: 任务目录
 *   - AIGUIBIN_OUTPUT_DIR: 输出目录
 *   - AIGUIBIN_WORKSPACE: 工作目录
 *   - AIGUIBIN_BASH: Bash 路径
 *   - AIGUIBIN_PYTHON: Python 路径
 *   - AIGUIBIN_NODE: Node.js 路径
 */

const path = require('path');
const fs = require('fs');

function main() {
    // 获取环境变量
    const taskId = process.env.AIGUIBIN_TASK_ID || 'N/A';
    const taskDir = process.env.AIGUIBIN_TASK_DIR || '.';
    const outputDir = process.env.AIGUIBIN_OUTPUT_DIR || '.';
    const workspace = process.env.AIGUIBIN_WORKSPACE || '.';

    // 解析命令行参数（简单示例，复杂场景建议使用 commander/yargs）
    const args = process.argv.slice(2);
    const inputFile = args[0];
    const outputFile = args.find(a => a.startsWith('--output='))?.split('=')[1] || 'output.txt';
    const verbose = args.includes('--verbose');

    if (!inputFile) {
        console.error('用法: aiguibin /your-command <input> [--output=result.txt] [--verbose]');
        process.exit(1);
    }

    console.log(`Task ID: ${taskId}`);
    console.log(`Workspace: ${workspace}`);
    console.log(`Input: ${inputFile}`);
    console.log(`Output: ${path.join(outputDir, outputFile)}`);

    // 业务逻辑
    if (verbose) {
        console.log(`[${new Date().toISOString()}] Processing ${inputFile}...`);
    }

    // 在输出目录生成结果
    const resultPath = path.join(outputDir, outputFile);
    fs.writeFileSync(resultPath,
        `Processed: ${inputFile}\nTimestamp: ${new Date().toISOString()}\n`,
        'utf-8'
    );

    console.log(`✓ Result: ${resultPath}`);
}

main();
```

#### 命令行帮助规范（强制要求）

**所有后续新增的脚本文件必须实现命令行帮助功能。** 当用户执行 `aiguibin /XXXX --help` 命令时，系统应清晰展示当前脚本的使用场景说明和详细的使用指南。

##### 帮助内容必须包含

1. **使用场景说明**：明确阐述脚本的适用业务场景和解决的具体问题
2. **使用指南**：
   - 命令格式（位置参数 + 可选参数）
   - 参数说明（每个参数的含义、类型、是否必填）
   - 选项配置（所有可选选项及其默认值）
   - 示例用法（至少 3 个典型场景示例）

##### Python 实现模板

使用 `argparse` 的 `epilog` + `RawDescriptionHelpFormatter` 实现多行帮助文本：

```python
def main():
    epilog_text = """\
使用场景：
  ──────────────────────────────────────────────────────────────
  场景1：基础用法（描述适用业务场景）
  ──────────────────────────────────────────────────────────────
  aiguibin /your-command input.xlsx

  ──────────────────────────────────────────────────────────────
  场景2：高级用法（描述解决的具体问题）
  ──────────────────────────────────────────────────────────────
  aiguibin /your-command input.xlsx --option value -o output.txt

  ──────────────────────────────────────────────────────────────
  场景3：组合用法（实际工作中常见组合）
  ──────────────────────────────────────────────────────────────
  aiguibin /your-command input.xlsx --flag --option value -o output.txt

输出说明：
  - 输出文件格式
  - 输出文件位置
"""

    parser = argparse.ArgumentParser(
        description="脚本功能简述",
        epilog=epilog_text,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", help="输入文件路径")
    parser.add_argument("-o", "--output", help="输出文件路径")
    # ... 其他参数
    args = parser.parse_args()
```

##### Bash 实现模板

Bash 脚本通过 `--help` 参数判断实现：

```bash
#!/usr/bin/env bash
# /your-command - 命令描述

show_help() {
    cat << 'EOF'
用法: aiguibin /your-command <input> [options]

使用场景：
  场景1：基础用法
    aiguibin /your-command input.txt

  场景2：指定输出
    aiguibin /your-command input.txt -o output.txt

  场景3：组合用法
    aiguibin /your-command input.txt --flag --option value

参数:
  input          输入文件路径（必填）

选项:
  -o, --output   输出文件路径（默认: output.txt）
  --flag         启用某功能
  --option VAL   指定选项值
  -h, --help     显示此帮助信息

输出说明:
  - 输出文件格式
  - 输出文件位置
EOF
}

# 解析 --help
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_help
    exit 0
fi

# ... 业务逻辑
```

##### Node.js 实现模板

Node.js 脚本通过 `process.argv` 解析 `--help` 参数实现（无需第三方依赖）：

```javascript
#!/usr/bin/env node
/**
 * /your-command - 命令描述
 */

const path = require('path');
const fs = require('fs');

// 显示帮助信息
function showHelp() {
    console.log(`
用法: aiguibin /your-command <input> [options]

使用场景：
  ──────────────────────────────────────────────────────────────
  场景1：基础用法（描述适用业务场景）
  ──────────────────────────────────────────────────────────────
  aiguibin /your-command input.txt

  ──────────────────────────────────────────────────────────────
  场景2：指定输出（描述解决的具体问题）
  ──────────────────────────────────────────────────────────────
  aiguibin /your-command input.txt -o output.txt

  ──────────────────────────────────────────────────────────────
  场景3：组合用法（实际工作中常见组合）
  ──────────────────────────────────────────────────────────────
  aiguibin /your-command input.txt --flag --option value -o output.txt

参数:
  input          输入文件路径（必填）

选项:
  -o, --output   输出文件路径（默认: output.txt）
  --flag         启用某功能
  --option VAL   指定选项值
  -h, --help     显示此帮助信息

输出说明:
  - 输出文件格式
  - 输出文件位置
`);
}

// 解析命令行参数
function parseArgs(argv) {
    const args = { options: {}, positional: [] };
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg === '-h' || arg === '--help') {
            showHelp();
            process.exit(0);
        } else if (arg === '-o' || arg === '--output') {
            args.options.output = argv[++i];
        } else if (arg === '--flag') {
            args.options.flag = true;
        } else if (arg === '--option') {
            args.options.option = argv[++i];
        } else {
            args.positional.push(arg);
        }
    }
    return args;
}

// 主函数
function main() {
    const args = parseArgs(process.argv.slice(2));

    if (args.positional.length === 0) {
        console.error('错误: 缺少输入文件参数');
        showHelp();
        process.exit(1);
    }

    const inputFile = args.positional[0];
    const outputFile = args.options.output || 'output.txt';
    const outputDir = process.env.AIGUIBIN_OUTPUT_DIR || '.';
    const taskId = process.env.AIGUIBIN_TASK_ID || 'N/A';

    console.log(`Task ID: ${taskId}`);
    console.log(`Input: ${inputFile}`);
    console.log(`Output: ${path.join(outputDir, outputFile)}`);

    // 业务逻辑
    const resultPath = path.join(outputDir, outputFile);
    fs.writeFileSync(resultPath,
        `Processed: ${inputFile}\nTimestamp: ${new Date().toISOString()}\n`,
        'utf-8'
    );

    console.log(`✓ Result: ${resultPath}`);
}

main();
```

> **提示**：如果脚本参数较复杂，建议安装 `commander` 或 `yargs` 库简化参数解析：
> ```bash
> aiguibin /install-node --global commander yargs
> ```

##### 验收标准

- [ ] 执行 `aiguibin /XXXX --help` 能正常输出帮助信息
- [ ] 帮助信息包含至少 3 个使用场景示例
- [ ] 每个参数都有清晰的说明
- [ ] 帮助文本格式清晰（使用分隔线、缩进、对齐）
- [ ] 使用 `RawDescriptionHelpFormatter` 保留原始格式（Python）

### 4. 配置文件规范

#### YAML 配置模板
```yaml
# 文件描述
metadata:
  version: "1.0"
  created: "2026-06-23"
  description: "配置文件描述"

# 主要配置
main_setting: value
nested:
  setting1: value1
  setting2: value2

# 列表配置
items:
  - name: item1
    version: "1.0.0"
    required: true
    tags: [core, important]

# 备注信息
notes: |
  配置说明
  可以多行
```

#### JSON 配置模板
```json
{
  "metadata": {
    "version": "1.0",
    "created": "2026-06-23",
    "description": "配置文件描述"
  },
  "main_setting": "value",
  "nested": {
    "setting1": "value1",
    "setting2": "value2"
  },
  "items": [
    {
      "name": "item1",
      "version": "1.0.0",
      "required": true
    }
  ],
  "notes": "配置说明"
}
```

## 🎨 编码规范

### Python 编码规范
- **缩进**：4 个空格（不使用 Tab）
- **行长度**：最大 120 字符
- **类型注解**：函数参数和返回值使用类型注解
- **文档字符串**：所有类和方法必须有文档字符串
- **错误处理**：使用 try-except 捕获异常，提供友好的错误信息

### 环境变量规范
```python
# 系统环境变量（只读）
AIGUIBIN_CLI_HOME = os.environ.get("AIGUIBIN_CLI_HOME", "")
AIGUIBIN_AGENT_DIR = os.environ.get("AIGUIBIN_AGENT_DIR", "")

# 运行时环境变量（注入到子进程）
runtime_env = {
    "AIGUIBIN_TASK_ID": task_id,
    "AIGUIBIN_TASK_DIR": task_dir,
    "AIGUIBIN_OUTPUT_DIR": output_dir,
    "AIGUIBIN_WORKSPACE": workspace,
    "AIGUIBIN_BASH": bash_path,
    "AIGUIBIN_PYTHON": python_path,
}
```

### 日志规范
```python
# 应用日志（.agent/logs/app.log）
def app_log(level: str, message: str):
    """记录应用日志"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_file = os.path.join(AIGUIBIN_AGENT_DIR, "logs", "app.log")
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"[{timestamp}] [{level}] {message}\n")

# 模块日志（.agent/logs/module_name.log）
def module_log(level: str, message: str):
    """记录模块日志"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(self.log_file, "a", encoding="utf-8") as f:
        f.write(f"[{timestamp}] [{level}] {message}\n")
```

## 📋 必须包含的内容

### 每个新命令必须包含：
1. **命令处理器**：在 `dispatcher.py` 中添加 `_cmd_*` 方法
2. **命令注册**：在 `self._builtins` 字典中注册
3. **帮助文档**：在 `_cmd_help` 中添加命令说明
4. **错误处理**：完善的异常捕获和用户友好的错误信息
5. **日志记录**：关键操作记录到日志文件
6. **参数验证**：输入参数的验证和默认值处理

### 每个新脚本必须包含：
1. **shebang 行**：指定解释器
2. **文档字符串**：命令描述、用法、环境变量
3. **参数处理**：使用 argparse 或手动解析
4. **环境变量使用**：获取和使用 AIGUIBIN_* 环境变量
5. **输出管理**：结果写入 AIGUIBIN_OUTPUT_DIR
6. **错误处理**：异常捕获和错误信息输出
7. **命令行帮助（强制）**：实现 `--help` 功能，包含使用场景说明（业务场景+解决问题）和使用指南（命令格式+参数说明+选项配置+示例用法），详见"命令行帮助规范"小节

### 每个新配置文件必须包含：
1. **元数据**：版本、创建时间、描述
2. **配置结构**：清晰的层次结构
3. **默认值**：所有配置项的默认值
4. **验证规则**：配置值的类型和范围验证
5. **注释说明**：每个配置项的用途说明

## 🔄 迭代开发流程

### 新功能开发流程
1. **需求分析**：明确功能需求和边界
2. **架构设计**：确定模块和接口设计
3. **目录规划**：确定文件和目录结构
4. **代码实现**：按照规范编写代码
5. **测试验证**：功能测试和边界测试
6. **文档更新**：更新相关文档和帮助
7. **版本标记**：更新版本号和变更日志

### 版本迭代规范
```python
# 版本号格式：v{major}.{minor}.{patch}
# - major: 重大变更（不向后兼容）
# - minor: 新功能（向后兼容）
# - patch: Bug 修复

# 当前版本：v3.5.1
# 下个版本：v3.5.1.1（bug fix）或 v3.6（新功能）
```

### 变更日志规范
```
## [版本号] - 日期

### 新增
- 功能描述
- 功能描述

### 变更
- 变更描述
- 变更描述

### 修复
- Bug 修复描述
- Bug 修复描述

### 移除
- 移除功能描述
```

## 🚫 禁止事项

### 编码禁止事项
- ❌ 硬编码路径（必须使用动态计算）
- ❌ 使用 Tab 缩进（必须使用空格）
- ❌ 忽略类型注解（复杂函数必须添加）
- ❌ 直接输出到 stdout（使用 Rich 库）
- ❌ 静默异常（必须记录日志）

### 架构禁止事项
- ❌ 破坏向后兼容性
- ❌ 在工作目录产生程序数据
- ❌ 混淆配置和数据存储位置
- ❌ 忽略运行时检测的回退策略
- ❌ 绕过现有的错误处理机制

### 安全禁止事项
- ❌ 使用 yaml.load()（必须使用 yaml.safe_load()）
- ❌ 直接执行用户输入
- ❌ 忽略文件权限检查
- ❌ 暴露敏感信息到日志
- ❌ 忽略输入验证

## 📚 文档规范

### README.md 必须包含：
1. **项目概述**：核心特性和设计理念
2. **版本信息**：当前版本号和更新日期
3. **目录结构**：详细的目录结构说明
4. **安装使用**：安装步骤和使用示例
5. **开发指南**：开发环境和开发流程
6. **架构说明**：核心模块和设计原则
7. **故障排查**：常见问题和解决方案

### 详细文档建议：
1. **DEPENDENCIES.md** - 依赖管理详细文档（✅ 已存在）
2. **ARCHITECTURE.md** - 架构设计文档（✅ 已存在）
3. **API.md** - API 接口文档（✅ 已存在）
4. **CHANGELOG.md** - 版本变更日志（✅ 已存在）
5. **CONTRIBUTING.md** - 贡献指南（✅ 已存在）

## 🧪 测试建议

### 功能测试要点：
- 正常情况测试
- 边界条件测试
- 异常情况测试
- 路径检测测试
- 环境变量测试

### 集成测试要点：
- 多模块协同工作
- 命令执行流程
- 依赖管理集成
- 日志记录验证

## 📞 技术支持

### 开发环境要求：
- Python 3.13+
- Git Bash
- Node.js 22.x
- Rich 库（终端UI）
- PyYAML（配置解析）

### 调试技巧：
- 查看 `.agent/logs/` 下的日志文件
- 使用 `/doctor` 诊断运行时状态
- 使用 `/env` 查看环境变量
- 使用 `/list-*` 查看依赖状态

## 🐛 常见开发陷阱

### 1. 方法名拼写错误
**问题**：调用不存在的方法导致 `AttributeError`
```python
# 错误示例
node_path = self.runtime_detector.get_node_home()  # 方法不存在

# 正确示例
node_exe = self.runtime_detector.get_node_path()
node_home = os.path.dirname(node_exe) if node_exe else None
```

### 2. 路径硬编码
**问题**：路径不随安装目录变化
```python
# 错误示例
config_path = "D:\\AIguibinCLI\\config\\registry.yaml"

# 正确示例
AIGUIBIN_CLI_HOME = os.path.dirname(os.path.abspath(__file__))
config_path = os.path.join(AIGUIBIN_CLI_HOME, "config", "registry.yaml")
```

### 3. 缺少错误处理
**问题**：异常导致程序崩溃
```python
# 错误示例
with open(file_path, 'r') as f:
    data = yaml.load(f)  # 危险：可能注入代码

# 正确示例
try:
    with open(file_path, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f) or {}  # 安全：使用 safe_load
except Exception as e:
    console.print(f"[red]配置加载失败:[/red] {e}")
    return {}
```

### 4. 环境变量未传递
**问题**：脚本无法获取环境变量
```python
# 错误示例
subprocess.run(["python", "script.py"])

# 正确示例
env = os.environ.copy()
env["AIGUIBIN_TASK_ID"] = task_id
subprocess.run(["python", "script.py"], env=env)
```

## 🎯 开发检查清单

### 新命令开发检查：
- [ ] 命名符合 `/verb` 规范
- [ ] 在 `dispatcher.py` 中实现 `_cmd_*` 方法
- [ ] 在 `self._builtins` 中注册命令
- [ ] 在 `_cmd_help` 中添加帮助信息
- [ ] 参数验证和错误处理
- [ ] 日志记录到 `.agent/logs/`
- [ ] 更新相关文档

### 新脚本开发检查：
- [ ] 包含 shebang 行
- [ ] 有详细的文档字符串
- [ ] 使用 AIGUIBIN_* 环境变量
- [ ] 输出到 AIGUIBIN_OUTPUT_DIR
- [ ] 完善的错误处理
- [ ] 在 `registry.yaml` 中注册
- [ ] 测试各种参数组合
- [ ] 实现 `--help` 功能，包含使用场景说明和使用指南
- [ ] 帮助信息包含至少 3 个使用场景示例
- [ ] 执行 `aiguibin /XXXX --help` 验证输出格式正确

### 新配置文件检查：
- [ ] 包含元数据
- [ ] 结构清晰层次分明
- [ ] 有默认值和验证规则
- [ ] 注释说明完整
- [ ] 放在 `config/dependencies/` 下
- [ ] 更新相关文档

## 📈 性能优化建议

### 1. 避免重复计算
```python
# 错误示例
for item in items:
    config_path = os.path.join(AIGUIBIN_CLI_HOME, "config", "file.yaml")  # 重复计算

# 正确示例
config_path = os.path.join(AIGUIBIN_CLI_HOME, "config", "file.yaml")  # 只计算一次
for item in items:
    # 使用 config_path
```

### 2. 延迟加载
```python
# 错误示例
import heavy_module  # 立即加载

# 正确示例
def function():
    import heavy_module  # 延迟加载
    # 使用 heavy_module
```

### 3. 缓存结果
```python
# 错误示例
def get_config():
    with open(config_file, 'r') as f:
        return yaml.safe_load(f)  # 每次都读取

# 正确示例
_config_cache = None
def get_config():
    global _config_cache
    if _config_cache is None:
        with open(config_file, 'r') as f:
            _config_cache = yaml.safe_load(f) or {}
    return _config_cache
```

---

**核心原则总结**：
1. **架构一致性**：所有新功能必须遵循现有架构模式
2. **路径动态化**：零硬编码路径，全部动态计算
3. **职责分离**：配置、数据、输出各司其职
4. **向后兼容**：新功能不影响现有功能
5. **文档完备**：每个功能都有清晰的文档说明

遵循这些规范，可以确保项目的可维护性、可扩展性和稳定性。