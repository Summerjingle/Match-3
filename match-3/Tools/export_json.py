#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 Match3Config 里的 xlsx 导成 Godot 用的 res://Config/*.json。

格式沿用 VampireConfig 的 7 行元数据（R4 变量名称 / R5 变量类型 / R6 变量空间 / R3 主键 …）。
demo 无服务端，空间全 c，不分 client/server，整表导成 {"<主键>": {记录}} 的字典，
方便 Godot 里按主键 O(1) 查找（JSON.parse_string 原生解析）。

用法：
  python export_json.py               # 默认 Match3Config/ → ../Config/
  python export_json.py <源目录> [输出目录]
"""
import json
import os
import re
import sys

import openpyxl

INT_RE = re.compile(r'^-?\d+$')
FLOAT_RE = re.compile(r'^-?\d+(\.\d+)?$')

TOOLS = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.normpath(os.path.join(TOOLS, '..', 'Match3Config'))
DST = os.path.normpath(os.path.join(TOOLS, '..', 'Config'))


def norm_cell(v):
    """单元格 → 文本：None→''，整数化 float→int 文本，其余原样"""
    if v is None:
        return ''
    if isinstance(v, float) and v == int(v):
        return str(int(v))
    return str(v)


def to_value(text, typ):
    """按 R5 类型转成 JSON 原生类型（Godot parse 后直接可用）；空/未知 → 字符串"""
    text = (text or '').strip()
    t = (typ or '').strip().lower()
    if text == '':
        return ''
    if t in ('int', 'integer'):
        return int(text)
    if t in ('float', 'double', 'number', 'num'):
        return float(text)
    if t in ('bool', 'boolean'):
        return text.lower() in ('1', 'true', 'yes')
    return text


def parse_table(ws):
    """7 行元数据格式 → (headers, types, data)；非该格式返回 None"""
    rows = [tuple(r) for r in ws.iter_rows(values_only=True)]
    if len(rows) < 5 or rows[3][0] != '变量名称' or rows[4][0] != '变量类型':
        return None

    r3, r4, r5, r6 = rows[2], rows[3], rows[4], rows[5]
    r8 = rows[7] if len(rows) > 7 else ()
    a8 = str(r8[0]).strip() if r8 and r8[0] is not None else ''

    # 规则行 / 数据起始行：新格式 R8=外部引用，旧格式 R8=是否导出
    if a8 == '外部引用':
        rule_row, data_start = (rows[8] if len(rows) > 8 else ()), 10
    elif a8 == '是否导出':
        rule_row, data_start = r8, 9
    else:
        rule_row, data_start = (), 8
    is_rule = bool(rule_row) and str(rule_row[0]).strip() == '是否导出'

    n = len(r4) - 1
    headers = [str(r4[c]) if r4[c] is not None else '' for c in range(1, len(r4))]
    types = [str(r5[c]).strip() if c < len(r5) and r5[c] is not None else '' for c in range(1, len(r4))]
    spaces = [str(r6[c]).strip().lower() if c < len(r6) and r6[c] is not None else '' for c in range(1, len(r4))]

    # isExport 控制列（行级导出开关）
    is_ix = next((i for i, h in enumerate(headers) if h.lower() == 'isexport'), None)
    # 主键：R3 标 Y 优先，否则回退 id/mark 列
    key_col = None
    for c in range(1, len(r4)):
        if c - 1 == is_ix:
            continue
        if r3[c] is not None and str(r3[c]).strip().upper() == 'Y':
            key_col = c - 1
            break
    if key_col is None:
        for i, h in enumerate(headers):
            if h.lower() in ('id', 'mark'):
                key_col = i
                break

    # 列级过滤：规则行标 '不导出' 剔除；主键强制保留；isExport 恒剔除
    keep = []
    for i in range(len(headers)):
        if is_rule:
            flag = str(rule_row[i + 1]).strip() if i + 1 < len(rule_row) and rule_row[i + 1] is not None else ''
            keep.append(flag != '不导出' or i == key_col)
        else:
            keep.append(True)
    if is_ix is not None:
        keep[is_ix] = False

    new_idx = {}
    ni = 0
    for i, k in enumerate(keep):
        if k:
            new_idx[i] = ni
            ni += 1
    headers = [h for i, h in enumerate(headers) if keep[i]]
    types = [t for i, t in enumerate(types) if keep[i]]
    key_col = new_idx.get(key_col) if key_col is not None else None

    # 数据行：行级 isExport=='导出' 才导出；列级只留 keep
    data = {}
    for r in rows[data_start - 1:]:
        vals = [norm_cell(v) for v in r[1:]]
        if is_ix is not None and (is_ix >= len(vals) or vals[is_ix].strip() != '导出'):
            continue
        vals = [v for i, v in enumerate(vals) if i < len(keep) and keep[i]]
        if all(v == '' for v in vals):
            continue
        vals = (vals[:len(headers)] + [''] * len(headers))[:len(headers)]
        if key_col is None or key_col >= len(headers):
            continue
        rec = {}
        for h, t, v in zip(headers, types, vals):
            if h == '':
                continue
            # 类型不符直接抛错终止，不允许带病导出
            try:
                rec[h] = to_value(v, t)
            except ValueError:
                raise ValueError(f'列[{h}] 声明类型 {t} 但值 {v!r} 不匹配') from None
        data[str(vals[key_col])] = rec
    return headers, types, data


def main():
    src = SRC if len(sys.argv) < 2 else sys.argv[1]
    dst = DST if len(sys.argv) < 3 else sys.argv[2]
    os.makedirs(dst, exist_ok=True)

    # 清掉上次导出的旧 json，防改名残留
    for f in os.listdir(dst):
        if f.endswith('.json'):
            os.remove(os.path.join(dst, f))

    written = 0
    for fn in sorted(os.listdir(src)):
        if not fn.lower().endswith('.xlsx'):
            continue
        wb = openpyxl.load_workbook(os.path.join(src, fn), data_only=True)
        info = parse_table(wb.worksheets[0])
        if info is None:
            print(f'  [SKIP] {fn}: 不是 7 行元数据格式')
            continue
        headers, types, data = info
        table = os.path.splitext(fn)[0]
        out = os.path.join(dst, table + '.json')
        with open(out, 'w', encoding='utf-8', newline='') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        written += 1
        print(f'  [OK] {fn} → {out}（{len(data)} 行）')

    print(f'完成：{written} 张表 → {dst}')


if __name__ == '__main__':
    main()
