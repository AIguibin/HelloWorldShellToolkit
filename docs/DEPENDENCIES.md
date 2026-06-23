# 依赖管理系统使用指南

AIguibinCLI v3.5.1 集成了完整的依赖管理系统，支持 Python、Node.js 和 Shell 工具的统一管理。

## 快速开始

### 1. 查看依赖配置

```batch
aiguibin [MyProject] > /dep-config
```

这会显示所有依赖配置的概览，包括 Python、Node.js 和 Shell 工具的配置信息。

### 2. Python 依赖管理

#### 查看已安装的包
```batch
aiguibin [MyProject] > /list-python
```

#### 安装包
```batch
# 安装单个包
aiguibin [MyProject] > /install-python requests

# 安装多个包
aiguibin [MyProject] > /install-python requests pandas

# 从配置文件安装（推荐）
aiguibin [MyProject] > /install-python --from-file
```

#### 更新包
```batch
# 更新指定包
aiguibin [MyProject] > /update-python requests

# 更新所有包
aiguibin [MyProject] > /update-python --all
```

#### 卸载包
```batch
aiguibin [MyProject] > /uninstall-python requests
```

#### 导出当前依赖
```batch
aiguibin [MyProject] > /export-python
```

### 3. Node.js 依赖管理

#### 查看已安装的包
```batch
# 查看本地包
aiguibin [MyProject] > /list-node

# 查看全局包
aiguibin [MyProject] > /list-node --global
```

#### 安装包
```batch
# 本地安装
aiguibin [MyProject] > /install-node express

# 全局安装
aiguibin [MyProject] > /install-node --global typescript

# 保存到 package.json
aiguibin [MyProject] > /install-node express --save

# 保存为开发依赖
aiguibin [MyProject] > /install-node eslint --save-dev
```

#### 更新包
```batch
# 更新指定包
aiguibin [MyProject] > /update-node express

# 更新所有全局包
aiguibin [MyProject] > /update-node --global
```

#### 卸载包
```batch
# 卸载本地包
aiguibin [MyProject] > /uninstall-node express

# 卸载全局包
aiguibin [MyProject] > /uninstall-node --global typescript
```

### 4. Shell 工具管理

#### 查看已安装的工具
```batch
aiguibin [MyProject] > /list-tools
```

#### 添加工具
```batch
# 从网络下载
aiguibin [MyProject] > /add-tool https://github.com/BurntSushi/ripgrep/releases/download/v14.0.3/ripgrep-14.0.3-x86_64-pc-windows-msvc.zip rg.exe

# 从本地添加
aiguibin [MyProject] > /add-tool --local C:\Downloads\ripgrep.exe rg.exe
```

#### 移除工具
```batch
aiguibin [MyProject] > /remove-tool rg.exe
```

### 5. 同步依赖

```batch
# 根据配置文件同步安装所有依赖
aiguibin [MyProject] > /dep-sync

# 仅检查差异，不实际安装
aiguibin [MyProject] > /dep-sync --check-only
```

## 配置文件说明

### Python 依赖配置

文件位置：`config/dependencies/python-dependencies.yaml`

```yaml
python_version: "3.13"
site_packages_path: "python/Lib/site-packages"
dependencies:
  - name: rich
    version: ">=13.0.0"
    required: true
    description: Terminal UI library
    tags: [core, ui]
```

### Node.js 依赖配置

文件位置：`config/dependencies/node-dependencies.json`

```json
{
  "node_version": "22.0.0",
  "global_packages": {
    "typescript": {
      "version": "^5.0.0",
      "description": "TypeScript compiler",
      "required": true
    }
  },
  "local_packages": {
    "express": {
      "version": "^4.18.2",
      "description": "Web framework",
      "required": false
    }
  }
}
```

### Shell 工具配置

文件位置：`config/dependencies/shell-tools.yaml`

```yaml
tools:
  - name: ripgrep
    description: Fast file search tool
    windows_binary: "rg.exe"
    download_url: "https://github.com/BurntSushi/ripgrep/releases"
    version: "14.0.3"
    path: "tools/binaries/"
    required: false
    tags: [productivity, search]
```

## 日志和调试

所有依赖操作都会记录到 `.agent/logs/dependencies.log` 文件中，包含：

- 操作时间戳
- 操作类型（安装/卸载/更新）
- 包/工具名称
- 操作结果
- 错误信息（如果失败）

### 查看依赖日志

```batch
# 查看最近的依赖操作
type D:\AIguibinCLI\.agent\logs\dependencies.log

# 或者使用工具查看
aiguibin [MyProject] > /shell
$ tail -20 ~/.agent/logs/dependencies.log
```

## 常见问题

### Q1: Python 包安装失败

**问题**：运行 `/install-python <package>` 时报错

**解决方案**：
1. 检查网络连接
2. 尝试使用国内镜像：`pip install <package> -i https://pypi.tuna.tsinghua.edu.cn/simple`
3. 检查 Python 解释器是否正常：`/env` 查看 Python 路径

### Q2: Node.js 包安装失败

**问题**：运行 `/install-node <package>` 时报错

