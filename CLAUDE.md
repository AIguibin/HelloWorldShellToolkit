# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

AIguibin Agent System v3.5 — a local CLI agent with embedded runtimes (Python, Git Bash, Node.js). Users invoke commands with `/command --key=value --flag arg` syntax, which are either built-in handlers or user-registered scripts executed via auto-detected interpreters.

## Commands

```bash
# Direct execution (tests a command non-interactively)
python aiguibin.py /hello --name=World

# Interactive CLI (starts the REPL)
python aiguibin.py

# Build distributable ZIPs (lite + full)
python build.py
```

## Architecture

The dispatch chain is: `aiguibin.py` → `CommandParser` → `Dispatcher` → `ScriptExecutor`/`TaskManager`.

**Entry points** (`bin/`): `aiguibin.bat` (CMD), `aiguibin` (bash), `aiguibin.ps1` (PowerShell). All resolve `AIGUIBIN_CLI_HOME`, set runtime env vars, and invoke `aiguibin.py`.

**CommandParser** (`core/command_parser.py`): Converts `/cmd --key=value --flag --no-flag positional` into a `ParsedCommand` dataclass with kwargs, flags, and positional_args.

**Dispatcher** (`core/dispatcher.py`): Routes in three tiers — built-in commands first (hardcoded in `self._builtins` dict), then registered scripts from `ScriptRegistry`, then unknown-command error. Each built-in gets a `_cmd_<name>` method.

**ScriptRegistry** (`core/registry.py`): Loads command→script mappings from `config/registry.yaml`. Supports runtime registration (`/register`) with persistence back to YAML. Validates params against `ParamDef` (required, type, choices).

**ScriptExecutor** (`core/executor.py`): Detects interpreter by extension (`.py`→Python, `.sh`→Bash, `.js`→Node, `.bat`/`.cmd`→cmd, `.ps1`→PowerShell), then runs the script as a subprocess with real-time stdout/stderr capture and timeout control.

**RuntimeDetector** (`core/runtime.py`): Locates Python/Bash/Node.js with a fallback chain: embedded path (`AIGUIBIN_CLI_HOME/python/`, `git/`, `node/`) → `shutil.which()` / `sys.executable` → `None`. `build_path_env()` prepends embedded dirs to PATH for child processes.

**TaskManager** (`core/task_manager.py`): Creates structured task directories under `<workspace>/.aiguibin/tasks/task_<timestamp>/` with `config.json`, `logs/execution.log`, and `outputs/`. Task states: pending → running → completed/failed.

**DependencyManager** (`core/dependency_manager.py`): Three managers (`PythonDependencyManager`, `NodeDependencyManager`, `ToolManager`) exposed via built-in commands like `/install-python`, `/list-node`, `/add-tool`.

**Bootstrap** (`core/bootstrap.py`): Auto-downloads missing runtimes (Git portable, Node.js) using npmmirror APIs. Called by `aiguibin.bat` before launching the CLI.

## Key conventions

- **Environment variables injected into script subprocesses**: `AIGUIBIN_TASK_ID`, `AIGUIBIN_TASK_DIR`, `AIGUIBIN_OUTPUT_DIR`, `AIGUIBIN_WORKSPACE`, `AIGUIBIN_CLI_HOME`, `AIGUIBIN_BASH`, `AIGUIBIN_PYTHON`. Scripts should use these rather than hardcoding paths.
- **Scripts live in `scripts/`**, registered commands point to them in `config/registry.yaml`. A registered script's relative path is resolved against `scripts/`.
- **Application data** (history, logs) goes in `.agent/` under `AIGUIBIN_CLI_HOME`. Task outputs go in `.aiguibin/tasks/` under the current workspace.
- **Workspace** defaults to `cwd`, overridable via `--workspace` or `AIGUIBIN_WORKSPACE` env var.
- **Parameters** in registry.yaml use `flag` to map CLI `--flag` to a named param. Positional args fill required params that aren't satisfied by named flags.
- **Dependencies**: `rich`, `pyyaml`, `pyreadline3` (Windows), `openpyxl`, `xlrd==1.2.0`.
