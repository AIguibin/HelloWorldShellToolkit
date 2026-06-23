# AIguibinCLI 版本变更日志

本文档记录 AIguibinCLI 的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [3.5.1] - 2026-06-23

### 修复
- **文档对齐**：统一所有文件版本号 v3.0 → v3.5，修正启动横幅
- **openpyxl 漏装**：install.bat 新增 openpyxl 依赖安装
- **步骤标签一致性**：install.bat 统一使用 14 步分母
- **.gitignore 更新**：移除废弃的 msys64/，新增 git/node/dist 等忽略规则
- **README.md 修正**：更新核心模块数量(9个)、文件行数、目录结构、命令清单
- **版本号统一**：aiguibin.py、dispatcher.py、runtime.py、executor.py、入口脚本

### 移除
- 删除 test_bug_fixes.py

---

## [3.5.0] - 2026-06-22

### 新增
- **依赖管理系统**：统一的 Python、Node.js、Shell 工具依赖管理
  - `/list-python`, `/install-python`, `/update-python`, `/uninstall-python`
  - `/list-node`, `/install-node`, `/update-node`, `/uninstall-node`
  - `/list-tools`, `/add-tool`, `/remove-tool`
  - `/dep-config`, `/dep-sync`
- **应用数据目录**：新增 `.agent/` 目录结构
  - 历史记录移至 `.agent/.aiguibin_history`
  - 应用级日志存放在 `.agent/logs/`
- **依赖配置文件**：新增配置驱动的依赖管理
  - `config/dependencies/python-dependencies.yaml`
  - `config/dependencies/node-dependencies.json`
  - `config/dependencies/shell-tools.yaml`
- **工具目录**：新增 `tools/` 自定义工具目录
- **开发文档**：完整的开发规范和 API 文档

### 变更
- **目录结构重构**：
  - 配置文件保持原有位置
  - 应用数据和日志分离到 `.agent/` 目录
  - 工作目录仅包含任务输出
- **安装脚本升级**：从 12 步扩展到 14 步
  - 新增依赖管理目录创建
  - 新增 `.agent/` 目录结构创建
- **版本号更新**：v3.0 → v3.5
- **环境变量扩展**：新增 `AIGUIBIN_AGENT_DIR` 环境变量

### 修复
- **Critical Bug**：修复 `dispatcher.py` 中调用不存在的 `get_node_home()` 方法
  - 改为使用 `get_node_path()` 并通过 `os.path.dirname()` 推导目录
  - 影响范围：依赖管理系统初始化
  - 严重程度：P0（导致启动崩溃）

### 移除
- 无

---

## [3.0.0] - 2026-06-18

### 新增
- **v3.0 重大架构更新**：从 MSYS2 迁移到 Git 便携版 + Node.js
  - 内嵌 Git 便携版（替代 306MB 的 MSYS2）
  - 内嵌 Node.js 22.x LTS 便携版
  - 自动下载和版本管理（bootstrap.py）
- **Bootstrap 系统**：自动下载缺失的运行时组件
  - npmmirror API 集成
  - 版本号缓存（7天TTL）
  - 智能版本查询
- **多语言脚本支持**：
  - Python (`.py`)
  - Bash (`.sh`)
  - Batch (`.bat`)
  - PowerShell (`.ps1`)
  - JavaScript/Node.js (`.js`)
- **增强的内置命令**：
  - `/shell` - 启动内嵌 Git Bash
  - `/install-pkg` - npm 全局安装包
  - `/env` - 显示运行时路径
  - `/doctor` - 诊断运行时完整性
- **运行时检测系统**：RuntimeDetector 类
  - 三级回退策略（内嵌 → 系统 → None）
  - 动态 PATH 构建
  - 运行时状态检查

### 变更
- **架构重构**：
  - 移除 MSYS2（释放 306MB 空间）
  - 改用 Git 便携版自带 Git Bash
  - 体积减少 70%（306MB → ~95MB）
- **安装脚本重写**：install.bat 从 12 步改为新的 12 步
- **任务目录调整**：从安装目录移到工作目录
- **环境变量系统**：扩展的环境变量注入机制

