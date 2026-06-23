#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Excel 通用对比工具（统一版）
功能：
  1. 左右并排对比模式（默认）：以 A 为基准，在同一行左右并排展示对比结果
  2. 差异报告模式：生成清单格式的差异报告（支持 JSON 导出）
  3. 自动识别关键列（值唯一的列）
  4. 支持 JSON 智能对比（忽略字段顺序）
  5. 保留 A 的原始样式和格式
  6. 支持对比公式、包含相同单元格、导出 JSON

用法：
  # 模式1：左右并排对比（默认）
  python aiguibin-compare-excel.py A.xlsx B.xlsx
  python aiguibin-compare-excel.py A.xlsx B.xlsx -o output.xlsx --key-col 工号

  # 模式2：差异报告
  python aiguibin-compare-excel.py A.xlsx B.xlsx --mode report -o report.xlsx
  python aiguibin-compare-excel.py A.xlsx B.xlsx --mode report --json output.json

  # 高级选项
  python aiguibin-compare-excel.py A.xlsx B.xlsx --formula --equal
"""

import os
import sys
import json
import copy
import argparse
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Any, Tuple

try:
    from openpyxl import load_workbook, Workbook
    from openpyxl.styles import PatternFill, Font, Border, Side, Alignment
    from openpyxl.utils import get_column_letter
except ImportError:
    print("[错误] 缺少 openpyxl 依赖，请运行：pip install openpyxl")
    sys.exit(1)

# ─────────────────────────────────────────────
# 样式常量（左右并排模式）
# ─────────────────────────────────────────────
FILL_DIFF = PatternFill(start_color="FFFFFF00", end_color="FFFFFF00", fill_type="solid")
FONT_DIFF = Font(color="FF0000", bold=True)

# ─────────────────────────────────────────────
# 样式常量（差异报告模式）
# ─────────────────────────────────────────────
FILL_ONLY_A = PatternFill(start_color="FFE6E6", end_color="FFE6E6", fill_type="solid")
FILL_ONLY_B = PatternFill(start_color="E6F3FF", end_color="E6F3FF", fill_type="solid")
FILL_DIFF_REPORT = PatternFill(start_color="FFF2CC", end_color="FFF2CC", fill_type="solid")
FILL_EQUAL = PatternFill(start_color="E2EFDA", end_color="E2EFDA", fill_type="solid")
FILL_HEADER = PatternFill(start_color="4472C4", end_color="4472C4", fill_type="solid")

FONT_WHITE = Font(color="FFFFFF", bold=True)
FONT_RED = Font(color="FF0000")
FONT_NORMAL = Font(color="000000")

BORDER_THIN = Border(
    left=Side(style="thin"),
    right=Side(style="thin"),
    top=Side(style="thin"),
    bottom=Side(style="thin"),
)


# ─────────────────────────────────────────────
# 核心对比逻辑（共享）
# ─────────────────────────────────────────────

def _is_json_string(s: str) -> bool:
    """判断字符串是否可能是 JSON（对象或数组）"""
    s = s.strip()
    return (s.startswith('{') and s.endswith('}')) or (s.startswith('[') and s.endswith(']'))


def _compare_values(a_val, b_val, compare_json: bool = True) -> bool:
    """
    比较两个值是否相同（类型感知，支持 JSON 智能比较）
    - JSON 字符串：解析后比较（忽略字段顺序）
    - 数值：自动类型转换比较
    - 其他：字符串精确比较
    """
    if a_val is None and b_val is None:
        return True
    if a_val is None or b_val is None:
        return False

    a_str = str(a_val).strip()
    b_str = str(b_val).strip()

    # JSON 智能比较
    if compare_json and _is_json_string(a_str) and _is_json_string(b_str):
        try:
            a_json = json.loads(a_str)
            b_json = json.loads(b_str)
            return a_json == b_json
        except (json.JSONDecodeError, TypeError):
            pass

    # 数值比较
    try:
        return float(a_str) == float(b_str)
    except (ValueError, TypeError):
        pass

    # 字符串比较
    return a_str == b_str


def auto_detect_key_col(ws, sample_rows: int = 100) -> Tuple[Optional[int], Optional[str]]:
    """
    自动识别关键列：找第一个值唯一且非空的列。
    返回 (列索引 1-based, 列名)
    """
    if ws.max_row < 2:
        return None, None

    headers = {}
    for cell in ws[1]:
        if cell.value is not None:
            headers[cell.column] = str(cell.value)

    for col_idx in range(1, ws.max_column + 1):
        col_name = headers.get(col_idx, f"列{get_column_letter(col_idx)}")
        values = []
        for row_idx in range(2, min(ws.max_row + 1, sample_rows + 2)):
            val = ws.cell(row=row_idx, column=col_idx).value
            if val is not None and str(val).strip() != "":
                values.append(str(val).strip())

        if len(values) == 0:
            continue
        # 检查是否唯一（去重后数量等于原始数量）
        if len(set(values)) == len(values):
            return col_idx, col_name

    return None, None


def parse_columns(ws, col_specs: List[str]) -> List[int]:
    """
    将列名/列字母列表解析为列索引列表（1-based）。
    支持：
      - 列字母：A, B, C, AA
      - 列名：工号, 姓名
    """
    # 构建表头映射：列名 → 列索引
    headers = {}
    for cell in ws[1]:
        if cell.value is not None:
            headers[str(cell.value).strip()] = cell.column

    result = []
    for spec in col_specs:
        spec = spec.strip()
        # 尝试作为列字母解析（纯字母，1-3位）
        spec_upper = spec.upper()
        if 1 <= len(spec_upper) <= 3 and all(c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' for c in spec_upper):
            col_idx = 0
            for c in spec_upper:
                col_idx = col_idx * 26 + (ord(c) - ord('A') + 1)
            if 1 <= col_idx <= ws.max_column:
                result.append(col_idx)
            else:
                print(f"[警告] 列字母 '{spec}' 超出范围（最大 {get_column_letter(ws.max_column)}），已跳过")
        # 尝试作为列名解析
        elif spec in headers:
            result.append(headers[spec])
        else:
            print(f"[警告] 找不到列 '{spec}'，已跳过")

    return sorted(set(result))


def read_sheet_to_dict(ws, key_col_idx: int, compare_json: bool = True) -> Tuple[List[Any], Dict[str, List[Any]]]:
    """
    将 Sheet 读取为字典：key=关键列值，value=整行数据（list，长度=max_column）
    返回 (表头列表, 数据字典)
    """
    headers = [cell.value for cell in ws[1]]

    result = {}
    for row in ws.iter_rows(min_row=2, values_only=False):
        key_val = row[key_col_idx - 1].value
        if key_val is None or str(key_val).strip() == "":
            continue
        key_str = str(key_val).strip()
        row_data = [cell.value for cell in row]
        result[key_str] = row_data

    return headers, result


def copy_cell_style(src_cell, dst_cell):
    """复制单元格样式"""
    if src_cell.has_style:
        if src_cell.font:
            dst_cell.font = copy.copy(src_cell.font)
        if src_cell.fill and src_cell.fill.fill_type:
            dst_cell.fill = copy.copy(src_cell.fill)
        if src_cell.border:
            dst_cell.border = copy.copy(src_cell.border)
        if src_cell.alignment:
            dst_cell.alignment = copy.copy(src_cell.alignment)
        if src_cell.number_format:
            dst_cell.number_format = src_cell.number_format


# ─────────────────────────────────────────────
# 模式1：左右并排对比
# ─────────────────────────────────────────────

def compare_side_by_side(
    file_a: str,
    file_b: str,
    output_file: Optional[str] = None,
    key_col_name: Optional[str] = None,
    target_sheets: Optional[List[str]] = None,
    target_columns: Optional[List[str]] = None,
    compare_json: bool = True,
) -> str:
    """
    执行左右并排对比，生成结果文件。
    返回输出文件路径。
    """
    wb_a = load_workbook(file_a, data_only=True)
    wb_b = load_workbook(file_b, data_only=True)

    # 确定输出文件路径
    if output_file is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = f"compare-result-v{timestamp}.xlsx"

    # 以 A 为模板复制（保留样式）
    wb_out = load_workbook(file_a)

    # 确定要处理的 Sheet 列表
    if target_sheets:
        sheets_to_process = [s for s in target_sheets if s in wb_a.sheetnames and s in wb_b.sheetnames]
    else:
        sheets_to_process = [s for s in wb_a.sheetnames if s in wb_b.sheetnames]

    for sheet_name in sheets_to_process:
        ws_a = wb_a[sheet_name]
        ws_b = wb_b[sheet_name]
        ws_out = wb_out[sheet_name]

        # 检查 A 的 Sheet 是否有数据（不止表头）
        if ws_a.max_row < 2:
            print(f"[跳过] Sheet '{sheet_name}'：A 中无数据")
            continue

        # 识别关键列
        if key_col_name:
            key_col_idx = None
            for cell in ws_a[1]:
                if cell.value and str(cell.value) == key_col_name:
                    key_col_idx = cell.column
                    break
            if key_col_idx is None:
                try:
                    key_col_idx = ord(key_col_name.upper()) - ord('A') + 1
                except Exception:
                    pass
            if key_col_idx is None:
                print(f"[警告] Sheet '{sheet_name}'：找不到指定关键列 '{key_col_name}'，跳过")
                continue
        else:
            key_col_idx, _ = auto_detect_key_col(ws_a)
            if key_col_idx is None:
                print(f"[警告] Sheet '{sheet_name}'：无法自动识别关键列，跳过")
                continue

        print(f"[处理] Sheet '{sheet_name}'：关键列 = 第{key_col_idx}列 ({ws_a.cell(row=1, column=key_col_idx).value})")

        # 解析目标列
        if target_columns:
            col_indices = parse_columns(ws_a, target_columns)
            if not col_indices:
                print(f"[警告] Sheet '{sheet_name}'：指定的列均无效，跳过")
                continue
            # 确保关键列在对比列中
            if key_col_idx not in col_indices:
                col_indices.append(key_col_idx)
                col_indices.sort()
                print(f"[提示] 关键列已自动加入对比列")
            print(f"[处理] Sheet '{sheet_name}'：对比列 = {col_indices}")
        else:
            col_indices = list(range(1, len(headers_a) + 1))

        # 读取数据
        headers_a, data_a = read_sheet_to_dict(ws_a, key_col_idx, compare_json)
        _, data_b = read_sheet_to_dict(ws_b, key_col_idx, compare_json)

        a_max_col = ws_a.max_column
        offset_col = a_max_col + 3  # 右侧数据起始列（中间空2列）

        # 写入右侧表头（第1行）
        for i, col_idx in enumerate(col_indices):
            header_val = headers_a[col_idx - 1] if col_idx <= len(headers_a) else ""
            dst_cell = ws_out.cell(row=1, column=offset_col + i, value=header_val)
            src_cell = ws_out.cell(row=1, column=col_idx)
            copy_cell_style(src_cell, dst_cell)

        # 逐行处理 A 的数据
        b_matched_keys = set()

        for row_idx in range(2, ws_a.max_row + 1):
            key_val = ws_a.cell(row=row_idx, column=key_col_idx).value
            if key_val is None or str(key_val).strip() == "":
                continue

            key_str = str(key_val).strip()
            a_row_data = data_a.get(key_str, [])

            if key_str in data_b:
                b_matched_keys.add(key_str)
                b_row_data = data_b[key_str]

                for i, col_idx in enumerate(col_indices):
                    dst_cell = ws_out.cell(row=row_idx, column=offset_col + i)
                    b_val = b_row_data[col_idx - 1] if col_idx <= len(b_row_data) else None
                    dst_cell.value = b_val

                    a_cell = ws_out.cell(row=row_idx, column=col_idx)
                    a_val = a_cell.value

                    same = _compare_values(a_val, b_val, compare_json)

                    if same:
                        copy_cell_style(a_cell, dst_cell)
                    else:
                        dst_cell.fill = FILL_DIFF
                        dst_cell.font = FONT_DIFF
                        if a_cell.alignment:
                            dst_cell.alignment = copy.copy(a_cell.alignment)
                        if a_cell.number_format:
                            dst_cell.number_format = a_cell.number_format
            else:
                pass  # A有B无：右侧留空

        # 追加 B 独有数据到最底部
        b_only_start_row = ws_a.max_row + 1

        for key_str, b_row_data in data_b.items():
            if key_str in b_matched_keys:
                continue

            for i, col_idx in enumerate(col_indices):
                dst_cell = ws_out.cell(row=b_only_start_row, column=offset_col + i)
                b_val = b_row_data[col_idx - 1] if col_idx <= len(b_row_data) else None
                dst_cell.value = b_val

            b_only_start_row += 1

        # 自动调整右侧列宽
        for i, col_idx in enumerate(col_indices):
            col_letter = get_column_letter(offset_col + i)
            max_len = 0
            for row_idx in range(1, ws_out.max_row + 1):
                cell = ws_out.cell(row=row_idx, column=offset_col + i)
                if cell.value:
                    max_len = max(max_len, len(str(cell.value)))
            if max_len > 0:
                ws_out.column_dimensions[col_letter].width = min(max_len + 2, 50)

    # 保存
    out_path = Path(output_file)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    wb_out.save(str(out_path))
    wb_a.close()
    wb_b.close()

    print(f"[完成] 结果已保存至：{out_path.resolve()}")
    return str(out_path.resolve())


# ─────────────────────────────────────────────
# 模式2：差异报告（来自 excel_compare.py）
# ─────────────────────────────────────────────

def compare_sheets_detail(ws_a, ws_b, compare_formula: bool = False, compare_json: bool = True, target_col_indices: Optional[List[int]] = None) -> Dict[str, Any]:
    """
    对比两个 Worksheet 对象，返回详细的差异信息。
    target_col_indices: 指定对比的列索引列表（1-based），None 表示对比所有列。
    """
    result = {
        "sheet_name": ws_a.title,
        "only_in_a": [],
        "only_in_b": [],
        "diff_values": [],
        "equal_count": 0,
        "max_row_a": ws_a.max_row,
        "max_col_a": ws_a.max_column,
        "max_row_b": ws_b.max_row,
        "max_col_b": ws_b.max_column,
    }

    # 收集 A 的所有有值单元格
    cells_a = {}
    for row in ws_a.iter_rows():
        for cell in row:
            if cell.value is not None:
                if target_col_indices is None or cell.column in target_col_indices:
                    cells_a[(cell.row, cell.column)] = cell

    # 收集 B 的所有有值单元格
    cells_b = {}
    for row in ws_b.iter_rows():
        for cell in row:
            if cell.value is not None:
                if target_col_indices is None or cell.column in target_col_indices:
                    cells_b[(cell.row, cell.column)] = cell

    keys_a = set(cells_a.keys())
    keys_b = set(cells_b.keys())

    # 仅 A 有
    for k in sorted(keys_a - keys_b):
        cell = cells_a[k]
        result["only_in_a"].append({
            "row": k[0], "col": k[1],
            "col_letter": get_column_letter(k[1]),
            "value_a": str(cell.value)[:200],
        })

    # 仅 B 有
    for k in sorted(keys_b - keys_a):
        cell = cells_b[k]
        result["only_in_b"].append({
            "row": k[0], "col": k[1],
            "col_letter": get_column_letter(k[1]),
            "value_b": str(cell.value)[:200],
        })

    # 两边都有 → 对比值
    for k in sorted(keys_a & keys_b):
        cell_a = cells_a[k]
        cell_b = cells_b[k]
        val_a = cell_a.value
        val_b = cell_b.value

        same = _compare_values(val_a, val_b, compare_json)

        if same:
            result["equal_count"] += 1
        else:
            result["diff_values"].append({
                "row": k[0], "col": k[1],
                "col_letter": get_column_letter(k[1]),
                "value_a": str(val_a)[:200],
                "value_b": str(val_b)[:200],
            })

    return result


def compare_files_report(
    file_a: str,
    file_b: str,
    output_file: Optional[str] = None,
    sheets: Optional[List[str]] = None,
    compare_formula: bool = False,
    compare_json: bool = True,
    include_equal: bool = False,
    target_columns: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """
    对比两个 Excel 文件，生成差异报告。
    返回差异汇总字典。
    """
    wb_a = load_workbook(file_a, data_only=True)
    wb_b = load_workbook(file_b, data_only=True)

    all_sheets_a = set(wb_a.sheetnames)
    all_sheets_b = set(wb_b.sheetnames)

    if sheets:
        target_sheets = [s for s in sheets if s in all_sheets_a or s in all_sheets_b]
    else:
        target_sheets = list(all_sheets_a | all_sheets_b)

    summary = {
        "file_a": file_a,
        "file_b": file_b,
        "sheets_compared": [],
        "sheets_only_in_a": sorted(list(all_sheets_a - all_sheets_b)),
        "sheets_only_in_b": sorted(list(all_sheets_b - all_sheets_a)),
        "total_differences": 0,
        "details": {},
    }

    # 创建输出工作簿
    wb_out = None
    if output_file:
        wb_out = Workbook()
        if "Sheet" in wb_out.sheetnames:
            del wb_out["Sheet"]

    for sheet_name in target_sheets:
        in_a = sheet_name in all_sheets_a
        in_b = sheet_name in all_sheets_b

        if in_a and in_b:
            ws_a = wb_a[sheet_name]
            ws_b = wb_b[sheet_name]
            # 解析目标列
            if target_columns:
                col_indices = parse_columns(ws_a, target_columns)
            else:
                col_indices = None
            cmp = compare_sheets_detail(ws_a, ws_b, compare_formula, compare_json, col_indices)
            summary["sheets_compared"].append(sheet_name)
            summary["details"][sheet_name] = cmp
            diff_count = len(cmp["only_in_a"]) + len(cmp["only_in_b"]) + len(cmp["diff_values"])
            summary["total_differences"] += diff_count

            if wb_out:
                _write_sheet_report(wb_out, sheet_name, ws_a, ws_b, cmp, include_equal, compare_json)
        elif in_a and wb_out:
            _write_sheet_only(wb_out, sheet_name, wb_a[sheet_name], "A")
        elif in_b and wb_out:
            _write_sheet_only(wb_out, sheet_name, wb_b[sheet_name], "B")

    if wb_out and output_file:
        out_path = Path(output_file)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        wb_out.save(str(out_path))
        summary["output_file"] = str(out_path.resolve())

    wb_a.close()
    wb_b.close()

    return summary


def _write_sheet_report(wb_out, sheet_name: str, ws_a, ws_b, cmp: Dict, include_equal: bool, compare_json: bool):
    """将单个 Sheet 的对比结果写入输出工作簿（差异报告模式）"""
    ws = wb_out.create_sheet(title=sheet_name[:31])

    # 表头
    headers = ["行号", "列", "文件A的值", "文件B的值", "差异类型"]
    for col, h in enumerate(headers, 1):
        cell = ws.cell(row=1, column=col, value=h)
        cell.fill = FILL_HEADER
        cell.font = FONT_WHITE
        cell.border = BORDER_THIN
        cell.alignment = Alignment(horizontal="center", vertical="center")

    row_cursor = 2

    # 仅 A 有
    for item in cmp["only_in_a"]:
        _write_diff_row(ws, row_cursor, item, "仅A有值", FILL_ONLY_A)
        row_cursor += 1

    # 仅 B 有
    for item in cmp["only_in_b"]:
        _write_diff_row(ws, row_cursor, item, "仅B有值", FILL_ONLY_B)
        row_cursor += 1

    # 值不同
    for item in cmp["diff_values"]:
        _write_diff_row(ws, row_cursor, item, "值不同", FILL_DIFF_REPORT)
        row_cursor += 1

    # 相同（可选）
    if include_equal:
        cells_a = {}
        for row in ws_a.iter_rows():
            for cell in row:
                if cell.value is not None:
                    cells_a[(cell.row, cell.column)] = cell

        cells_b = {}
        for row in ws_b.iter_rows():
            for cell in row:
                if cell.value is not None:
                    cells_b[(cell.row, cell.column)] = cell

        for k in sorted(cells_a.keys() & cells_b.keys()):
            val_a = cells_a[k].value
            val_b = cells_b[k].value
            same = _compare_values(val_a, val_b, compare_json)
            if same:
                ws.cell(row=row_cursor, column=1, value=k[0])
                ws.cell(row=row_cursor, column=2, value=get_column_letter(k[1]))
                ws.cell(row=row_cursor, column=3, value=str(val_a)[:200])
                ws.cell(row=row_cursor, column=4, value=str(val_b)[:200])
                ws.cell(row=row_cursor, column=5, value="相同")
                for col in range(1, 6):
                    ws.cell(row=row_cursor, column=col).fill = FILL_EQUAL
                    ws.cell(row=row_cursor, column=col).border = BORDER_THIN
                row_cursor += 1

    # 自动列宽
    for col in ws.columns:
        max_len = 0
        col_letter = get_column_letter(col[0].column)
        for cell in col:
            if cell.value:
                max_len = max(max_len, len(str(cell.value)))
        ws.column_dimensions[col_letter].width = min(max_len + 2, 50)


def _write_diff_row(ws, row: int, item: Dict, diff_type: str, fill):
    """写入一行差异记录（差异报告模式）"""
    ws.cell(row=row, column=1, value=item["row"])
    ws.cell(row=row, column=2, value=item["col_letter"])
    ws.cell(row=row, column=3, value=item.get("value_a", ""))
    ws.cell(row=row, column=4, value=item.get("value_b", ""))
    ws.cell(row=row, column=5, value=diff_type)
    for col in range(1, 6):
        ws.cell(row=row, column=col).fill = fill
        ws.cell(row=row, column=col).border = BORDER_THIN


def _write_sheet_only(wb_out, sheet_name: str, ws, source: str):
    """写入仅存在于一个文件中的 Sheet（完整复制）"""
    new_ws = wb_out.create_sheet(title=f"{sheet_name[:28]}(仅{source})")
    for row in ws.iter_rows():
        for cell in row:
            new_cell = new_ws.cell(row=cell.row, column=cell.column, value=cell.value)
            if cell.has_style:
                if cell.font:
                    new_cell.font = cell.font.copy()
                if cell.fill:
                    new_cell.fill = cell.fill.copy()
                if cell.border:
                    new_cell.border = cell.border.copy()
                if cell.alignment:
                    new_cell.alignment = cell.alignment.copy()
    for col_letter, dim in ws.column_dimensions.items():
        new_ws.column_dimensions[col_letter].width = dim.width
    for row_num, dim in ws.row_dimensions.items():
        new_ws.row_dimensions[row_num].height = dim.height


def print_summary(summary: Dict):
    """打印对比汇总到控制台"""
    print("\n" + "=" * 60)
    print("==== Excel 对比结果汇总 ====")
    print("=" * 60)
    print(f"文件A：{summary['file_a']}")
    print(f"文件B：{summary['file_b']}")
    print()

    if summary["sheets_only_in_a"]:
        print(f"[警告] 仅文件A有的 Sheet：{summary['sheets_only_in_a']}")
    if summary["sheets_only_in_b"]:
        print(f"[警告] 仅文件B有的 Sheet：{summary['sheets_only_in_b']}")

    print(f"\n已对比 Sheet：{summary['sheets_compared']}")
    print(f"差异总数：{summary['total_differences']}")
    print()

    for sheet_name, detail in summary["details"].items():
        print(f"── Sheet: {sheet_name} ──")
        print(f"  仅A有值：{len(detail['only_in_a'])} 个单元格")
        print(f"  仅B有值：{len(detail['only_in_b'])} 个单元格")
        print(f"  值不同：  {len(detail['diff_values'])} 个单元格")
        print(f"  相同：    {detail['equal_count']} 个单元格")

        for item in detail["only_in_a"][:5]:
            print(f"    [仅A] {item['col_letter']}{item['row']}: {item['value_a']}")
        for item in detail["only_in_b"][:5]:
            print(f"    [仅B] {item['col_letter']}{item['row']}: {item['value_b']}")
        for item in detail["diff_values"][:5]:
            print(f"    [不同] {item['col_letter']}{item['row']}: A={item['value_a']} | B={item['value_b']}")

    if "output_file" in summary:
        print(f"\n[报告] 详细报告已保存至：{summary['output_file']}")
    print("=" * 60)


# ─────────────────────────────────────────────
# 命令行入口
# ─────────────────────────────────────────────

def main():
    epilog_text = """\
