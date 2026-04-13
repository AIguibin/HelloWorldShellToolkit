#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成提示管理系统的Excel文件
包含使用说明工作表和提示管理工作表
"""

import pandas as pd
import openpyxl
from openpyxl.styles import PatternFill, Font, Alignment
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from datetime import datetime

# 配置参数
OUTPUT_FILE = "prompt_management_system.xlsx"

# 创建Excel工作簿
excel_writer = pd.ExcelWriter(OUTPUT_FILE, engine='openpyxl')

# --------------------------
# 1. 使用说明工作表
# --------------------------
instructions_data = {
    'A': [
        '提示管理系统 - 使用指南',
        '',
        '工作表说明:',
        '1. 使用说明: 本工作表包含数据录入指南和列定义说明',
        '2. 提示管理: 主数据表，用于记录所有技术提示和业务提示',
        '',
        '列定义说明:',
        '',
        '列名', 'Prompt ID', 'Prompt Type', 'Prompt Content', 'Application Scenario', 'Creator', 'Creation Date', 'Last Modified Date', 'Status', 'Remarks',
        '数据类型', '文本', '下拉列表', '长文本', '文本', '文本', '日期', '日期', '下拉列表', '文本',
        '必填', '是', '是', '是', '是', '是', '是', '否', '是', '否',
        '说明', '唯一标识符 (P-YYYYMMDD-XXX)', 'technical/business', '详细提示内容', '使用场景', '创建者信息', '创建日期', '最后修改日期', 'draft/reviewed/approved/retired', '备注信息',
        '示例', 'P-20260116-001', 'technical', '优化数据库查询性能', '数据库性能优化项目', '张三/数据库管理员', '2026-01-16', '2026-01-20', 'approved', '已验证有效',
        '',
        '数据录入指南:',
        '1. 所有必填字段必须填写',
        '2. Prompt ID必须唯一',
        '3. 日期格式使用YYYY-MM-DD',
        '4. 状态变更时更新Last Modified Date',
        '',
        '注意事项:',
        '请不要删除或修改表头',
        '定期备份Excel文件',
        '重要数据建议在系统中留有备份'
    ]
}

# 创建DataFrame
instructions_df = pd.DataFrame(dict([(k, pd.Series(v)) for k, v in instructions_data.items()]))

# 写入Excel
instructions_df.to_excel(excel_writer, sheet_name='使用说明', index=False, header=False)

# --------------------------
# 2. 提示管理工作表
# --------------------------
# 表头定义
headers = ['Prompt ID', 'Prompt Type', 'Prompt Content', 'Application Scenario', 'Creator', 'Creation Date', 'Last Modified Date', 'Status', 'Remarks']

# 示例数据
sample_data = [
    ['P-20260116-001', 'technical', '优化数据库查询性能，减少响应时间，包括索引优化、查询重写和缓存策略', '数据库性能优化项目', '张三/数据库管理员', '2026-01-16', '2026-01-20', 'approved', '已在实际项目中验证有效'],
    ['P-20260116-002', 'business', '制定客户满意度调查问卷，包含关键指标和反馈收集机制', '客户关系管理系统改进', '李四/产品经理', '2026-01-16', '2026-01-18', 'reviewed', '等待业务部门确认'],
    ['P-20260117-001', 'technical', '实现API接口的限流和熔断机制，确保系统稳定性', '微服务架构优化', '王五/后端开发', '2026-01-17', '2026-01-19', 'approved', '已在生产环境部署'],
    ['P-20260117-002', 'business', '设计用户注册流程优化方案，提升转化率', '用户增长项目', '赵六/用户体验设计师', '2026-01-17', '2026-01-17', 'draft', '初步方案，需要进一步细化'],
    ['P-20260118-001', 'technical', '配置CI/CD流水线，实现自动化测试和部署', 'DevOps流程改进', '钱七/运维工程师', '2026-01-18', '2026-01-20', 'approved', '已集成到开发流程中']
]

# 创建DataFrame
prompt_df = pd.DataFrame(sample_data, columns=headers)

# 写入Excel
prompt_df.to_excel(excel_writer, sheet_name='提示管理', index=False)

# --------------------------
# 3. 格式化Excel文件
# --------------------------
# 获取工作簿对象
excel_writer.close()

# 使用openpyxl重新打开文件进行格式设置
workbook = openpyxl.load_workbook(OUTPUT_FILE)

# --------------------------
# 3.1 格式化"使用说明"工作表
# --------------------------
instruction_sheet = workbook['使用说明']

# 设置标题格式
title_cell = instruction_sheet['A1']
title_cell.font = Font(bold=True, size=14)
title_cell.fill = PatternFill(start_color='E0F2FE', end_color='E0F2FE', fill_type='solid')
title_cell.alignment = Alignment(horizontal='left', vertical='center')

# 设置说明内容格式
for row in range(4, 29):
    cell = instruction_sheet[f'A{row}']
    cell.font = Font(size=11)

# 设置表格标题格式
for col in range(1, 10):
    cell = instruction_sheet[f'{get_column_letter(col)}8']
    cell.font = Font(bold=True)
    cell.fill = PatternFill(start_color='E0F2FE', end_color='E0F2FE', fill_type='solid')
    cell.alignment = Alignment(horizontal='center', vertical='center')

# 设置列宽
column_widths = {
    'A': 40,
    'B': 15,
    'C': 12,
    'D': 25,
    'E': 20,
    'F': 15,
    'G': 15,
    'H': 12,
    'I': 15,
    'J': 25
}

for col, width in column_widths.items():
    instruction_sheet.column_dimensions[col].width = width

# --------------------------
# 3.2 格式化"提示管理"工作表
# --------------------------
prompt_sheet = workbook['提示管理']

# 设置表头格式
title_fill = PatternFill(start_color='E0F2FE', end_color='E0F2FE', fill_type='solid')
title_font = Font(bold=True)

for col in range(1, len(headers) + 1):
    cell = prompt_sheet[f'{get_column_letter(col)}1']
    cell.font = title_font
    cell.fill = title_fill
    cell.alignment = Alignment(horizontal='center', vertical='center')

# 设置列宽
prompt_column_widths = {
    'A': 15,   # Prompt ID
    'B': 12,   # Prompt Type
    'C': 50,   # Prompt Content
    'D': 25,   # Application Scenario
    'E': 20,   # Creator
    'F': 12,   # Creation Date
    'G': 15,   # Last Modified Date
    'H': 12,   # Status
    'I': 30    # Remarks
}

for col, width in prompt_column_widths.items():
    prompt_sheet.column_dimensions[col].width = width

# 设置数据格式
for row in range(2, prompt_df.shape[0] + 2):
    # 设置日期格式
    for col in ['F', 'G']:
        cell = prompt_sheet[f'{col}{row}']
        cell.number_format = 'yyyy-mm-dd'
        
    # 设置文本列自动换行
    for col in ['C', 'D', 'E', 'I']:
        cell = prompt_sheet[f'{col}{row}']
        cell.alignment = Alignment(wrap_text=True)

# --------------------------
# 3.3 设置数据验证
# --------------------------

# Prompt Type列数据验证 (B列)
type_dv = DataValidation(
    type="list",
    formula1='"technical,business"',
    allow_blank=False,
    showErrorMessage=True,
    errorTitle="输入错误",
    error="请选择有效的提示类型: technical 或 business"
)
type_dv.add('B2:B1048576')
prompt_sheet.add_data_validation(type_dv)

# Status列数据验证 (H列)
status_dv = DataValidation(
    type="list",
    formula1='"draft,reviewed,approved,retired"',
    allow_blank=False,
    showErrorMessage=True,
    errorTitle="输入错误",
    error="请选择有效的状态: draft, reviewed, approved, retired"
)
status_dv.add('H2:H1048576')
prompt_sheet.add_data_validation(status_dv)

# --------------------------
# 3.4 设置条件格式
# --------------------------
from openpyxl.formatting.rule import CellIsRule

# 定义颜色
colors = {
    'draft': 'FFFF00',
    'reviewed': '00BFFF',
    'approved': '90EE90',
    'retired': 'D3D3D3'
}

# 为Status列添加条件格式
for status, color in colors.items():
    rule = CellIsRule(
        operator='equal',
        formula=[f'"{status}"'],
        stopIfTrue=True,
        fill=PatternFill(start_color=color, end_color=color, fill_type='solid')
    )
    prompt_sheet.conditional_formatting.add('H2:H1048576', rule)

# --------------------------
# 4. 保存文件
# --------------------------
workbook.save(OUTPUT_FILE)
workbook.close()

print(f"Excel文件已生成: {OUTPUT_FILE}")
print(f"文件位置: {OUTPUT_FILE}")
print("\n文件包含:")
print("1. 使用说明工作表 - 数据录入指南和列定义")
print("2. 提示管理工作表 - 包含5条示例记录")
print("\n功能特点:")
print("- 专业的表格格式化")
print("- 数据验证功能 (Prompt Type, Status)")
print("- 条件格式 (按状态自动着色)")
print("- 合理的列宽设置")
print("- 清晰的使用说明")