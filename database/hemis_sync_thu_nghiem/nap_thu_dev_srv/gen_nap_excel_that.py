# -*- coding: utf-8 -*-
"""Sinh nap_excel_that.sql: nap THO cac file Excel cua Bo (Export_*.xlsx) vao database hemis_sync,
schema rieng nap_thu - KHONG dung toi schema hemis_sync cua app va KHONG dung toi hemis_noi_bo.

Muc dich: thu xem du lieu that co nap duoc khong, va Excel co cot nao thua/thieu so voi database.
Moi dong Excel thanh 1 dong nap_thu.excel_dong, du_lieu = jsonb {tieu_de_cot: gia_tri}.
Bo qua sheet HuongDan va Danh muc.

Chay (tren may co file Excel):
  python -I gen_nap_excel_that.py --pylib <thu_muc_openpyxl> --out <file.sql> <a.xlsx> [<b.xlsx> ...]

FILE KET QUA CHUA DU LIEU CA NHAN THAT: chi de o scratchpad / dev-srv, KHONG dua vao git, xoa sau khi thu.
Chay tren dev-srv (MOT giao dich, chay lai duoc - xoa dong cu cua cung ten file truoc khi nap):
  docker exec -i hemis-postgres psql -U postgres -d hemis_sync -v ON_ERROR_STOP=1 -1 -f - < nap_excel_that.sql
"""
import argparse
import datetime as dt
import json
import os
import sys

BO_QUA = ("huongdan", "danhmuc")
LO = 500  # so dong moi lenh INSERT


def khoa_sheet(ten):
    return "".join(ch for ch in ten.lower() if ch.isalnum()).replace("ụ", "u")


def sql_text(s):
    return "'" + s.replace("\x00", "").replace("'", "''") + "'"


def gia_tri(v):
    if v is None:
        return None
    if isinstance(v, dt.datetime):
        return v.date().isoformat() if v.time() == dt.time(0) else v.isoformat()
    if isinstance(v, (dt.date, dt.time)):
        return v.isoformat()
    if isinstance(v, str):
        v = v.strip()
        return v or None
    return v


def tim_tieu_de(rows):
    """Dong dau tien (trong 15 dong dau) co >= 3 o, tat ca la chu."""
    for i, r in enumerate(rows[:15]):
        vals = [v for v in r if v not in (None, "")]
        if len(vals) >= 3 and all(isinstance(v, str) for v in vals):
            return i
    return None


def ten_cot(r):
    cot, da_co = [], {}
    for j, v in enumerate(r, 1):
        ten = " ".join(str(v).split()) if v not in (None, "") else f"cot_{j}"
        if ten in da_co:
            da_co[ten] += 1
            ten = f"{ten}_{da_co[ten]}"
        else:
            da_co[ten] = 1
        cot.append(ten)
    while cot and cot[-1].startswith("cot_"):
        cot.pop()
    return cot


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pylib")
    ap.add_argument("--out", required=True)
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    if a.pylib:
        sys.path.insert(0, a.pylib)
    import openpyxl

    out = [
        "-- nap_excel_that.sql - SINH TU DONG boi gen_nap_excel_that.py. CHUA DU LIEU THAT: KHONG dua vao git.",
        "SET client_encoding = 'UTF8';",
        "DO $g$ BEGIN IF current_database() <> 'hemis_sync' THEN"
        " RAISE EXCEPTION 'Chi chay tren database hemis_sync (dang o %)', current_database(); END IF; END $g$;",
        "CREATE SCHEMA IF NOT EXISTS nap_thu;",
        "CREATE TABLE IF NOT EXISTS nap_thu.excel_sheet (tep text, sheet text, dong_tieu_de int NOT NULL,"
        " cot text[] NOT NULL, so_dong int NOT NULL, nap_luc timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (tep, sheet));",
        "CREATE TABLE IF NOT EXISTS nap_thu.excel_dong (tep text, sheet text, dong_so int,"
        " du_lieu jsonb NOT NULL, PRIMARY KEY (tep, sheet, dong_so));",
    ]
    tong = 0
    for path in a.files:
        tep = os.path.basename(path)
        out.append(f"DELETE FROM nap_thu.excel_dong WHERE tep = {sql_text(tep)};")
        out.append(f"DELETE FROM nap_thu.excel_sheet WHERE tep = {sql_text(tep)};")
        wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
        for ws in wb.worksheets:
            if khoa_sheet(ws.title).startswith(BO_QUA):
                continue
            rows = [list(r) for r in ws.iter_rows(values_only=True)]
            h = tim_tieu_de(rows)
            if h is None:
                print(f"  BO QUA {tep} [{ws.title}]: khong thay dong tieu de", file=sys.stderr)
                continue
            cot = ten_cot(rows[h])
            dong = []
            for i, r in enumerate(rows[h + 1:], h + 2):
                d = {c: gia_tri(r[j]) if j < len(r) else None for j, c in enumerate(cot)}
                if all(v is None for v in d.values()):
                    continue
                dong.append((i, json.dumps(d, ensure_ascii=False, default=str)))
            arr = "ARRAY[" + ",".join(sql_text(c) for c in cot) + "]::text[]"
            out.append(f"INSERT INTO nap_thu.excel_sheet (tep, sheet, dong_tieu_de, cot, so_dong) VALUES"
                       f" ({sql_text(tep)}, {sql_text(ws.title)}, {h + 1}, {arr}, {len(dong)});")
            for k in range(0, len(dong), LO):
                vals = ",\n".join(f"({sql_text(tep)},{sql_text(ws.title)},{i},{sql_text(j)}::jsonb)"
                                  for i, j in dong[k:k + LO])
                out.append(f"INSERT INTO nap_thu.excel_dong (tep, sheet, dong_so, du_lieu) VALUES\n{vals};")
            print(f"  {tep} [{ws.title}]: {len(cot)} cot, {len(dong)} dong", file=sys.stderr)
            tong += len(dong)
        wb.close()
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print(f"Tong {tong} dong -> {a.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
