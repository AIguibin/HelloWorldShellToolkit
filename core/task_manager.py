"""
任务文件夹管理 - 自动创建并维护结构化的任务目录

v2.0 改造:
  - 任务目录跟随工作空间（cwd），而非安装目录
  - 支持 AIGUIBIN_TASKS_DIR 环境变量自定义任务目录位置

每个任务的工作空间:
  <workspace>/.aiguibin/tasks/task_20260615_143022/
  ├── config.json    # 任务配置（命令、参数、状态）
  ├── logs/          # 执行日志
  │   └── execution.log
  └── outputs/       # 输出结果
"""

import json
import os
from datetime import datetime
from typing import Any


class TaskManager:
    """任务目录管理器"""

    def __init__(self, workspace: str):
        """
        Args:
            workspace: 工作空间目录，任务将创建在 <workspace>/.aiguibin/tasks/ 下
        """
        self.workspace = workspace

        # 支持通过环境变量自定义任务目录
        custom_dir = os.environ.get("AIGUIBIN_TASKS_DIR")
        if custom_dir:
            self.tasks_dir = os.path.abspath(custom_dir)
        else:
            self.tasks_dir = os.path.join(workspace, ".aiguibin", "tasks")

        os.makedirs(self.tasks_dir, exist_ok=True)

    def create_task(self, command: str, args: dict | None = None) -> str:
        """创建新任务，返回任务 ID"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        task_id = f"task_{timestamp}"
        task_dir = os.path.join(self.tasks_dir, task_id)

        os.makedirs(task_dir, exist_ok=True)
        os.makedirs(os.path.join(task_dir, "logs"), exist_ok=True)
        os.makedirs(os.path.join(task_dir, "outputs"), exist_ok=True)

        config = {
            "task_id": task_id,
            "command": command,
            "args": args or {},
            "status": "pending",
            "workspace": self.workspace,
            "created_at": datetime.now().isoformat(),
        }
        config_path = os.path.join(task_dir, "config.json")
        with open(config_path, "w", encoding="utf-8") as f:
            json.dump(config, f, ensure_ascii=False, indent=2)

        return task_id

    def get_task_dir(self, task_id: str) -> str:
        """获取任务目录路径"""
        return os.path.join(self.tasks_dir, task_id)

    def get_log_path(self, task_id: str) -> str:
        """获取任务日志文件路径"""
        return os.path.join(self.tasks_dir, task_id, "logs", "execution.log")

    def get_output_dir(self, task_id: str) -> str:
        """获取任务输出目录路径"""
        return os.path.join(self.tasks_dir, task_id, "outputs")

    def update_status(self, task_id: str, status: str):
        """更新任务状态"""
        config_path = os.path.join(self.tasks_dir, task_id, "config.json")
        if os.path.exists(config_path):
            with open(config_path, "r", encoding="utf-8") as f:
                config = json.load(f)
            config["status"] = status
            config["updated_at"] = datetime.now().isoformat()
            with open(config_path, "w", encoding="utf-8") as f:
                json.dump(config, f, ensure_ascii=False, indent=2)

    def append_log(self, task_id: str, message: str):
        """追加日志"""
        log_path = self.get_log_path(task_id)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(f"[{timestamp}] {message}\n")

    def list_tasks(self, limit: int = 20) -> list[dict[str, Any]]:
        """列出最近的任务"""
        tasks = []
        if not os.path.exists(self.tasks_dir):
            return tasks

        for name in sorted(os.listdir(self.tasks_dir), reverse=True):
            task_dir = os.path.join(self.tasks_dir, name)
            if not os.path.isdir(task_dir):
                continue

            config_path = os.path.join(task_dir, "config.json")
            if os.path.exists(config_path):
                with open(config_path, "r", encoding="utf-8") as f:
                    tasks.append(json.load(f))

            if len(tasks) >= limit:
                break

        return tasks

    def get_task_info(self, task_id: str) -> dict[str, Any] | None:
        """获取任务详情"""
        config_path = os.path.join(self.tasks_dir, task_id, "config.json")
        if not os.path.exists(config_path):
            return None
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)
