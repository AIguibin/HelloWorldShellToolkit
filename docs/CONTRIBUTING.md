# AIguibinCLI 贡献指南

感谢您对 AIguibinCLI 项目的关注！本指南将帮助您了解如何为项目做出贡献。

## 开发环境设置

### 前置要求

- **Python 3.13+**：主要开发语言
- **Git**：版本控制
- **Node.js 22.x+**：用于 JavaScript 脚本测试
- **文本编辑器**：支持 Python 语法高亮（推荐 VSCode）

### 克隆仓库

```bash
git clone <repository-url>
cd aiguibin-agent-terminal
```

### 安装依赖

#### 方式一：使用 install.bat

```bash
install.bat
```

#### 方式二：手动安装

```bash
# 安装 Python 依赖
python/python.exe -m pip install rich pyyaml pyreadline3 openpyxl --target python/Lib/site-packages

# 下载运行时（如需要）
# 参考 install.bat 中的步骤
```

### 验证安装

```bash
# 启动 aiguibin
aiguibin

# 检查运行时状态
/doctor

# 检查环境变量
/env
```

## 开发流程

### 1. 创建分支

```bash
git checkout -b feature/your-feature-name
# 或
git checkout -b fix/your-bug-fix
```

### 2. 开发规范

#### 代码风格
- 遵循 PEP 8 编码规范
- 使用 4 空格缩进（不使用 Tab）
- 行长度最大 120 字符
- 添加类型注解
- 编写文档字符串

#### 目录结构
- 新命令处理器：`core/dispatcher.py`
- 新核心模块：`core/new_module.py`
- 用户脚本：`scripts/your_script.py`
- 配置文件：`config/` 或 `config/dependencies/`
- 文档：`docs/`

#### 命名规范
- **命令**：`/verb-noun`（小写，连字符分隔）
- **文件**：`module_name.py`（下划线分隔）
- **类**：`ClassName`（驼峰命名）
- **函数**：`function_name`（下划线分隔）
- **变量**：`variable_name`（下划线分隔）

### 3. 开发步骤

#### 添加新命令

1. **实现命令处理器**
```python
def _cmd_your_command(self, parsed: ParsedCommand) -> bool:
    """命令描述"""
    # 参数验证
    if not parsed.positional_args:
        self.console.print("[yellow]用法:[/yellow] /your-command <args>")
        return True
    
    # 业务逻辑
    try:
        result = self._do_something(parsed.positional_args)
        self.console.print(f"[green]✓[/green] {result}")
        return True
    except Exception as e:
        self.console.print(f"[red]✗[/red] {e}")
        return True
```

2. **注册命令**
```python
self._builtins = {
    # 现有命令
    "help": self._cmd_help,
    # 新命令（按字母顺序）
    "your-command": self._cmd_your_command,
}
```

3. **更新帮助信息**
```python
def _cmd_help(self, parsed: ParsedCommand) -> bool:
    # 添加你的命令说明
    commands_table.add_row("/your-command", "命令描述", "参数")
```

4. **测试命令**
```bash
# 测试命令
aiguibin /your-command test

# 测试错误处理
aiguibin /your-command  # 无参数
```

#### 添加新脚本

1. **创建脚本文件**
```python
#!/usr/bin/env python3
"""
/your-script - 脚本描述

用法:
  /your-script --input=file.txt
"""

import os
import sys
import argparse

def main():
    parser = argparse.ArgumentParser(description="脚本描述")
    parser.add_argument("--input", required=True, help="输入文件")
    args = parser.parse_args()
    
    # 获取环境变量
    output_dir = os.environ.get("AIGUIBIN_OUTPUT_DIR", ".")
    
    # 业务逻辑
    result = process_file(args.input)
    
    # 输出结果
    result_path = os.path.join(output_dir, "result.txt")
    with open(result_path, "w", encoding="utf-8") as f:
        f.write(result)
    
    print(f"✓ Result: {result_path}")

if __name__ == "__main__":
    main()
```

2. **注册到 registry.yaml**
```yaml
commands:
  - name: your-script
    script: your_script.py
    description: 脚本描述
    params:
      - name: input
        type: string
        required: true
        description: 输入文件
        flag: input
```

3. **测试脚本**
```bash
# 重新加载配置
/reload

# 测试脚本
/your-script --input=test.txt

# 查看输出
/workspace
cd .aiguibin/tasks/latest/outputs
```

#### 添加新核心模块

1. **创建模块文件**
```python
#!/usr/bin/env python3
"""
模块功能描述
"""

from typing import Dict, List, Optional, Tuple
from datetime import datetime
import os

class YourModule:
    """模块描述"""
    
    def __init__(self, aiguibin_home: str, agent_dir: str):
        """初始化"""
        self.aiguibin_home = aiguibin_home
        self.agent_dir = agent_dir
        self.log_file = os.path.join(agent_dir, "logs", "module.log")
    
    def do_something(self, args: List[str]) -> Tuple[bool, str]:
        """核心方法"""
        try:
            # 业务逻辑
            return True, "操作成功"
        except Exception as e:
            self._log("ERROR", f"操作失败: {e}")
            return False, str(e)
    
    def _log(self, level: str, message: str) -> None:
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(f"[{timestamp}] [{level}] {message}\n")
```

2. **在 dispatcher 中使用**
```python
from core.your_module import YourModule

class Dispatcher:
    def __init__(self, ...):
        # 初始化模块
        self.your_module = YourModule(AIGUIBIN_CLI_HOME, AIGUIBIN_AGENT_DIR)
```

### 4. 测试

#### 功能测试

