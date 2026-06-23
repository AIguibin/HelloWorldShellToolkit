"""
命令解析器 - 解析 /command 格式的指令及参数

支持格式:
  /run script.py --env=prod --verbose arg1 arg2
  /build --target=release --clean main.app
  /deploy --env=staging --dry-run

参数类型:
  - 键值对:  --key=value 或 --key value
  - 布尔标志: --flag (解析为 True) 或 --no-flag (解析为 False)
  - 位置参数: 不以 -- 开头的参数
"""

import shlex
from dataclasses import dataclass, field
from typing import Any


@dataclass
class ParsedCommand:
    """解析后的命令结构"""
    command: str = ""
    positional_args: list[str] = field(default_factory=list)
    kwargs: dict[str, Any] = field(default_factory=dict)
    flags: set[str] = field(default_factory=set)
    raw_input: str = ""


class CommandParser:
    """命令解析器，支持键值对、布尔标志、位置参数"""

    def parse(self, raw_input: str) -> ParsedCommand:
        """解析用户输入的命令字符串"""
        raw_input = raw_input.strip()
        if not raw_input:
            return ParsedCommand(raw_input=raw_input)

        # 提取命令名（以 / 开头的第一个 token）
        tokens = shlex.split(raw_input, posix=True)
        if not tokens:
            return ParsedCommand(raw_input=raw_input)

        command = tokens[0]
        if command.startswith("/"):
            command = command[1:]

        positional_args: list[str] = []
        kwargs: dict[str, Any] = {}
        flags: set[str] = set()

        i = 1
        while i < len(tokens):
            token = tokens[i]

            if token.startswith("--no-"):
                # 布尔标志取反: --no-verbose → flags 中不含 verbose
                flag_name = token[5:]
                flags.discard(flag_name)
                i += 1

            elif token.startswith("--"):
                # 可能是 --key=value 或 --key value 或 --flag
                key_part = token[2:]

                if "=" in key_part:
                    # --key=value
                    key, value = key_part.split("=", 1)
                    kwargs[key] = self._auto_convert(value)
                    i += 1

                elif i + 1 < len(tokens):
                    next_token = tokens[i + 1]
                    # --key value（下一个 token 必须不是 --flag 或 -x 短标志）
                    is_long_flag = next_token.startswith("--")
                    is_short_flag = next_token.startswith("-") and len(next_token) == 2 and next_token[1].isalpha()
                    if not is_long_flag and not is_short_flag:
                        kwargs[key_part] = self._auto_convert(next_token)
                        i += 2
                    else:
                        # 独立布尔标志: --verbose
                        flags.add(key_part)
                        i += 1
                else:
                    # 独立布尔标志: --verbose
                    flags.add(key_part)
                    i += 1

            elif token.startswith("-") and len(token) == 2:
                # 短标志: -v → flags 添加 'v'
                flag_name = token[1:]
                flags.add(flag_name)
                i += 1

            else:
                # 位置参数
                positional_args.append(token)
                i += 1

        return ParsedCommand(
            command=command,
            positional_args=positional_args,
            kwargs=kwargs,
            flags=flags,
            raw_input=raw_input,
        )

    def _auto_convert(self, value: str) -> Any:
        """自动将字符串值转换为合适的 Python 类型"""
        if value.lower() == "true":
            return True
        if value.lower() == "false":
            return False
        if value.lower() == "none" or value.lower() == "null":
            return None

        # 尝试转整数
        try:
            return int(value)
        except ValueError:
            pass

        # 尝试转浮点数
        try:
            return float(value)
        except ValueError:
            pass

        return value