### 修复
- **Windows shebang 问题**：扩展名检测优先于 shebang
  - 避免了 Microsoft Store 别名问题
- **PowerShell BOM 问题**：改用 cmd echo 写入配置文件
  - 避免了 UTF-8 BOM 导致的解析错误
- **路径转换问题**：Git Bash 中设置 `MSYS_NO_PATHCONV=1`
  - 解决了命令参数被误转为路径的问题

### 移除
- **MSYS2 支持**：完全移除 MSYS2 相关代码
  - 移除 `msys64/` 目录
  - 移除 MSYS2 下载和安装逻辑
  - 移除 `scripts/setup_msys.py`
- **旧的依赖安装方式**：`/install-pkg` 改为使用 npm

---

## [2.5.0] - 2026-06-15

### 新增
- **多语言脚本支持**：支持 `.sh`, `.bat`, `.ps1`, `.js` 脚本
- **扩展名优先策略**：基于文件扩展名选择解释器
- **示例脚本**：新增多种语言示例脚本
  - `gitinfo.sh` - Bash 脚本示例
  - `ping.ps1` - PowerShell 脚本示例
  - `npmcheck.js` - Node.js 脚本示例

### 变更
- **解释器检测逻辑**：从 shebang 优先改为扩展名优先
- **参数处理增强**：支持更多参数类型和格式

### 修复
- **Windows shebang 解析问题**：避免 Microsoft Store 别名

---

## [2.0.0] - 2026-06-10

### 新增
- **全局命令行工具**：可在任意目录执行
- **安装系统**：install.bat 自动配置环境
- **工作空间分离**：安装目录与工作目录分离
- **新命令**：
  - `/workspace` - 查看工作空间信息
  - `/cd <path>` - 切换工作目录
- **Shell 入口脚本**：
  - `bin/aiguibin.bat` - CMD 入口
  - `bin/aiguibin.ps1` - PowerShell 入口
  - `bin/aiguibin` - Bash 入口

### 变更
- **架构重构**：从本地工具变为全局工具
- **任务目录调整**：移到工作目录下
- **环境变量管理**：系统级环境变量设置
- **路径自适应**：安装目录可动态变化

### 修复
- **路径计算问题**：基于脚本位置动态计算安装目录

### 移除
- **本地限制**：不再限制在项目目录执行

---

## [1.0.0] - 2026-06-01

### 新增
- **基础 Aiguibin 系统**：`/命令` 调度系统
- **核心模块**：
  - `command_parser.py` - 命令解析器
  - `registry.py` - 脚本注册表
  - `task_manager.py` - 任务管理器
  - `executor.py` - 脚本执行引擎
  - `dispatcher.py` - 命令调度器
- **内置命令**：
  - `/help` - 帮助信息
  - `/list` - 列出命令
  - `/register` - 注册脚本
  - `/unregister` - 取消注册
  - `/reload` - 重新加载配置
  - `/exit` - 退出
- **参数解析**：支持 `--key=value`, `--flag`, 位置参数
- **任务管理**：每次执行创建任务目录
- **交互式 CLI**：支持 readline 历史和补全
- **单次执行模式**：支持 `aiguibin /command` 非交互式执行

---

## 版本说明

### 版本号规则
- **Major**：重大架构变更，不向后兼容
- **Minor**：新功能添加，向后兼容
- **Patch**：Bug 修复和小改进

### 发布周期
- **Major 版本**：6-12 个月，重大架构升级
- **Minor 版本**：1-3 个月，新功能发布
- **Patch 版本**：按需发布，紧急修复

### 兼容性承诺
- **Minor 版本**：保证向后兼容
- **Patch 版本**：完全兼容
- **Major 版本**：提供迁移路径

## 即将发布

### [3.5.1] - 计划中
- 优化依赖管理日志性能
- 增强错误提示信息
- 修复已知的小问题

### [3.6.0] - 计划中
- 新增更多工具下载支持
- 改进依赖冲突检测
- 增加依赖版本锁定功能

---

**变更记录说明**：
- 每个版本按照新功能、变更、修复、移除分类
- 重大变更有详细说明
- Bug 修复标注严重程度
- 提供版本兼容性信息