"""
脚本注册机制 - 通过 YAML 配置文件管理可用脚本

支持功能:
  - 从 YAML 文件加载脚本注册信息
  - 动态注册新脚本（运行时添加并持久化到配置文件）
  - 按命令名查找脚本
  - 参数定义与校验
"""

import os
from dataclasses import dataclass, field
from typing import Any

import yaml


@dataclass
class ParamDef:
    """参数定义"""
    name: str
    type: str = "string"  # string, int, float, bool, choice
    required: bool = False
    default: Any = None
    description: str = ""
    choices: list[str] = field(default_factory=list)
    flag: str = ""  # 对应的 CLI flag 名，如 --env

    def validate_value(self, value: Any) -> tuple[bool, str]:
        """校验参数值是否合法"""
        if self.choices and str(value) not in self.choices:
            return False, f"值 '{value}' 不在允许范围内 {self.choices}"
        return True, ""


@dataclass
class CommandDef:
    """命令定义"""
    name: str
    script: str  # 脚本相对路径（相对于 scripts/ 目录）
    description: str = ""
    params: list[ParamDef] = field(default_factory=list)
    tags: list[str] = field(default_factory=list)


class ScriptRegistry:
    """脚本注册表，从 YAML 配置加载并管理可用脚本"""

    def __init__(self, config_path: str, scripts_dir: str):
        self.config_path = config_path
        self.scripts_dir = scripts_dir
        self._commands: dict[str, CommandDef] = {}
        self._load()

    def _load(self):
        """从 YAML 配置文件加载脚本注册"""
        if not os.path.exists(self.config_path):
            return

        with open(self.config_path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}

        for item in data.get("commands", []):
            cmd_def = self._parse_command(item)
            if cmd_def:
                self._commands[cmd_def.name] = cmd_def

    def _parse_command(self, data: dict) -> CommandDef | None:
        """解析单条命令配置"""
        if "name" not in data or "script" not in data:
            return None

        params = []
        for p in data.get("params", []):
            params.append(ParamDef(
                name=p.get("name", ""),
                type=p.get("type", "string"),
                required=p.get("required", False),
                default=p.get("default"),
                description=p.get("description", ""),
                choices=p.get("choices", []),
                flag=p.get("flag", ""),
            ))

        return CommandDef(
            name=data["name"],
            script=data["script"],
            description=data.get("description", ""),
            params=params,
            tags=data.get("tags", []),
        )

    def get(self, name: str) -> CommandDef | None:
        """按命令名查找"""
        return self._commands.get(name)

    def list_commands(self) -> list[CommandDef]:
        """列出所有已注册命令"""
        return list(self._commands.values())

    def get_all(self) -> dict[str, CommandDef]:
        """获取完整注册表"""
        return dict(self._commands)

    def register(self, name: str, script: str, description: str = "",
                 params: list[dict] | None = None, tags: list[str] | None = None) -> bool:
        """动态注册新脚本（运行时添加并持久化到配置文件）"""
        if name in self._commands:
            return False

        param_defs = []
        if params:
            for p in params:
                param_defs.append(ParamDef(
                    name=p.get("name", ""),
                    type=p.get("type", "string"),
                    required=p.get("required", False),
                    default=p.get("default"),
                    description=p.get("description", ""),
                    choices=p.get("choices", []),
                    flag=p.get("flag", ""),
                ))

        cmd_def = CommandDef(
            name=name,
            script=script,
            description=description,
            params=param_defs,
            tags=tags or [],
        )

        self._commands[name] = cmd_def
        self._save()
        return True

    def unregister(self, name: str) -> bool:
        """取消注册脚本"""
        if name not in self._commands:
            return False
        del self._commands[name]
        self._save()
        return True

    def reload(self):
        """重新从配置文件加载"""
        self._commands.clear()
        self._load()

    def _save(self):
        """持久化当前注册表到 YAML"""
        commands_data = []
        for cmd in self._commands.values():
            cmd_dict = {
                "name": cmd.name,
                "script": cmd.script,
                "description": cmd.description,
                "tags": cmd.tags,
                "params": [
                    {
                        "name": p.name,
                        "type": p.type,
                        "required": p.required,
                        "default": p.default,
                        "description": p.description,
                        "choices": p.choices,
                        "flag": p.flag,
                    }
                    for p in cmd.params
                ],
            }
            commands_data.append(cmd_dict)

        data = {"commands": commands_data}

        os.makedirs(os.path.dirname(self.config_path), exist_ok=True)
        with open(self.config_path, "w", encoding="utf-8") as f:
            yaml.dump(data, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

    def validate_params(self, cmd_def: CommandDef, parsed_kwargs: dict,
                        parsed_flags: set, parsed_positional: list) -> tuple[bool, list[str]]:
        """校验解析后的参数是否符合命令定义

        必填参数优先通过命名参数(--flag=value, --flag)满足，
        未满足的必填参数按定义顺序从位置参数中依次映射。
        """
        errors = []
        # ── 第一步：收集命名参数未满足的必填参数 ──
        unsatisfied: list[ParamDef] = []
        for param in cmd_def.params:
            if not param.required:
                continue
            flag_name = param.flag or param.name
            # 通过 --key=value 或 --flag 满足 → 跳过
            if flag_name in parsed_kwargs or flag_name in parsed_flags:
                continue
            # 有默认值 → 跳过
            if param.default is not None:
                continue
            unsatisfied.append(param)

        # ── 第二步：用位置参数按顺序映射 ──
        for i, param in enumerate(unsatisfied):
            if i >= len(parsed_positional):
                flag_name = param.flag or param.name
                errors.append(f"缺少必填参数: --{flag_name}")
            else:
                valid, msg = param.validate_value(parsed_positional[i])
                if not valid:
                    flag_name = param.flag or param.name
                    errors.append(f"参数 --{flag_name} 的值不合法: {msg}")

        # ── 第三步：校验命名参数的值合法性 ──
        for param in cmd_def.params:
            flag_name = param.flag or param.name
            if flag_name in parsed_kwargs:
                valid, msg = param.validate_value(parsed_kwargs[flag_name])
                if not valid:
                    errors.append(f"参数 --{flag_name} 的值不合法: {msg}")

        return len(errors) == 0, errors