```bash
# 测试新命令
aiguibin /your-command arg1 arg2

# 测试参数验证
aiguibin /your-command  # 无参数

# 测试错误处理
aiguibin /your-command invalid_arg
```

#### 集成测试

```bash
# 测试依赖管理
/dep-sync
/list-python

# 测试脚本执行
/your-script --input=test.txt

# 检查任务状态
/status
```

#### 边界测试

```bash
# 测试空输入
aiguibin /your-command ""

# 测试特殊字符
aiguibin /your-command "test@#$%^"

# 测试路径边界
aiguibin /your-command "very/long/path/that/exceeds/limit"
```

### 5. 文档更新

#### 更新 CHANGELOG.md

```markdown
## [3.5.1] - 2024-06-XX

### 新增
- `/your-command` - 命令描述

### 修复
- 修复某个问题
```

#### 更新 README.md

在适当位置添加新功能说明。

#### 更新 API.md

如果是编程接口，更新 API 文档。

## 代码提交规范

### Commit Message 格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type 类型
- **feat**: 新功能
- **fix**: Bug 修复
- **docs**: 文档更新
- **style**: 代码格式（不影响功能）
- **refactor**: 重构
- **perf**: 性能优化
- **test**: 测试相关
- **chore**: 构建/工具链相关

#### 示例

```
feat(dependencies): add Rust package support

- Add RustDependencyManager class
- Implement install, uninstall, update methods
- Add /install-rust command
- Update documentation

Closes #123
```

### 提交检查清单

- [ ] 代码遵循开发规范
- [ ] 添加必要的文档字符串
- [ ] 更新相关文档
- [ ] 测试通过
- [ ] 没有 debug 代码
- [ ] 没有硬编码路径

## Pull Request 流程

### 1. 创建 Pull Request

```bash
# 推送到远程仓库
git push origin feature/your-feature-name

# 在 GitHub/GitLab 上创建 PR
# 标题格式：[type] 短描述
# 描述中说明：变更内容、测试方法、相关问题
```

### 2. PR 描述模板

```markdown
## 变更说明
简要描述本次 PR 的变更内容

## 变更类型
- [ ] 新功能
- [ ] Bug 修复
- [ ] 文档更新
- [ ] 重构
- [ ] 性能优化

## 测试情况
- [ ] 单元测试
- [ ] 集成测试
- [ ] 手动测试
- [ ] 边界测试

## 相关问题
Closes #123, #456

## 截图/示例
如果有界面变更，提供截图或示例
```

### 3. 代码审查

- **审查要点**：
  - 代码质量和规范
  - 功能完整性
  - 错误处理
  - 文档完整性
  - 测试覆盖

- **修改建议**：
  - 根据审查意见修改代码
  - 回复审查问题
  - 更新 PR 描述

### 4. 合并

- **合并条件**：
  - 所有审查通过
  - CI 测试通过
  - 文档完整
  - 无合并冲突

- **合并方式**：
  - 小改动：直接合并
  - 大改动：Squash merge
  - 保持历史：Merge commit

## 质量标准

### 代码质量

- ✅ 符合 PEP 8 规范
- ✅ 没有语法错误
- ✅ 类型注解完整
- ✅ 错误处理完善
- ✅ 日志记录合理

### 文档质量

- ✅ 有清晰的文档字符串
- ✅ 参数说明完整
- ✅ 使用示例丰富
- ✅ 边界情况说明
- ✅ 更新相关文档

### 测试质量

- ✅ 正常情况测试
- ✅ 异常情况测试
- ✅ 边界条件测试
- ✅ 集成测试通过
- ✅ 手动测试验证

## 常见问题

### Q: 如何调试命令？

**A**: 
1. 查看 `.agent/logs/` 下的日志文件
2. 使用 `/doctor` 诊断运行时状态
3. 在代码中添加 `console.print()` 输出调试信息
4. 使用 Python 调试器：`import pdb; pdb.set_trace()`

### Q: 如何处理路径问题？

**A**:
1. 使用 `AIGUIBIN_CLI_HOME` 和 `AIGUIBIN_AGENT_DIR` 常量
2. 使用 `os.path.join()` 构建路径
3. 使用 `os.path.abspath()` 获取绝对路径
4. 测试不同安装目录的情况

### Q: 如何测试脚本？

**A**:
1. 使用不同参数组合测试
2. 测试异常输入处理
3. 检查输出文件内容
4. 查看任务目录和日志

### Q: 如何处理兼容性？

**A**:
1. 新功能保持向后兼容
2. 提供迁移路径
3. 废弃功能提前通知
4. 使用版本控制管理变更

## 获取帮助

### 文档资源

- **开发规范**：`docs/DEV_GUIDELINES.md`
- **架构文档**：`docs/ARCHITECTURE.md`
- **API 文档**：`docs/API.md`
- **变更日志**：`docs/CHANGELOG.md`
- **依赖管理**：`docs/DEPENDENCIES.md`
- **快速开始**：`docs/QUICKSTART.md`

### 社区支持

- **Issues**：报告 Bug 和功能请求
- **Discussions**：技术讨论和问题解答
- **Pull Requests**：代码贡献和审查

### 联系方式

- **项目维护者**：[您的联系方式]
- **邮件列表**：[项目邮件列表]
- **即时通讯**：[Discord/Slack 群组]

## 贡献者列表

感谢所有贡献者的努力！

### 核心贡献者
- [您的名字] - 项目创始人，核心架构设计

### 贡献者
- [贡献者名字] - 贡献内容

### 特别感谢
- [开源项目] - 使用的开源库和工具

## 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。

---

**再次感谢您的贡献！** 🎉

您的帮助让 AIguibinCLI 变得更好！