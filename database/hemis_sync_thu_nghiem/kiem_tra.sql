-- kiem_tra.sql - CHI DOC. Kiem tra database hemis_sync sau khi nap.
--   docker exec -i hemis-postgres psql -U hemis -d hemis_sync -v ON_ERROR_STOP=1 -f - < kiem_tra.sql
-- Moi dong in "OK" hoac "SAI"; neu co dong SAI thi cuoi cung RAISE EXCEPTION (psql thoat khac 0).
-- Khong co flyway_schema_history: goi nay KHONG chay Flyway (V1-V3 ap bang psql), nen hemis_sync co 14 bang
-- (database `hemis` that tren proxywaf co 15 = 14 + flyway_schema_history).
-- Ky vong so dong lay tu seed/EXPECTED.json (validation_rule 324, catalog_hemis 35).
\set ON_ERROR_STOP on

DO $kt$
DECLARE
    r record;
    sai int := 0;
BEGIN
    FOR r IN
        SELECT * FROM (VALUES
            -- (ten kiem tra, gia tri thuc te, ky vong)
            ('database hien tai',
                current_database()::text, 'hemis_sync'),
            ('hemis_sync: so bang',
                (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='hemis_sync' AND c.relkind IN ('r','p'))::text, '14'),
            ('hemis_sync: ten 14 bang',
                (SELECT string_agg(c.relname, ',' ORDER BY c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='hemis_sync' AND c.relkind IN ('r','p')),
                'api_log,catalog_diff,catalog_hemis,catalog_map,co_so_giao_duc,data_group,data_group_status,entity_map,sign_job,sync_batch,sync_error,sync_record,sync_watermark,validation_rule'),
            ('hemis_sync: khong co flyway_schema_history',
                (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='hemis_sync' AND c.relname='flyway_schema_history')::text, '0'),
            ('hemis_src: so view',
                (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='hemis_src' AND c.relkind='v')::text, '1'),
            ('hemis_src: ten view',
                (SELECT string_agg(c.relname, ',') FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='hemis_src' AND c.relkind='v'), 'v_co_so_giao_duc'),
            ('hemis_src: so bang (phai 0)',
                (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                  WHERE n.nspname='hemis_src' AND c.relkind IN ('r','p'))::text, '0'),
            ('hemis_sync: so ham (kiem_tra_ket_noi_noi_bo, kiem_tra_khoang_trong)',
                (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                  WHERE n.nspname='hemis_sync')::text, '2'),
            ('co_so_giao_duc: so dong',        (SELECT count(*) FROM hemis_sync.co_so_giao_duc)::text, '1'),
            ('catalog_hemis: so dong',         (SELECT count(*) FROM hemis_sync.catalog_hemis)::text, '35'),
            ('catalog_hemis: so danh muc',     (SELECT count(DISTINCT dm_name) FROM hemis_sync.catalog_hemis)::text, '14'),
            ('validation_rule: so dong',       (SELECT count(*) FROM hemis_sync.validation_rule)::text, '324'),
            ('validation_rule: so mang (entity)', (SELECT count(DISTINCT entity) FROM hemis_sync.validation_rule)::text, '23'),
            ('validation_rule: ph chi CANBO',  (SELECT string_agg(DISTINCT ph, ',') FROM hemis_sync.validation_rule), 'CANBO'),
            ('validation_rule: _CANBO_HOSO co 71 truong', (SELECT count(*) FROM hemis_sync.validation_rule WHERE entity='_CANBO_HOSO')::text, '71'),
            ('validation_rule: condition_expr deu NULL', (SELECT count(*) FROM hemis_sync.validation_rule WHERE condition_expr IS NOT NULL)::text, '0'),
            ('validation_rule: note deu bat dau GIA LAP', (SELECT count(*) FROM hemis_sync.validation_rule WHERE note NOT LIKE 'GIA LAP - tu YAML D01%')::text, '0'),
            ('validation_rule: max_length chi voi string', (SELECT count(*) FROM hemis_sync.validation_rule WHERE max_length IS NOT NULL AND data_type IS DISTINCT FROM 'string')::text, '0'),
            ('data_group (V2 tu nap)',         (SELECT count(*) FROM hemis_sync.data_group)::text, '14'),
            ('data_group_status (V2 tu nap)',  (SELECT count(*) FROM hemis_sync.data_group_status)::text, '14'),
            ('bang nhat ky/entity_map/sync_* phai rong',
                ((SELECT count(*) FROM hemis_sync.entity_map) + (SELECT count(*) FROM hemis_sync.sync_batch)
                 + (SELECT count(*) FROM hemis_sync.sync_record) + (SELECT count(*) FROM hemis_sync.sync_error)
                 + (SELECT count(*) FROM hemis_sync.api_log) + (SELECT count(*) FROM hemis_sync.sign_job)
                 + (SELECT count(*) FROM hemis_sync.catalog_map) + (SELECT count(*) FROM hemis_sync.catalog_diff)
                 + (SELECT count(*) FROM hemis_sync.sync_watermark))::text, '0'),
            ('co_so_giao_duc: du lieu gia (example.test, GIA-, 0000)',
                (SELECT count(*) FROM hemis_sync.co_so_giao_duc
                  WHERE website='https://example.test' AND email LIKE '%@example.test'
                    AND so_dien_thoai LIKE '0000%' AND ma_don_vi LIKE 'GIA-%'
                    AND tinh_thanh_new LIKE 'GIA-%' AND xa_phuong_new LIKE 'GIA-%')::text, '1'),
            ('kiem_tra_ket_noi_noi_bo()',
                (SELECT trang_thai FROM hemis_sync.kiem_tra_ket_noi_noi_bo()), 'CHUA_THIET_LAP'),
            ('hemis_src.v_co_so_giao_duc: so dong', (SELECT count(*) FROM hemis_src.v_co_so_giao_duc)::text, '1'),
            ('v_co_so_giao_duc: cot IN HOA dung spec ("ID", "MA_DON_VI", "Created")',
                (SELECT count(*) FROM information_schema.columns
                  WHERE table_schema='hemis_src' AND table_name='v_co_so_giao_duc'
                    AND column_name IN ('ID','MA_DON_VI','Created'))::text, '3'),
            ('v_co_so_giao_duc: so cot', (SELECT count(*) FROM information_schema.columns
                  WHERE table_schema='hemis_src' AND table_name='v_co_so_giao_duc')::text, '34')
        ) AS t(ten, thuc_te, ky_vong)
    LOOP
        IF r.thuc_te IS NOT DISTINCT FROM r.ky_vong THEN
            RAISE NOTICE 'OK   % = %', r.ten, r.thuc_te;
        ELSE
            RAISE NOTICE 'SAI  %: thuc te [%], ky vong [%]', r.ten, r.thuc_te, r.ky_vong;
            sai := sai + 1;
        END IF;
    END LOOP;
    IF sai > 0 THEN
        RAISE EXCEPTION 'kiem_tra.sql: % kiem tra SAI', sai;
    END IF;
    RAISE NOTICE 'kiem_tra.sql: TAT CA DAT';
END
$kt$;

-- Xem tay (chi doc)
SELECT * FROM hemis_sync.kiem_tra_ket_noi_noi_bo();
SELECT * FROM hemis_src.v_co_so_giao_duc;
SELECT dm_name, count(*) AS so_dong FROM hemis_sync.catalog_hemis GROUP BY dm_name ORDER BY dm_name;
SELECT entity, count(*) AS so_truong, count(*) FILTER (WHERE required) AS bat_buoc
  FROM hemis_sync.validation_rule GROUP BY entity ORDER BY entity;