**解决方案**：
1. 检查 Node.js 和 npm 是否可用：`/env` 查看 Node.js 路径
2. 尝试手动运行：`node/npm install <package>`
3. 检查网络连接和 npm 配置

### Q3: 工具无法下载

**问题**：运行 `/add-tool <url>` 时下载失败

**解决方案**：
1. 检查 URL 是否正确
2. 手动下载后使用 `/add-tool --local <path> <name>`
3. 检查网络连接和防火墙设置

### Q4: 配置文件格式错误

**问题**：运行 `/dep-sync` 时报错

**解决方案**：
1. 检查 YAML/JSON 文件格式是否正确
2. 使用 YAML/JSON 验证工具检查文件
3. 参考 `config/dependencies/` 下的示例文件

## 最佳实践

### 1. 使用配置文件管理依赖

推荐使用配置文件来管理依赖，而不是手动安装：

```batch
# 编辑配置文件
aiguibin [MyProject] > /shell
$ nano config/dependencies/python-dependencies.yaml

# 同步安装
aiguibin [MyProject] > /dep-sync
```

### 2. 定期更新依赖

```batch
# 更新所有 Python 包
aiguibin [MyProject] > /update-python --all

# 更新所有 Node.js 全局包
aiguibin [MyProject] > /update-node --global
```

### 3. 导出依赖配置

```batch
# 导出当前 Python 依赖到配置文件
aiguibin [MyProject] > /export-python
```

### 4. 版本锁定

在配置文件中使用精确版本号，确保环境一致性：

```yaml
dependencies:
  - name: requests
    version: "==2.31.0"    # 精确版本
    required: true
```

### 5. 依赖隔离

所有依赖都安装到内嵌运行时目录，不会影响系统环境：

- Python 包：`python/Lib/site-packages/`
- Node.js 包：`node/node_modules/`
- Shell 工具：`tools/binaries/`

## 高级功能

### 自定义工具组

在 `shell-tools.yaml` 中定义工具组：

```yaml
tool_groups:
  productivity:
    description: Productivity enhancement tools
    tools: [ripgrep, fd, bat, fzf]
```

批量安装工具组（功能开发中）：

```batch
# 安装生产力工具组
aiguibin [MyProject] > /install-tools productivity
```

### 离线安装

1. 在线环境导出依赖配置
2. 下载所需的包文件
3. 在离线环境手动安装

### 依赖检查

检查依赖完整性（计划中功能）：

```
# 查看已安装的依赖
aiguibin [MyProject] > /list-python
aiguibin [MyProject] > /list-node --global

# 同步配置文件中的依赖
aiguibin [MyProject] > /dep-sync
```

## 性能优化

### 1. 缓存机制

依赖管理系统使用缓存来避免重复下载：

- Python 版本缓存：`config/runtime-versions.json`
- Node.js npm 缓存：`node/.npm/`

### 2. 并发安装

批量安装包时，系统会尽可能并发安装以提高速度。

### 3. 增量更新

更新包时，只更新有新版本的包，跳过已是最新版本的包。

## 安全考虑

### 1. 包验证

下载的包会进行完整性检查：

- Python 包：pip 会验证包的哈希值
- Node.js 包：npm 会验证包的完整性

### 2. 权限管理

所有操作都在安装目录下进行，需要适当的文件权限。

### 3. 卸载确认

卸载重要包时会提示确认，避免误删核心依赖。

## 扩展和自定义

### 添加自定义依赖管理器

可以扩展 `dependency_manager.py` 来支持其他类型的依赖：

```python
class CustomDependencyManager(DependencyManager):
    """自定义依赖管理器"""
    
    def install(self, packages: List[str]) -> Tuple[bool, str]:
        # 自定义安装逻辑
        pass
```

### 自定义命令

在 `dispatcher.py` 中添加自定义依赖管理命令：

```python
def _cmd_custom_dep(self, parsed: ParsedCommand) -> bool:
    """自定义依赖命令"""
    # 实现逻辑
    return True
```

## 故障排查

### 查看详细的错误信息

如果操作失败，查看日志文件获取详细信息：

```batch
type D:\AIguibinCLI\.agent\logs\dependencies.log
```

### 检查运行时状态

使用 `/doctor` 命令检查运行时完整性：

```batch
aiguibin [MyProject] > /doctor
```

### 重置依赖

如果依赖管理出现问题，可以重置：

```batch
# 1. 删除依赖目录
rmdir /s /q D:\AIguibinCLI\python\Lib\site-packages\*

# 2. 重新安装核心依赖
aiguibin [MyProject] > /install-python --from-file
```

## 总结

AIguibinCLI 的依赖管理系统提供了完整的依赖管理能力，包括：

✅ 统一的命令行接口  
✅ 配置文件驱动的自动化  
✅ 多种依赖类型支持  
✅ 完整的日志和监控  
✅ 离线和在线安装支持  
✅ 版本管理和冲突检测  
✅ 性能优化和缓存机制

通过合理使用依赖管理系统，可以大大简化开发环境的管理和维护工作。
