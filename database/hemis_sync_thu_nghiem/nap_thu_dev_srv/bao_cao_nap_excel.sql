-- bao_cao_nap_excel.sql - doc ket qua nap_excel_that.sql (schema nap_thu trong database hemis_sync).
-- CHI DOC, khong in gia tri du lieu (chi so dong, ten cot). Chay:
--   docker exec -i hemis-postgres psql -U postgres -d hemis_sync -f - < bao_cao_nap_excel.sql
BEGIN READ ONLY;

\echo '== 1. Moi sheet: so cot, so dong theo Excel va so dong da vao DB (khop = t la nap du)'
SELECT s.tep, s.sheet, cardinality(s.cot) AS so_cot, s.so_dong AS dong_excel,
       count(d.dong_so) AS dong_trong_db, s.so_dong = count(d.dong_so) AS khop
FROM nap_thu.excel_sheet s
LEFT JOIN nap_thu.excel_dong d ON d.tep = s.tep AND d.sheet = s.sheet
GROUP BY s.tep, s.sheet, s.cot, s.so_dong
ORDER BY s.tep, s.sheet;

\echo '== 2. Cot co tieu de nhung KHONG dong nao co gia tri'
SELECT s.tep, s.sheet, string_agg(c.ten, ' | ' ORDER BY c.vt) AS cot_trong
FROM nap_thu.excel_sheet s
CROSS JOIN LATERAL unnest(s.cot) WITH ORDINALITY AS c(ten, vt)
WHERE NOT EXISTS (SELECT 1 FROM nap_thu.excel_dong d
                  WHERE d.tep = s.tep AND d.sheet = s.sheet AND d.du_lieu ->> c.ten IS NOT NULL)
GROUP BY s.tep, s.sheet
ORDER BY s.tep, s.sheet;

\echo '== 3. Tieu de cot tung sheet (de doi chieu voi dac ta HEMIS)'
SELECT s.tep, s.sheet, array_to_string(s.cot, ' | ') AS cot
FROM nap_thu.excel_sheet s
ORDER BY s.tep, s.sheet;

\echo '== 4. Tong'
SELECT count(DISTINCT tep) AS so_tep, count(*) AS so_sheet, sum(so_dong) AS tong_dong
FROM nap_thu.excel_sheet;

ROLLBACK;
