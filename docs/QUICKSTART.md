# 30 秒快速开始

> **目标**：从拿到分发包到执行第一条命令，不超过 30 秒。

---

## 分发包说明

AIguibinCLI 提供两种 ZIP 分发包，按需选择其一即可：

| 包名 | 体积 | 适用场景 | 是否需联网 |
|------|------|---------|-----------|
| `AIguibinCLI-v3.5.1-lite.zip` | ~1 MB | 网络畅通、追求最小下载 | ✅ 首次需联网下载运行时 |
| `AIguibinCLI-v3.5.1-full.zip` | ~150 MB | 离线环境、企业内网 | ❌ 完全离线可用 |

**两种包安装后的最终形态完全一致**，区别仅在于运行时（Python/Git/Node.js）是下载还是预置。

---

## 方式一：源码包（lite，推荐联网用户）

### 3 步完成安装

```
① 解压 → ② 双击 install.bat → ③ 重开终端验证
```

**详细操作**：

1. **解压** `AIguibinCLI-v3.5.1-lite.zip` 到任意目录
   - 推荐路径：`D:\AIguibinCLI` 或 `C:\Tools\AIguibinCLI`
   - ⚠️ **禁止路径包含中文或空格**（否则 cmd.exe 编码崩溃）

2. **双击** `install.bat`
   - 脚本会自动完成 14 步安装：
     - 下载 Python 3.13.3 Embeddable（~15MB）
     - 下载 Git 2.54.0 便携版（~60MB）
     - 下载 Node.js 22.x 便携版（~35MB）
     - 安装核心依赖（rich、pyyaml、pyreadline3、openpyxl）
     - 配置 `AIGUIBIN_CLI_HOME` 环境变量
     - 将 `bin/` 加入 `PATH`
   - 全程使用国内镜像源（清华 + npmmirror），无需代理

3. **重新打开终端**，执行验证：
   ```batch
   aiguibin /hello
   ```
   看到欢迎信息即安装成功。

---

## 方式二：完整包（full，推荐离线用户）

### 2 步完成安装

```
① 解压 → ② 双击 install.bat
```

**详细操作**：

1. **解压** `AIguibinCLI-v3.5.1-full.zip` 到任意目录
   - 包内已含 `python/`、`git/`、`node/` 三个运行时目录
   - ⚠️ **禁止路径包含中文或空格**

2. **双击** `install.bat`
   - 脚本检测到运行时已存在，**跳过下载**
   - 仅执行环境变量配置和 PATH 注册（约 2 秒）

3. **重新打开终端**，执行验证：
   ```batch
   aiguibin /hello
   ```

---

## 首次使用指引

安装成功后，在任意目录打开终端（CMD / PowerShell / Git Bash 均可）：

```batch
# 进入交互式 CLI
aiguibin

# 查看所有可用命令
aiguibin > /help

# 查看已注册脚本
aiguibin > /list

# 检查运行时状态
aiguibin > /doctor

# 查看环境变量
aiguibin > /env

# 退出
aiguibin > /exit
```

### 单次执行模式（非交互式）

```batch
# 直接执行命令，执行后退出
aiguibin /hello
aiguibin /sysinfo
aiguibin /gitinfo
```

---

## 三种终端入口

| 终端 | 入口命令 | 适用场景 |
|------|---------|---------|
| CMD | `aiguibin` | 默认入口，兼容性最好 |
| PowerShell | `aiguibin` | 同上，支持 PS 特性 |
| Git Bash | `aiguibin` | 路径自动转换，适合 Bash 脚本 |

三种入口功能完全等价，任选其一即可。

---

## 常见问题

### Q1: 双击 install.bat 闪退

**原因**：路径含中文/空格，或权限不足。

**解决**：
1. 确保安装路径仅含英文、数字、下划线、连字符
2. 右键 → 以管理员身份运行

### Q2: `aiguibin` 命令未找到

**原因**：环境变量未生效。

**解决**：
1. **关闭所有终端窗口**，重新打开
2. 或手动执行：`set PATH=%PATH%;D:\AIguibinCLI\bin`（替换为实际路径）
3. 或运行 `D:\AIguibinCLI\bin\aiguibin.bat`（绝对路径调用）

### Q3: 首次启动卡在下载运行时

**原因**：网络问题或镜像源不可达。

**解决**：
1. 检查网络连接
2. 若企业内网受限，改用 `full` 完整包
3. 手动下载运行时放到对应目录：
   - `python/` ← Python 3.13.3 Embeddable
   - `git/` ← PortableGit 2.54.0
   - `node/` ← Node.js 22.x 便携版

### Q4: SmartScreen 提示"已保护你的电脑"

**原因**：Windows 对 .bat 文件的默认安全策略。

**解决**：点击"更多信息" → "仍要运行"

### Q5: 如何卸载

```batch
# 方式一：使用卸载脚本
D:\AIguibinCLI\uninstall.bat

# 方式二：直接删除目录
rmdir /s /q D:\AIguibinCLI
```

卸载会清理环境变量和 PATH，不残留任何系统垃圾。

---

## 下一步

- 📖 完整文档：参见 [README.md](../README.md)
- 📦 依赖管理：参见 [DEPENDENCIES.md](./DEPENDENCIES.md)
- 🛠 注册自定义脚本：`aiguibin > /register mycmd --script scripts/myscript.py`

---

**安装遇到问题？** 执行 `aiguibin /doctor` 进行诊断，或查看 `.agent/logs/` 下的日志文件。