使用场景：
  ──────────────────────────────────────────────────────────────
  场景1：基础对比（左右并排，默认模式）
  ──────────────────────────────────────────────────────────────
  # 自动识别关键列，结果输出到 compare-result-v<时间戳>.xlsx
  aiguibin /compare-excel A.xlsx B.xlsx

  # 指定输出文件名
  aiguibin /compare-excel A.xlsx B.xlsx -o diff.xlsx

  ──────────────────────────────────────────────────────────────
  场景2：指定关键列（手动指定，避免自动识别错误）
  ──────────────────────────────────────────────────────────────
  # 按列名指定
  aiguibin /compare-excel A.xlsx B.xlsx --key-col 工号

  # 按列字母指定
  aiguibin /compare-excel A.xlsx B.xlsx --key-col A

  ──────────────────────────────────────────────────────────────
  场景3：指定列对比（只对比关心的列，忽略其他列）
  ──────────────────────────────────────────────────────────────
  # 按列字母指定（只对比 A、B、C 三列）
  aiguibin /compare-excel A.xlsx B.xlsx --columns A B C

  # 按列名指定（只对比工号、姓名、部门）
  aiguibin /compare-excel A.xlsx B.xlsx --columns 工号 姓名 部门

  # 混合使用（关键列不在指定列中会自动加入）
  aiguibin /compare-excel A.xlsx B.xlsx --key-col 工号 --columns 姓名 部门

  ──────────────────────────────────────────────────────────────
  场景4：指定 Sheet 对比（多 Sheet 文件，只对比部分 Sheet）
  ──────────────────────────────────────────────────────────────
  # 只对比 Sheet1 和 Sheet2
  aiguibin /compare-excel A.xlsx B.xlsx -s Sheet1 Sheet2

  # 指定 Sheet + 指定列
  aiguibin /compare-excel A.xlsx B.xlsx -s Sheet1 --columns A B C

  ──────────────────────────────────────────────────────────────
  场景5：差异报告模式（清单格式，适合审查）
  ──────────────────────────────────────────────────────────────
  # 生成差异报告 Excel
  aiguibin /compare-excel A.xlsx B.xlsx --mode report -o report.xlsx

  # 报告中包含相同单元格（默认只列出差异）
  aiguibin /compare-excel A.xlsx B.xlsx --mode report --equal

  # 报告 + 指定列
  aiguibin /compare-excel A.xlsx B.xlsx --mode report --columns 工号 姓名

  ──────────────────────────────────────────────────────────────
  场景6：JSON 导出（差异汇总，适合程序处理）
  ──────────────────────────────────────────────────────────────
  # 导出差异汇总为 JSON
  aiguibin /compare-excel A.xlsx B.xlsx --mode report --json diff.json

  ──────────────────────────────────────────────────────────────
  场景7：公式对比（默认只对比值，加此参数对比公式）
  ──────────────────────────────────────────────────────────────
  aiguibin /compare-excel A.xlsx B.xlsx --formula

  ──────────────────────────────────────────────────────────────
  场景8：禁用 JSON 智能对比（默认开启，将 JSON 字符串解析后比较）
  ──────────────────────────────────────────────────────────────
  # 按原始字符串对比，不解析 JSON
  aiguibin /compare-excel A.xlsx B.xlsx --no-json-compare

  ──────────────────────────────────────────────────────────────
  场景9：组合使用（实际工作中常见组合）
  ──────────────────────────────────────────────────────────────
  # 指定 Sheet + 指定列 + 指定关键列 + 指定输出
  aiguibin /compare-excel A.xlsx B.xlsx -s Sheet1 --key-col 工号 --columns 姓名 部门 薪资 -o diff.xlsx

  # 报告模式 + JSON 导出 + 指定列
  aiguibin /compare-excel A.xlsx B.xlsx --mode report --columns 工号 薪资 --json diff.json

  # 全量对比 + 公式 + 包含相同
  aiguibin /compare-excel A.xlsx B.xlsx --mode report --formula --equal -o full-report.xlsx

输出说明：
  side-by-side 模式：
    - 以 A 为基准，右侧并排展示 B 的数据
    - 差异单元格：黄色背景 + 红色加粗字体
    - 保留 A 的原始样式和格式
    - 自动调整右侧列宽
    - B 独有的数据追加到最底部

  report 模式：
    - 生成清单格式报告：行号、列、A的值、B的值、差异类型
    - 差异类型：仅A有值、仅B有值、值不同
    - 可选导出 JSON 汇总
"""

    parser = argparse.ArgumentParser(
        description="Excel 通用对比工具（统一版） - 支持左右并排对比和差异报告两种模式",
        epilog=epilog_text,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("file_a", help="文件A路径（基准文件）")
    parser.add_argument("file_b", help="文件B路径（对比文件）")
    parser.add_argument("-o", "--output", help="输出文件路径")
    parser.add_argument("--mode", choices=["side-by-side", "report"], default="side-by-side",
                        help="对比模式：side-by-side（左右并排，默认）或 report（差异报告）")
    parser.add_argument("--key-col", help="手动指定关键列名或列字母（仅 side-by-side 模式）")
    parser.add_argument("-s", "--sheets", nargs="+", help="指定对比的 Sheet 名（默认全部）")
    parser.add_argument("--columns", nargs="+", help="指定对比的列（列名或列字母，如：A B C 或 工号 姓名）")
    parser.add_argument("--formula", action="store_true", help="对比公式（默认只对比值）")
    parser.add_argument("--equal", action="store_true", help="在报告中包含相同单元格（仅 report 模式）")
    parser.add_argument("--json", help="将汇总结果导出为 JSON 文件")
    parser.add_argument("--no-json-compare", action="store_true", help="禁用 JSON 智能对比")

    args = parser.parse_args()

    if not os.path.isfile(args.file_a):
        print(f"[错误] 文件不存在：{args.file_a}")
        sys.exit(1)
    if not os.path.isfile(args.file_b):
        print(f"[错误] 文件不存在：{args.file_b}")
        sys.exit(1)

    compare_json = not args.no_json_compare

    print(f"[开始] 对比：\n  A: {args.file_a}\n  B: {args.file_b}")
    print(f"[模式] {args.mode}")

    if args.mode == "side-by-side":
        # 左右并排对比模式
        output_path = compare_side_by_side(
            file_a=args.file_a,
            file_b=args.file_b,
            output_file=args.output,
            key_col_name=args.key_col,
            target_sheets=args.sheets,
            target_columns=args.columns,
            compare_json=compare_json,
        )
        print(f"\n[成功] 输出文件：{output_path}")

    else:
        # 差异报告模式
        summary = compare_files_report(
            file_a=args.file_a,
            file_b=args.file_b,
            output_file=args.output,
            sheets=args.sheets,
            compare_formula=args.formula,
            compare_json=compare_json,
            include_equal=args.equal,
            target_columns=args.columns,
        )

        print_summary(summary)

        # 导出 JSON
        if args.json:
            json_path = Path(args.json)
            json_path.parent.mkdir(parents=True, exist_ok=True)
            serializable = json.loads(
                json.dumps(summary, ensure_ascii=False, default=str)
            )
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(serializable, f, ensure_ascii=False, indent=2)
            print(f"[JSON] 汇总 JSON 已保存至：{json_path}")

        print("\n[完成] 对比完成！")


if __name__ == "__main__":
    main()