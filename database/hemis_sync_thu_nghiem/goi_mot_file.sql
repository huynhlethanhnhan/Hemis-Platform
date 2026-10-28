-- goi_mot_file.sql - database hemis_sync: schema hemis_sync + hemis_src (V1, V2, V3 cua thay) + DU LIEU GIA.
-- SINH TU DONG boi scripts/gen_goi.py. KHONG sua tay.
-- Chay (MOT giao dich; loi o dau thi khong de lai gi):
--   docker exec -i hemis-postgres psql -U hemis -d hemis_sync -v ON_ERROR_STOP=1 -1 -f - < goi_mot_file.sql
-- Tu choi (RAISE EXCEPTION) neu: khong phai database hemis_sync, hoac hemis_sync/hemis_src da co bang/view.

SET client_encoding = 'UTF8';

DO $guard$
BEGIN
    IF current_database() <> 'hemis_sync' THEN
        RAISE EXCEPTION 'TU CHOI: database hien tai la "%", goi nay chi chay duoc tren hemis_sync', current_database();
    END IF;
    IF EXISTS (SELECT 1
                 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname IN ('hemis_sync', 'hemis_src')
                  AND c.relkind IN ('r', 'p', 'v', 'm', 'f')) THEN
        RAISE EXCEPTION 'TU CHOI: hemis_sync/hemis_src da co bang hoac view. Khong nap lai de tranh nhan doi. Muon nap lai: xoa rieng database hemis_sync (xem README) roi tao lai.';
    END IF;
END
$guard$;

CREATE SCHEMA IF NOT EXISTS hemis_sync;
SET search_path = hemis_sync;

-- =====================================================================
-- BAT DAU V1__hemis_sync.sql (ban sao nguyen van cua thay, commit 22b99be)
-- =====================================================================
-- =====================================================================
-- V1 - Schema hemis_sync: vung lam viec cua Cong tich hop HEMIS
-- Khong dung chung voi schema nghiep vu (dwh) de co the trien khai doc lap.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. entity_map: anh xa khoa noi bo -> dinh danh GUID gui cho HEMIS
--    GUID sinh MOT LAN va giu co dinh, de HEMIS cap nhat dung ban ghi
--    qua nhieu dot dong bo.
-- ---------------------------------------------------------------------
CREATE TABLE entity_map (
    local_table   VARCHAR(100) NOT NULL,
    local_id      VARCHAR(100) NOT NULL,
    hemis_id      UUID         NOT NULL DEFAULT gen_random_uuid(),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_entity_map PRIMARY KEY (local_table, local_id),
    CONSTRAINT uq_entity_map_hemis_id UNIQUE (hemis_id)
);
COMMENT ON TABLE entity_map IS 'Anh xa khoa noi bo sang GUID gui cho HEMIS; GUID khong duoc thay doi';

-- ---------------------------------------------------------------------
-- 2. catalog_hemis: ban sao hon 175 danh muc dung chung cua HEMIS
-- ---------------------------------------------------------------------
CREATE TABLE catalog_hemis (
    id            BIGSERIAL    PRIMARY KEY,
    dm_name       VARCHAR(100) NOT NULL,   -- vi du: DM_DAN_TOC
    hemis_id      VARCHAR(36),             -- truong Id (Guid) cua ban ghi danh muc
    code          VARCHAR(100),            -- truong Code
    ma            VARCHAR(100),            -- truong MA_<TEN_DANH_MUC>
    ten           VARCHAR(500),            -- truong TEN_<TEN_DANH_MUC>
    is_public     BOOLEAN,
    is_deleted    BOOLEAN      NOT NULL DEFAULT false,
    modified      TIMESTAMPTZ,
    fetched_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    raw_json      JSONB,                   -- giu nguyen ban ghi goc de doi chieu
    CONSTRAINT uq_catalog_hemis UNIQUE (dm_name, ma)
);
CREATE INDEX ix_catalog_hemis_dm ON catalog_hemis (dm_name);
COMMENT ON TABLE catalog_hemis IS 'Ban sao danh muc dung chung tai ve tu API getDanhMucHemis';

-- ---------------------------------------------------------------------
-- 3. catalog_map: anh xa ma danh muc noi bo -> ma HEMIS
-- ---------------------------------------------------------------------
CREATE TABLE catalog_map (
    id            BIGSERIAL    PRIMARY KEY,
    dm_name       VARCHAR(100) NOT NULL,
    local_code    VARCHAR(100) NOT NULL,
    hemis_code    VARCHAR(100),            -- NULL = chua anh xa duoc (loi muc chan)
    note          VARCHAR(500),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_catalog_map UNIQUE (dm_name, local_code)
);
COMMENT ON COLUMN catalog_map.hemis_code IS 'NULL nghia la chua anh xa duoc - phai xu ly truoc khi gui';

-- ---------------------------------------------------------------------
-- 4. sync_batch: moi dot dong bo mot phan he
-- ---------------------------------------------------------------------
CREATE TABLE sync_batch (
    id              BIGSERIAL    PRIMARY KEY,
    ph              VARCHAR(50)  NOT NULL,  -- COSOGIAODUC, CANBO, HOCVIEN...
    api             VARCHAR(10)  NOT NULL,  -- db1, db3, db7...
    iks             UUID         NOT NULL,  -- ma phien ky so (k1 + k2)
    id_key          UUID         NOT NULL,  -- ma phien dong bo (tra cuu nhat ky)
    don_vi_id       UUID         NOT NULL,
    record_count    INT          NOT NULL DEFAULT 0,
    status          VARCHAR(30)  NOT NULL,  -- xem enum BatchStatus
    xml_path        VARCHAR(500),
    signed_xml_path VARCHAR(500),
    json_path       VARCHAR(500),
    payload_sha256  VARCHAR(64),
    signer_subject  VARCHAR(500),           -- X509SubjectName cua nguoi ky
    signed_at       TIMESTAMPTZ,
    sent_at         TIMESTAMPTZ,
    message         TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_sync_batch_iks UNIQUE (iks)
);
CREATE INDEX ix_sync_batch_status ON sync_batch (status, created_at DESC);
CREATE INDEX ix_sync_batch_ph ON sync_batch (ph, created_at DESC);

-- ---------------------------------------------------------------------
-- 5. sync_record: ban ghi thuoc tung dot
-- ---------------------------------------------------------------------
CREATE TABLE sync_record (
    id            BIGSERIAL    PRIMARY KEY,
    batch_id      BIGINT       NOT NULL REFERENCES sync_batch (id) ON DELETE CASCADE,
    entity        VARCHAR(100) NOT NULL,   -- vi du: _CO_SO_GIAO_DUC
    hemis_id      UUID,
    local_id      VARCHAR(100),
    valid         BOOLEAN      NOT NULL DEFAULT true,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_sync_record_batch ON sync_record (batch_id);

-- ---------------------------------------------------------------------
-- 6. sync_error: loi theo tung ban ghi / tung truong
-- ---------------------------------------------------------------------
CREATE TABLE sync_error (
    id            BIGSERIAL    PRIMARY KEY,
    batch_id      BIGINT       REFERENCES sync_batch (id) ON DELETE CASCADE,
    entity        VARCHAR(100),
    local_id      VARCHAR(100),
    field         VARCHAR(100),
    rule_code     VARCHAR(50),             -- REQUIRED, MAX_LENGTH, CATALOG, CONDITIONAL...
    severity      VARCHAR(20)  NOT NULL DEFAULT 'BLOCK',  -- BLOCK | WARN
    message       TEXT         NOT NULL,
    owner_unit    VARCHAR(100),            -- don vi chiu trach nhiem xu ly
    resolved      BOOLEAN      NOT NULL DEFAULT false,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_sync_error_batch ON sync_error (batch_id, resolved);

-- ---------------------------------------------------------------------
-- 7. api_log: nhat ky tung lan goi API cua Bo
--    KHONG ghi so CCCD, ho ten day du vao bang nay.
-- ---------------------------------------------------------------------
CREATE TABLE api_log (
    id            BIGSERIAL    PRIMARY KEY,
    batch_id      BIGINT       REFERENCES sync_batch (id) ON DELETE SET NULL,
    direction     VARCHAR(10)  NOT NULL DEFAULT 'OUT',
    method        VARCHAR(10)  NOT NULL,
    url           VARCHAR(1000) NOT NULL,
    http_status   INT,
    success       BOOLEAN,
    request_bytes BIGINT,
    duration_ms   BIGINT,
    response_body TEXT,                    -- cat ngan, da che du lieu ca nhan
    error         TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_api_log_created ON api_log (created_at DESC);
CREATE INDEX ix_api_log_batch ON api_log (batch_id);

-- ---------------------------------------------------------------------
-- 8. sign_job: hang doi ky so cho tac nhan tren tram ky so
-- ---------------------------------------------------------------------
CREATE TABLE sign_job (
    id            BIGSERIAL    PRIMARY KEY,
    batch_id      BIGINT       NOT NULL REFERENCES sync_batch (id) ON DELETE CASCADE,
    status        VARCHAR(20)  NOT NULL,   -- PENDING | LEASED | SIGNED | FAILED
    xml_path      VARCHAR(500) NOT NULL,
    signed_path   VARCHAR(500),
    leased_by     VARCHAR(100),
    leased_at     TIMESTAMPTZ,
    attempts      INT          NOT NULL DEFAULT 0,
    error         TEXT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_sign_job_status ON sign_job (status, created_at);

-- ---------------------------------------------------------------------
-- 9. validation_rule: quy tac kiem tra sinh tu dac ta cua Bo
-- ---------------------------------------------------------------------
CREATE TABLE validation_rule (
    id            BIGSERIAL    PRIMARY KEY,
    ph            VARCHAR(50)  NOT NULL,
    entity        VARCHAR(100) NOT NULL,
    field         VARCHAR(100) NOT NULL,
    required      BOOLEAN      NOT NULL DEFAULT false,
    max_length    INT,
    data_type     VARCHAR(30),             -- string | int | double | date | bool | guid
    catalog_name  VARCHAR(100),            -- neu tham chieu danh muc HEMIS
    condition_expr VARCHAR(500),           -- vi du: bat buoc khi TRANG_THAI_ID = '04'
    note          VARCHAR(500),
    CONSTRAINT uq_validation_rule UNIQUE (ph, entity, field)
);

-- =====================================================================
-- BAT DAU V2__bo_sung_hemis_sync.sql (ban sao nguyen van cua thay, commit 22b99be)
-- =====================================================================
-- =====================================================================
-- V2 - Bo sung schema hemis_sync de lay du lieu tu kho du lieu cu (DWH)
--
-- Bon nhom bo sung:
--   1. co_so_giao_duc        - bang con THIEU trong DWH (xem docs/10)
--   2. entity_map doi khoa   - khoa theo NGHIEP VU, khong theo ID tu tang
--   3. sync_watermark        - moc trich xuat gia tang
--   4. data_group / status   - theo doi Bang 1C cua Thong tu 83/2026
--
-- Migration nay CHI dung cham schema hemis_sync, khong dung vao public (DWH),
-- nen chay an toan tren ca may phat trien (khong co DWH) lan may chu.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. co_so_giao_duc
--
-- VAN DE: kho du lieu hien tai KHONG CO bang nao luu thong tin chung cua
-- Truong. Module co_so_giao_duc chi co 13 bang con (BanGiamHieu, VanBanTuChu,
-- ThongTinKiemDinh_CSGD...) ma thieu ban ghi goc. Trong khi do phan he
-- COSOGIAODUC (API db1) la phan he thi diem cua Giai doan 1.
--
-- Dat tam o day de khong chan tien do. NO KY THUAT: khi Nhom DWH bo sung
-- bang public.CoSoGiaoDuc thi chuyen sang doc tu do va bo bang nay
-- (xem docs/10_THIET_KE_CSDL.md muc 4).
-- ---------------------------------------------------------------------
CREATE TABLE co_so_giao_duc (
    id                              SMALLINT     PRIMARY KEY DEFAULT 1,
    hemis_id                        UUID         NOT NULL,   -- = DON_VI_ID do Bo cap
    ma_don_vi                       VARCHAR(50)  NOT NULL,
    ten_don_vi                      VARCHAR(250) NOT NULL,
    ten_tieng_anh                   VARCHAR(250),
    ten_don_vi_cha                  VARCHAR(250),

    website                         VARCHAR(250) NOT NULL,
    email                           VARCHAR(100) NOT NULL,
    so_dien_thoai                   VARCHAR(50)  NOT NULL,
    fax                             VARCHAR(50),
    dia_chi                         VARCHAR(250) NOT NULL,

    -- Dia gioi cu
    tinh_thanh_id                   VARCHAR(36),
    quan_huyen_id                   VARCHAR(36),
    xa_phuong_id                    VARCHAR(36),
    -- Dia gioi moi theo QD 19/2025/QD-TTg - BAT BUOC
    tinh_thanh_new                  VARCHAR(36)  NOT NULL,
    xa_phuong_new                   VARCHAR(36)  NOT NULL,

    -- Quyet dinh thanh lap, cap phep
    so_qd_thanh_lap                 VARCHAR(50)  NOT NULL,
    ngay_qd_thanh_lap               DATE         NOT NULL,
    so_qd_chuyen_doi_loai_hinh      VARCHAR(50),
    ngay_qd_chuyen_doi              DATE,
    so_qd_cap_phep_hoat_dong        VARCHAR(50),
    ngay_duoc_cap_phep_hoat_dong    DATE         NOT NULL,

    -- Phan loai - dung MA DANH MUC CUA HEMIS
    loai_hinh_id                    VARCHAR(36)  NOT NULL,   -- DM_LOAI_HINH_TRUONG
    hinh_thuc_thanh_lap             VARCHAR(250) NOT NULL,   -- DM_HINH_THUC_THANH_LAP
    loai_co_so                      VARCHAR(50)  NOT NULL,   -- DM_PHAN_LOAI_CO_SO

    is_loi_nhuan                    BOOLEAN,
    tu_chu                          BOOLEAN,
    truong_dac_thu                  BOOLEAN      NOT NULL DEFAULT false,
    so_gv_gdtc                      INT,

    qd_ban_hanh_quy_che             VARCHAR(100),
    ngay_qd_ban_hanh_quy_che        DATE,

    -- Dinh danh
    ma_dinh_danh_dien_tu            VARCHAR(50),              -- QD 20
    ma_dinh_danh_nd69               VARCHAR(36)  NOT NULL,    -- Nghi dinh 69

    nguon_du_lieu                   VARCHAR(100) NOT NULL DEFAULT 'Nhap tay - Phong TCHC',
    created_at                      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at                      TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT ck_co_so_giao_duc_mot_dong CHECK (id = 1)
);
COMMENT ON TABLE co_so_giao_duc IS
  'Thong tin chung cua Truong - BANG TAM, do DWH chua co. Chi co dung 01 dong.';

-- ---------------------------------------------------------------------
-- 2. entity_map - doi khoa sang KHOA NGHIEP VU
--
-- LY DO: DWH trien khai bang reset_all.sql (xoa va tao lai toan bo). Khoa
-- chinh la SERIAL nen sau moi lan nap lai, ID cua cung mot nguoi se khac.
-- Neu gan GUID theo ID thi GUID se doi -> HEMIS coi la ban ghi moi -> nhan
-- ban du lieu tren he thong cua Bo, khong go lai duoc.
--
-- Vi vay khoa phai la thu KHONG DOI theo nghiep vu: so CCCD, ma chuong
-- trinh dao tao, ma nganh...
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS entity_map;

CREATE TABLE entity_map (
    entity_type   VARCHAR(50)  NOT NULL,   -- CAN_BO, NGUOI_HOC, CHUONG_TRINH_DT...
    business_key  VARCHAR(200) NOT NULL,   -- SoCCCD, MaChuongTrinhDaoTao...
    hemis_id      UUID         NOT NULL DEFAULT gen_random_uuid(),
    local_table   VARCHAR(100),            -- de tham chieu nguoc, khong phai khoa
    local_id      VARCHAR(100),
    first_sent_at TIMESTAMPTZ,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_entity_map PRIMARY KEY (entity_type, business_key),
    CONSTRAINT uq_entity_map_hemis_id UNIQUE (hemis_id)
);
COMMENT ON COLUMN entity_map.business_key IS
  'Khoa nghiep vu KHONG DOI. TUYET DOI khong dung khoa SERIAL cua DWH.';
COMMENT ON COLUMN entity_map.first_sent_at IS
  'Lan dau gui len HEMIS. Da co gia tri = GUID nay HEMIS da biet, khong duoc doi.';

-- ---------------------------------------------------------------------
-- 3. catalog_map - bo sung chien luoc anh xa
--
-- Kho du lieu da duoc mo hinh hoa theo chuan HEMIS nen PHAN LON ma danh muc
-- da trung (vi du DM_GioiTinh.Ma = '01' <-> HEMIS GIOI_TINH_ID = '01').
-- Do do khong khai bao anh xa cho tung ma, chi khai bao NGOAI LE.
-- ---------------------------------------------------------------------
ALTER TABLE catalog_map
    ADD COLUMN strategy VARCHAR(20) NOT NULL DEFAULT 'IDENTITY',
    ADD COLUMN dwh_table VARCHAR(100);

COMMENT ON COLUMN catalog_map.strategy IS
  'IDENTITY = ma noi bo trung ma HEMIS (mac dinh); MAPPED = co anh xa rieng; MISSING = chua co ma HEMIS tuong ung (loi muc chan)';

-- Bang doi chieu danh muc DWH <-> HEMIS, sinh tu dong de phat hien lech
CREATE TABLE catalog_diff (
    id            BIGSERIAL    PRIMARY KEY,
    dm_name       VARCHAR(100) NOT NULL,   -- ten danh muc HEMIS
    dwh_table     VARCHAR(100),            -- ten bang danh muc trong DWH
    dwh_code      VARCHAR(100),
    dwh_name      VARCHAR(500),
    hemis_code    VARCHAR(100),
    hemis_name    VARCHAR(500),
    diff_type     VARCHAR(30)  NOT NULL,   -- CHI_CO_DWH | CHI_CO_HEMIS | LECH_TEN | TRUNG_KHOP
    checked_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_catalog_diff_type ON catalog_diff (diff_type, dm_name);
COMMENT ON TABLE catalog_diff IS
  'Ket qua doi chieu danh muc cua DWH voi danh muc tai ve tu HEMIS. Chay lai sau moi lan tai danh muc.';

-- ---------------------------------------------------------------------
-- 4. sync_watermark - moc trich xuat gia tang
--
-- LUU Y: cot UpdatedAt trong DWH cho phep NULL (ban ghi chua tung sua).
-- Moi truy van delta phai dung COALESCE(UpdatedAt, CreatedAt), neu khong
-- se bo sot toan bo ban ghi chua tung duoc cap nhat.
-- ---------------------------------------------------------------------
CREATE TABLE sync_watermark (
    ph                  VARCHAR(50)  PRIMARY KEY,
    last_extracted_at   TIMESTAMPTZ,
    last_success_at     TIMESTAMPTZ,
    last_batch_id       BIGINT REFERENCES sync_batch (id) ON DELETE SET NULL,
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT now()
);
COMMENT ON COLUMN sync_watermark.last_success_at IS
  'Moc de lay delta lan sau: WHERE COALESCE(UpdatedAt, CreatedAt) > last_success_at';

-- ---------------------------------------------------------------------
-- 5. data_group va data_group_status - phuc vu Bang 1C (Thong tu 83/2026)
-- ---------------------------------------------------------------------
CREATE TABLE data_group (
    code            VARCHAR(20)  PRIMARY KEY,   -- B1A, B2A, B3D...
    ten_nhom        VARCHAR(250) NOT NULL,
    bat_buoc        BOOLEAN      NOT NULL DEFAULT true,
    ph              VARCHAR(50),                -- phan he API tuong ung, NULL = chua co
    don_vi_chu_tri  VARCHAR(150),
    he_thong_nguon  VARCHAR(150),               -- Dieu 8 Thong tu 83/2026
    thu_tu          INT          NOT NULL
);
COMMENT ON TABLE data_group IS
  '14 nhom du lieu theo Bang 1C, Phu luc V Thong tu 83/2026/TT-BGDDT';
COMMENT ON COLUMN data_group.ph IS
  'NULL nghia la nhom du lieu chua co phan he API tuong ung - thu thap theo bieu mau';

CREATE TABLE data_group_status (
    id                      BIGSERIAL    PRIMARY KEY,
    group_code              VARCHAR(20)  NOT NULL REFERENCES data_group (code),
    ky_danh_gia             INT          NOT NULL,       -- nam du lieu, vi du 2026
    ngay_phai_cap_nhat      DATE,
    ngay_cap_nhat_thuc_te   TIMESTAMPTZ,
    dung_han                BOOLEAN,
    so_truong_bat_buoc      INT,
    so_truong_dat           INT,
    day_du_pct              NUMERIC(5,2),
    tin_cay_pct             NUMERIC(5,2),
    dat_dieu_kien           BOOLEAN,
    ghi_chu                 TEXT,
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_data_group_status UNIQUE (group_code, ky_danh_gia)
);
COMMENT ON TABLE data_group_status IS
  'Sinh truc tiep Bang 1C. Chi ngay_phai_cap_nhat va bat_buoc nhap tay, con lai tinh tu nhat ky.';

-- Nap 14 nhom du lieu theo dung thu tu Bang 1C.
-- Cot ph va don_vi_chu_tri la DU KIEN, cho huong dan chinh thuc cua Bo
-- (xem RANG BUOC-09 trong docs/08_SRS.md).
INSERT INTO data_group (code, ten_nhom, bat_buoc, ph, don_vi_chu_tri, he_thong_nguon, thu_tu) VALUES
 ('B1A', 'Noi dung quan tri noi bo bang van ban',               true, 'COSOGIAODUC', 'Phong To chuc - Hanh chinh',      'Ho so van ban',            1),
 ('B1B', 'Chi so hoat dong chinh',                              true, NULL,          'Phong Ke hoach - Tai chinh',     'Ke hoach nam',             2),
 ('B2A', 'Doi ngu giang vien',                                  true, 'CANBO',       'Phong To chuc - Hanh chinh',     'He thong quan ly nhan su', 3),
 ('B3A', 'Dat dai, khuon vien, phan hieu',                      true, 'COSOVATCHAT', 'Phong Quan tri co so vat chat',  'Ho so dat dai',            4),
 ('B3B', 'San xay dung va cho lam viec',                        true, 'COSOVATCHAT', 'Phong Quan tri co so vat chat',  'Ho so cong trinh',         5),
 ('B3C', 'Hoc lieu, giao trinh, tai lieu hoc tap',              true, 'COSOVATCHAT', 'Thu vien',                       'Phan mem thu vien',        6),
 ('B3D', 'Ha tang cong nghe thong tin va he thong hoc tap so',  true, NULL,          'Phong Cong nghe thong tin',      'LMS; so quan ly thiet bi', 7),
 ('B4A', 'Thu, chi hoat dong',                                  true, 'TAISAN',      'Phong Ke hoach - Tai chinh',     'He thong quan ly tai chinh',8),
 ('B5A', 'Tuyen sinh va quy mo dao tao',                        true, 'TUYENSINH',   'Phong Dao tao',                  'He thong quan ly dao tao', 9),
 ('B5B', 'Theo doi khoa hoc, tot nghiep',                       true, 'HOCVIEN',     'Phong Dao tao',                  'He thong quan ly dao tao',10),
 ('B5C', 'Khao sat viec lam va hai long nguoi hoc',             true, 'HOCVIEN',     'Phong Cong tac chinh tri - HSSV','Ket qua khao sat',        11),
 ('B6A', 'San pham khoa hoc, cong nghe va doi moi sang tao',    true, 'NCKH',        'Phong Quan ly khoa hoc',         'He thong quan ly KHCN',   12),
 ('B6B', 'Thu tu khoa hoc, cong nghe va chuyen giao',           true, 'TAISAN',      'Phong Quan ly khoa hoc',         'He thong quan ly tai chinh',13),
 ('B6C', 'Giang vien tham gia hoat dong khoa hoc cong nghe',    true, 'CANBO',       'Phong Quan ly khoa hoc',         'He thong quan ly KHCN',   14);

-- Khoi tao ky danh gia 2026 voi han noi bo som hon han cua Bo 15 ngay
INSERT INTO data_group_status (group_code, ky_danh_gia, ngay_phai_cap_nhat)
SELECT code, 2026,
       CASE WHEN code IN ('B4A', 'B6B') THEN DATE '2027-03-15'   -- tai chinh
            ELSE DATE '2026-12-15' END
FROM data_group;

-- =====================================================================
-- BAT DAU V3__hemis_src_views.sql (ban sao nguyen van cua thay, commit 22b99be)
-- =====================================================================
-- =====================================================================
-- V3 - Schema hemis_src: LOP HOP DONG doc du lieu tu HEMIS NOI BO
--
-- KIEN TRUC: HAI DATABASE RIENG
--
--   Database "hemis_noi_bo"            Database cua hemis-platform
--   ─────────────────────────          ───────────────────────────
--   public.*   (253 bang)   ◄── fdw ── hemis_noi_bo.*  (bang ngoai, chi doc)
--   don vi trong truong nhap                  │
--   lieu va lam sach o day                    ▼
--                                      hemis_src.*   (view - HOP DONG)
--                                             │
--                                             ▼
--                                      hemis_sync.*  (vung lam viec)
--
-- Ket noi fdw duoc thiet lap MOT LAN bang db/setup/01_ket_noi_hemis_noi_bo.sql,
-- khong chay qua Flyway (can superuser va chua mat khau).
--
-- NGUYEN TAC: ma nguon Java KHONG BAO GIO truy van hemis_noi_bo.* truc tiep.
-- Moi truy cap deu qua view trong hemis_src. Doi ben kia chi can sua view.
--
-- Migration nay tu phat hien da thiet lap fdw hay chua. Chua co thi bo qua
-- phan doc tu HEMIS noi bo, khong bao loi - de may phat trien van chay duoc.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS hemis_src;
COMMENT ON SCHEMA hemis_src IS
  'Lop hop dong doc du lieu tu HEMIS noi bo. Chi chua VIEW, khong chua bang.';

-- ---------------------------------------------------------------------
-- 1. CO SO GIAO DUC (phan he COSOGIAODUC - API db1)
--
-- Doc tu hemis_sync (CUNG database) vi HEMIS noi bo chua co bang thong tin
-- chung cua Truong - xem V2 muc 1. Khi ben kia bo sung, sua view nay tro
-- sang hemis_noi_bo.cosogiaoduc.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW hemis_src.v_co_so_giao_duc AS
SELECT
    hemis_id                        AS "ID",
    ma_don_vi                       AS "MA_DON_VI",
    ten_don_vi                      AS "TEN_DON_VI",
    ten_tieng_anh                   AS "TEN_TIENG_ANH",
    ten_don_vi_cha                  AS "TEN_DON_VI_CHA",
    website                         AS "WEBSITE",
    email                           AS "EMAIL",
    so_dien_thoai                   AS "SO_DIEN_THOAI",
    fax                             AS "FAX",
    dia_chi                         AS "DIA_CHI",
    tinh_thanh_id                   AS "TINH_THANH_ID",
    quan_huyen_id                   AS "QUAN_HUYEN_ID",
    xa_phuong_id                    AS "XA_PHUONG_ID",
    tinh_thanh_new                  AS "TINH_THANH_NEW",
    xa_phuong_new                   AS "XA_PHUONG_NEW",
    so_qd_thanh_lap                 AS "SO_QD_THANH_LAP",
    ngay_qd_thanh_lap               AS "NGAY_QD_THANH_LAP",
    so_qd_chuyen_doi_loai_hinh      AS "SO_QD_CHUYEN_DOI_LOAI_HINH",
    ngay_qd_chuyen_doi              AS "NGAY_QD_CHUYEN_DOI",
    so_qd_cap_phep_hoat_dong        AS "SO_QD_CAP_PHEP_HOAT_DONG",
    ngay_duoc_cap_phep_hoat_dong    AS "NGAY_DUOC_CAP_PHEP_HOAT_DONG",
    loai_hinh_id                    AS "LOAI_HINH_ID",
    hinh_thuc_thanh_lap             AS "HINH_THUC_THANH_LAP",
    loai_co_so                      AS "LOAI_CO_SO",
    is_loi_nhuan                    AS "IS_LOI_NHUAN",
    tu_chu                          AS "TU_CHU",
    truong_dac_thu                  AS "TRUONG_DAC_THU",
    so_gv_gdtc                      AS "SO_GV_GDTC",
    qd_ban_hanh_quy_che             AS "QD_BAN_HANH_QUY_CHE",
    ngay_qd_ban_hanh_quy_che        AS "NGAY_QD_BAN_HANH_QUY_CHE",
    ma_dinh_danh_dien_tu            AS "MA_DINH_DANH_DIEN_TU",
    ma_dinh_danh_nd69               AS "MA_DINH_DANH_ND69",
    created_at::date                AS "Created",
    updated_at::date                AS "Modified"
FROM hemis_sync.co_so_giao_duc;

COMMENT ON VIEW hemis_src.v_co_so_giao_duc IS
  'Phan he COSOGIAODUC (db1). Tam doc tu hemis_sync vi HEMIS noi bo chua co bang thong tin chung Truong.';

-- ---------------------------------------------------------------------
-- 2, 3. View doc tu HEMIS noi bo qua bang ngoai
--
-- LUU Y VE TEN COT: ben HEMIS noi bo cac bang duoc tao khong dat ten trong
-- ngoac kep (CREATE TABLE CanBo (SoCCCD ...)), nen PostgreSQL ha thanh chu
-- thuong: canbo, socccd. Viet cb.SoCCCD o day van dung vi cung duoc ha
-- thanh cb.socccd - giu kieu viet hoa cho de doi chieu voi tai lieu.
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('hemis_noi_bo.canbo') IS NULL THEN
        RAISE NOTICE E'Chua thiet lap ket noi toi HEMIS noi bo - BO QUA cac view doc tu ben do.\n'
                     '  Day la trang thai binh thuong tren may phat trien.\n'
                     '  Tren may chu: chay db/setup/01_ket_noi_hemis_noi_bo.sql roi chay lai V3.';
        RETURN;
    END IF;

    -- -----------------------------------------------------------------
    -- 2. DOI NGU (phan he CANBO - API db3)
    -- Khoa nghiep vu: SoCCCD. KHONG dung canbo.id (SERIAL) - xem docs/10 muc 3.
    -- -----------------------------------------------------------------
    EXECUTE $v$
    CREATE OR REPLACE VIEW hemis_src.v_can_bo AS
    SELECT
        cb.SoCCCD                           AS business_key,
        cb.SoCCCD                           AS "CCCD",
        cb.Ho                               AS "HO_DEM",
        cb.Ten                              AS "TEN_GOI",
        cb.NgaySinh                         AS "NGAY_SINH",
        cb.MaCanBo                          AS "MA_CAN_BO",
        cb.Email                            AS "EMAIL",
        cb.DienThoai                        AS "DIEN_THOAI",
        cb.MaGioiTinh::text                 AS "GIOI_TINH_ID",
        cb.MaDanToc::text                   AS "DAN_TOC_ID",
        cb.MaQuocTich::text                 AS "QUOC_TICH_ID",
        cb.MaTonGiao::text                  AS "TON_GIAO_ID",
        cb.MaTinhCuTru::text                AS "HK_TINH_ID",
        cb.MaXaPhuongCuTru::text            AS "HK_XA_ID",
        NULL::text                          AS "HK_TINH_NEW",   -- TODO SV1-04: dia gioi moi
        NULL::text                          AS "HK_XA_NEW",     -- TODO SV1-04: dia gioi moi
        cb.MaTrangThaiCanBo::text           AS "TRANG_THAI_CAN_BO_ID",
        cb.MaChucDanhNgheNghiep::text       AS "CHUC_DANH_NGHE_NGHIEP",
        cb.MaChucDanhGiangVien::text        AS "CHUC_DANH_GIANG_VIEN",
        cb.MaChucDanhNghienCuuKH::text      AS "CHUC_DANH_NGHIEN_CUU_KHOA_HOC",
        cb.MaNgach::text                    AS "NGACH_ID",
        cb.MaKhungNangLucNN::text           AS "KHUNG_NLUC_NNGU_ID",
        cb.MaTrinhDoLLCT::text              AS "TRINH_DO_LLCT_ID",
        cb.MaTrinhDoQLNN::text              AS "TRINH_DO_QLNN_ID",
        cb.MaTrinhDoTinHoc::text            AS "TRINH_DO_TIN_HOC_ID",
        cb.BacSiChuyenKhoaI                 AS "BAC_SI_CK_DUOC_SI_CK_I",
        cb.BacSiChuyenKhoaII                AS "BAC_SI_CK_DUOC_SI_CK_II",
        cb.ChungChiSuPhamGV                 AS "IS_CHUNG_CHI_SP_GIANG_VIEN",
        cb.CreatedAt::date                  AS "Created",
        COALESCE(cb.UpdatedAt, cb.CreatedAt)::date AS "Modified",
        COALESCE(cb.UpdatedAt, cb.CreatedAt)       AS delta_ts,
        cb.ID                               AS nguon_id
    FROM hemis_noi_bo.canbo cb
    $v$;

    COMMENT ON VIEW hemis_src.v_can_bo IS
      'Phan he CANBO (db3). business_key = SoCCCD. nguon_id chi de truy nguoc, khong dung lam dinh danh gui Bo.';

    -- -----------------------------------------------------------------
    -- 3. NGUOI HOC (phan he HOCVIEN - API db7)
    -- -----------------------------------------------------------------
    EXECUTE $v$
    CREATE OR REPLACE VIEW hemis_src.v_nguoi_hoc AS
    SELECT
        nh.SoCCCD                           AS business_key,
        nh.SoCCCD                           AS "CMTND",
        nh.HoVaTen                          AS "HO_TEN",
        nh.NgaySinh                         AS "NGAY_SINH",
        nh.Email                            AS "EMAIL",
        nh.DienThoai                        AS "DIEN_THOAI",
        nh.SoSoBaoHiem                      AS "SO_BAO_HIEM",
        nh.MaGioiTinh::text                 AS "GIOI_TINH_ID",
        nh.MaDanToc::text                   AS "DAN_TOC_ID",
        nh.MaQuocTich::text                 AS "QUOC_TICH_ID",
        nh.MaTonGiao::text                  AS "TON_GIAO_ID",
        nh.MaLoaiKhuyetTat::text            AS "KHUYET_TAT_ID",
        nh.MaTinhThuongTru::text            AS "TINH_THANH_ID",
        nh.MaXaPhuongThuongTru::text        AS "XA_PHUONG_ID",
        NULL::text                          AS "TINH_THANH_NEW",  -- TODO SV1-04
        NULL::text                          AS "XA_PHUONG_NEW",   -- TODO SV1-04
        nh.NoiSinh                          AS "NOI_SINH",
        nh.QueQuan                          AS "QUE_QUAN",
        nh.NgayVaoDoan                      AS "NGAY_VAO_DOAN",
        nh.NgayVaoDang                      AS "NGAY_VAO_DANG",
        nh.NgayVaoDangChinhThuc             AS "NGAY_VAO_DANG_CHINH_THUC",
        nh.CreatedAt::date                  AS "Created",
        COALESCE(nh.UpdatedAt, nh.CreatedAt)::date AS "Modified",
        COALESCE(nh.UpdatedAt, nh.CreatedAt)       AS delta_ts,
        nh.ID                               AS nguon_id
    FROM hemis_noi_bo.nguoihoc nh
    $v$;

    COMMENT ON VIEW hemis_src.v_nguoi_hoc IS
      'Phan he HOCVIEN (db7). business_key = SoCCCD.';

    RAISE NOTICE 'Da tao cac view hemis_src doc tu HEMIS noi bo.';
END $$;

-- ---------------------------------------------------------------------
-- 4. Kiem tra suc khoe ket noi toi HEMIS noi bo
--
-- Goi tu diem kiem tra suc khoe cua ung dung. Tra ve trang thai thay vi
-- nem loi, de HEMIS noi bo tam dung khong lam sap cong tich hop.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION hemis_sync.kiem_tra_ket_noi_noi_bo()
RETURNS TABLE (trang_thai TEXT, chi_tiet TEXT)
LANGUAGE plpgsql AS $$
DECLARE
    n BIGINT;
BEGIN
    IF to_regclass('hemis_noi_bo.canbo') IS NULL THEN
        RETURN QUERY SELECT 'CHUA_THIET_LAP'::TEXT,
                            'Chua chay db/setup/01_ket_noi_hemis_noi_bo.sql'::TEXT;
        RETURN;
    END IF;
    BEGIN
        EXECUTE 'SELECT count(*) FROM hemis_noi_bo.canbo' INTO n;
        RETURN QUERY SELECT 'OK'::TEXT, format('Doc duoc %s dong tu bang can bo', n);
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT 'LOI'::TEXT, SQLERRM::TEXT;
    END;
END $$;

COMMENT ON FUNCTION hemis_sync.kiem_tra_ket_noi_noi_bo() IS
  'Kiem tra ket noi fdw toi HEMIS noi bo. Dung cho diem kiem tra suc khoe.';

-- ---------------------------------------------------------------------
-- 5. Khung ham bao cao khoang trong du lieu (FR-DQ-03)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION hemis_sync.kiem_tra_khoang_trong(p_ph VARCHAR)
RETURNS TABLE (
    truong          VARCHAR,
    so_ban_ghi      BIGINT,
    so_thieu        BIGINT,
    ty_le_dat_pct   NUMERIC
)
LANGUAGE plpgsql AS $$
BEGIN
    -- Khung ham. Hoan thien o nhiem vu SV2-03: doc danh sach truong bat buoc
    -- tu bang validation_rule, sinh truy van dem gia tri rong tren view
    -- hemis_src tuong ung, tra ve ty le dat cho tung truong.
    RAISE NOTICE 'Chua trien khai cho phan he %. Xem nhiem vu SV2-03.', p_ph;
    RETURN;
END $$;

COMMENT ON FUNCTION hemis_sync.kiem_tra_khoang_trong(VARCHAR) IS
  'Dem truong bat buoc con thieu theo phan he. Phuc vu bao cao khoang trong du lieu (FR-DQ-03).';

-- =====================================================================
-- BAT DAU seed/01_du_lieu_gia.sql (du lieu GIA)
-- =====================================================================
-- seed/01_du_lieu_gia.sql - DU LIEU GIA cho database hemis_sync.
-- SINH TU DONG boi scripts/gen_seed.py (khong sua tay; seed co dinh, chay lai ra y het).
-- KHONG co du lieu ca nhan: ten truong gia, website/email thuoc example.test, dien thoai 0000..., ma GIA-...
-- Chi chen vao hemis_sync.{co_so_giao_duc, catalog_hemis, validation_rule}. Khong BEGIN/COMMIT (nguoi goi lo giao dich).

-- (a) co_so_giao_duc: 1 dong GIA LAP
INSERT INTO hemis_sync.co_so_giao_duc (id, hemis_id, ma_don_vi, ten_don_vi, ten_tieng_anh, ten_don_vi_cha, website, email, so_dien_thoai, fax, dia_chi, tinh_thanh_id, quan_huyen_id, xa_phuong_id, tinh_thanh_new, xa_phuong_new, so_qd_thanh_lap, ngay_qd_thanh_lap, so_qd_chuyen_doi_loai_hinh, ngay_qd_chuyen_doi, so_qd_cap_phep_hoat_dong, ngay_duoc_cap_phep_hoat_dong, loai_hinh_id, hinh_thuc_thanh_lap, loai_co_so, is_loi_nhuan, tu_chu, truong_dac_thu, so_gv_gdtc, qd_ban_hanh_quy_che, ngay_qd_ban_hanh_quy_che, ma_dinh_danh_dien_tu, ma_dinh_danh_nd69, nguon_du_lieu, created_at, updated_at) VALUES
  (1, 'ffffffff-0000-4000-8000-00000000a001', 'GIA-0001', 'TRUONG DAI HOC GIA LAP', 'FAKE UNIVERSITY (TEST ONLY)', 'BO GIA LAP', 'https://example.test', 'lienhe@example.test', '0000000000', '0000000001', 'So 0 Duong Gia Lap, Phuong GIA-X01, Tinh GIA-T01', 'GIA-T01', 'GIA-H01', 'GIA-X01', 'GIA-T01', 'GIA-X01', 'GIA-QD-0001', '2000-01-01', NULL, NULL, 'GIA-CP-0001', '2000-02-01', '01', 'GIA-HT01', 'GIA-LCS01', false, false, false, 0, NULL, NULL, 'GIA-DDDT-0001', 'GIA-ND69-0001', 'GIA LAP - hermis-db/hemis_sync', '2026-10-21 00:00:00+00', '2026-10-21 00:00:00+00');

-- (b) catalog_hemis: 35 dong tu hermis-infra/hemis-mock/__files/danh-muc.json (14 danh muc)
INSERT INTO hemis_sync.catalog_hemis (dm_name, hemis_id, code, ma, ten, is_public, is_deleted, modified, fetched_at, raw_json) VALUES
  ('DM_BAC_LUONG', 'a0000001-0000-4000-8000-000000000001', NULL, '1', 'Bậc 1', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000001-0000-4000-8000-000000000001","IsDeleted":false,"MA_BAC_LUONG":"1","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_BAC_LUONG":"Bậc 1"}'::jsonb),
  ('DM_BAC_LUONG', 'a0000001-0000-4000-8000-000000000002', NULL, '2', 'Bậc 2', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000001-0000-4000-8000-000000000002","IsDeleted":false,"MA_BAC_LUONG":"2","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_BAC_LUONG":"Bậc 2"}'::jsonb),
  ('DM_BAC_LUONG', 'a0000001-0000-4000-8000-000000000003', NULL, '3', 'Bậc 3', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000001-0000-4000-8000-000000000003","IsDeleted":false,"MA_BAC_LUONG":"3","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_BAC_LUONG":"Bậc 3"}'::jsonb),
  ('DM_CHUC_DANH', 'a0000002-0000-4000-8000-000000000001', NULL, '01', 'Giảng viên', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000002-0000-4000-8000-000000000001","IsDeleted":false,"MA_CHUC_DANH":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_CHUC_DANH":"Giảng viên"}'::jsonb),
  ('DM_CHUC_DANH', 'a0000002-0000-4000-8000-000000000002', NULL, '02', 'Giảng viên chính', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000002-0000-4000-8000-000000000002","IsDeleted":false,"MA_CHUC_DANH":"02","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_CHUC_DANH":"Giảng viên chính"}'::jsonb),
  ('DM_CHUC_DANH', 'a0000002-0000-4000-8000-000000000003', NULL, '03', 'Giảng viên cao cấp', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000002-0000-4000-8000-000000000003","IsDeleted":false,"MA_CHUC_DANH":"03","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_CHUC_DANH":"Giảng viên cao cấp"}'::jsonb),
  ('DM_CHUC_VU', 'a0000003-0000-4000-8000-000000000001', NULL, '01', 'Hiệu trưởng', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000003-0000-4000-8000-000000000001","IsDeleted":false,"MA_CHUC_VU":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_CHUC_VU":"Hiệu trưởng"}'::jsonb),
  ('DM_CHUC_VU', 'a0000003-0000-4000-8000-000000000002', NULL, '02', 'Phó Hiệu trưởng', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000003-0000-4000-8000-000000000002","IsDeleted":false,"MA_CHUC_VU":"02","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_CHUC_VU":"Phó Hiệu trưởng"}'::jsonb),
  ('DM_CHUC_VU', 'a0000003-0000-4000-8000-000000000003', NULL, '03', 'Trưởng khoa', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000003-0000-4000-8000-000000000003","IsDeleted":false,"MA_CHUC_VU":"03","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_CHUC_VU":"Trưởng khoa"}'::jsonb),
  ('DM_DAN_TOC', 'a0000004-0000-4000-8000-000000000001', NULL, '01', 'Kinh', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000004-0000-4000-8000-000000000001","IsDeleted":false,"MA_DAN_TOC":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_DAN_TOC":"Kinh"}'::jsonb),
  ('DM_DAN_TOC', 'a0000004-0000-4000-8000-000000000002', NULL, '02', 'Tày', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000004-0000-4000-8000-000000000002","IsDeleted":false,"MA_DAN_TOC":"02","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_DAN_TOC":"Tày"}'::jsonb),
  ('DM_DAN_TOC', 'a0000004-0000-4000-8000-000000000003', NULL, '03', 'Thái', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000004-0000-4000-8000-000000000003","IsDeleted":false,"MA_DAN_TOC":"03","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_DAN_TOC":"Thái"}'::jsonb),
  ('DM_GIOI_TINH', 'a0000005-0000-4000-8000-000000000001', NULL, '01', 'Nam', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000005-0000-4000-8000-000000000001","IsDeleted":false,"MA_GIOI_TINH":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_GIOI_TINH":"Nam"}'::jsonb),
  ('DM_GIOI_TINH', 'a0000005-0000-4000-8000-000000000002', NULL, '02', 'Nữ', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000005-0000-4000-8000-000000000002","IsDeleted":false,"MA_GIOI_TINH":"02","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_GIOI_TINH":"Nữ"}'::jsonb),
  ('DM_HOC_HAM', 'a0000006-0000-4000-8000-000000000001', NULL, '01', 'Phó giáo sư', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000006-0000-4000-8000-000000000001","IsDeleted":false,"MA_HOC_HAM":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_HOC_HAM":"Phó giáo sư"}'::jsonb),
  ('DM_HOC_HAM', 'a0000006-0000-4000-8000-000000000002', NULL, '02', 'Giáo sư', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000006-0000-4000-8000-000000000002","IsDeleted":false,"MA_HOC_HAM":"02","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_HOC_HAM":"Giáo sư"}'::jsonb),
  ('DM_LOAI_HINH_TRUONG', 'a0000007-0000-4000-8000-000000000001', NULL, '01', 'Công lập', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000007-0000-4000-8000-000000000001","IsDeleted":false,"MA_LOAI_HINH_TRUONG":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_LOAI_HINH_TRUONG":"Công lập"}'::jsonb),
  ('DM_LOAI_HINH_TRUONG', 'a0000007-0000-4000-8000-000000000002', NULL, '02', 'Tư thục', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000007-0000-4000-8000-000000000002","IsDeleted":false,"MA_LOAI_HINH_TRUONG":"02","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_LOAI_HINH_TRUONG":"Tư thục"}'::jsonb),
  ('DM_LOAI_HOP_DONG', 'a0000008-0000-4000-8000-000000000001', NULL, '01', 'Biên chế', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000008-0000-4000-8000-000000000001","IsDeleted":false,"MA_LOAI_HOP_DONG":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_LOAI_HOP_DONG":"Biên chế"}'::jsonb),
  ('DM_LOAI_HOP_DONG', 'a0000008-0000-4000-8000-000000000002', NULL, '02', 'Hợp đồng lao động', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000008-0000-4000-8000-000000000002","IsDeleted":false,"MA_LOAI_HOP_DONG":"02","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_LOAI_HOP_DONG":"Hợp đồng lao động"}'::jsonb),
  ('DM_LOAI_HOP_DONG', 'a0000008-0000-4000-8000-000000000003', NULL, '03', 'Hợp đồng thỉnh giảng', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000008-0000-4000-8000-000000000003","IsDeleted":false,"MA_LOAI_HOP_DONG":"03","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_LOAI_HOP_DONG":"Hợp đồng thỉnh giảng"}'::jsonb),
  ('DM_NGACH', 'a0000009-0000-4000-8000-000000000001', NULL, 'V.07.01.03', 'Giảng viên (hạng III)', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000009-0000-4000-8000-000000000001","IsDeleted":false,"MA_NGACH":"V.07.01.03","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_NGACH":"Giảng viên (hạng III)"}'::jsonb),
  ('DM_NGACH', 'a0000009-0000-4000-8000-000000000002', NULL, 'V.07.01.02', 'Giảng viên chính (hạng II)', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000009-0000-4000-8000-000000000002","IsDeleted":false,"MA_NGACH":"V.07.01.02","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_NGACH":"Giảng viên chính (hạng II)"}'::jsonb),
  ('DM_QUOC_TICH', 'a0000010-0000-4000-8000-000000000001', NULL, '704', 'Việt Nam', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000010-0000-4000-8000-000000000001","IsDeleted":false,"MA_QUOC_TICH":"704","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_QUOC_TICH":"Việt Nam"}'::jsonb),
  ('DM_QUOC_TICH', 'a0000010-0000-4000-8000-000000000002', NULL, '840', 'Hoa Kỳ', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000010-0000-4000-8000-000000000002","IsDeleted":false,"MA_QUOC_TICH":"840","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_QUOC_TICH":"Hoa Kỳ"}'::jsonb),
  ('DM_TINH_NEW', 'a0000011-0000-4000-8000-000000000001', NULL, '79', 'Thành phố Hồ Chí Minh', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000011-0000-4000-8000-000000000001","IsDeleted":false,"MA_TINH_NEW":"79","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_TINH_NEW":"Thành phố Hồ Chí Minh"}'::jsonb),
  ('DM_TINH_NEW', 'a0000011-0000-4000-8000-000000000002', NULL, '01', 'Thành phố Hà Nội', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000011-0000-4000-8000-000000000002","IsDeleted":false,"MA_TINH_NEW":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_TINH_NEW":"Thành phố Hà Nội"}'::jsonb),
  ('DM_TON_GIAO', 'a0000012-0000-4000-8000-000000000001', NULL, '00', 'Không', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000012-0000-4000-8000-000000000001","IsDeleted":false,"MA_TON_GIAO":"00","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_TON_GIAO":"Không"}'::jsonb),
  ('DM_TON_GIAO', 'a0000012-0000-4000-8000-000000000002', NULL, '01', 'Phật giáo', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000012-0000-4000-8000-000000000002","IsDeleted":false,"MA_TON_GIAO":"01","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_TON_GIAO":"Phật giáo"}'::jsonb),
  ('DM_TON_GIAO', 'a0000012-0000-4000-8000-000000000003', NULL, '02', 'Công giáo', true, true, '2026-03-01T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000012-0000-4000-8000-000000000003","IsDeleted":true,"MA_TON_GIAO":"02","Modified":"2026-03-01T08:00:00","ModifiedBy":"mock","TEN_TON_GIAO":"Công giáo"}'::jsonb),
  ('DM_TRINH_DO_DAO_TAO', 'a0000013-0000-4000-8000-000000000001', NULL, 'DH', 'Đại học', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000013-0000-4000-8000-000000000001","IsDeleted":false,"MA_TRINH_DO_DAO_TAO":"DH","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_TRINH_DO_DAO_TAO":"Đại học"}'::jsonb),
  ('DM_TRINH_DO_DAO_TAO', 'a0000013-0000-4000-8000-000000000002', NULL, 'ThS', 'Thạc sĩ', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000013-0000-4000-8000-000000000002","IsDeleted":false,"MA_TRINH_DO_DAO_TAO":"ThS","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_TRINH_DO_DAO_TAO":"Thạc sĩ"}'::jsonb),
  ('DM_TRINH_DO_DAO_TAO', 'a0000013-0000-4000-8000-000000000003', NULL, 'TS', 'Tiến sĩ', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000013-0000-4000-8000-000000000003","IsDeleted":false,"MA_TRINH_DO_DAO_TAO":"TS","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_TRINH_DO_DAO_TAO":"Tiến sĩ"}'::jsonb),
  ('DM_XA_NEW', 'a0000014-0000-4000-8000-000000000001', NULL, '27004', 'Phường Bàn Cờ', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000014-0000-4000-8000-000000000001","IsDeleted":false,"MA_XA_NEW":"27004","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_XA_NEW":"Phường Bàn Cờ"}'::jsonb),
  ('DM_XA_NEW', 'a0000014-0000-4000-8000-000000000002', NULL, '27007', 'Phường Xuân Hòa', true, false, '2026-01-15T08:00:00+00', '2026-10-21 00:00:00+00', '{"Code":null,"Created":"2026-01-15T08:00:00","CreatedBy":"mock","ISPUBLIC":true,"Id":"a0000014-0000-4000-8000-000000000002","IsDeleted":false,"MA_XA_NEW":"27007","Modified":"2026-01-15T08:00:00","ModifiedBy":"mock","TEN_XA_NEW":"Phường Xuân Hòa"}'::jsonb);

-- (c) validation_rule: 324 dong tu docs/spec/db3_doi_ngu.yaml (23 mang)
INSERT INTO hemis_sync.validation_rule (ph, entity, field, required, max_length, data_type, catalog_name, condition_expr, note) VALUES
  ('CANBO', '_CANBO_HOSO', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'HO_DEM', true, 250, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TEN_GOI', true, 250, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_SINH', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'DAN_TOC_ID', true, 36, 'string', 'DM_DAN_TOC', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'GIOI_TINH_ID', true, 36, 'string', 'DM_GIOI_TINH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'QUOC_TICH_ID', true, 36, 'string', 'DM_QUOC_TICH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TON_GIAO_ID', true, 36, 'string', 'DM_TON_GIAO', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'HK_TINH_ID', false, 36, 'string', 'DM_TINH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'HK_HUYEN_ID', false, 36, 'string', 'DM_HUYEN', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'HK_XA_ID', false, 36, 'string', 'DM_XA', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'HK_TINH_NEW', true, 20, 'string', 'DM_TINH_NEW', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'HK_XA_NEW', true, 20, 'string', 'DM_XA_NEW', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'MA_CAN_BO', false, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'BAC_SI_CK_DUOC_SI_CK_I', false, NULL, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'BAC_SI_CK_DUOC_SI_CK_II', false, NULL, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'EMAIL', false, 250, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'DIEN_THOAI', false, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'TRANG_THAI_CAN_BO_ID', true, 36, 'string', 'DM_TRANG_THAI_CAN_BO', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'CHUC_DANH_NGHE_NGHIEP', true, 36, 'string', 'DM_CHUC_DANH_NGHE_NGHIEP', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'CHUC_DANH_GIANG_VIEN', false, 36, 'string', 'DM_CHUC_DANH_GIANG_VIEN', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'CHUC_DANH_NGHIEN_CUU_KHOA_HOC', false, 36, 'string', 'DM_CHUC_DANH_NGHIEN_CUU_KHOA_HOC', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGACH_ID', false, 36, 'string', 'DM_NGACH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'KHUNG_NLUC_NNGU_ID', false, 36, 'string', 'DM_KHUNG_NANG_LUC_NGOAI_NGU', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TRINH_DO_LLCT_ID', false, 36, 'string', 'DM_TRINH_DO_LLCT', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TRINH_DO_QLNN_ID', false, 36, 'string', 'DM_TRINH_DO_QLNN', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TRINH_DO_TIN_HOC_ID', false, 36, 'string', 'DM_TRINH_DO_TIN_HOC', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'IS_CHUNG_CHI_SP_GIANG_VIEN', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'IS_CHUNG_CHI_SP_GIAO_VIEN', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'CHUC_VU_ID', true, 36, 'string', 'DM_CHUC_VU', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'CO_QUAN_CONG_TAC', false, 3600, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_TUYEN_DUNG', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_CHUYEN_TRANG_THAI', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'IS_MAC_LENIN', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'IS_SU_PHAM', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'SO_GIAY_PHEP_LAO_DONG', false, 100, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'GVNN_TU_NGAY', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'GVNN_DEN_NGAY', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGANH_THAM_GIA_DTTX', false, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'THOI_GIAN_THAM_GIA_DAO_TAO', false, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'THAM_NIEN_CONG_TAC', false, 200, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TEN_DOANH_NGHIEP', false, 2000, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'DIA_CHI_DTTX', false, 2000, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'SO_QUYET_DINH', false, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_QUYET_DINH', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_KET_THUC_TAM_NGHI', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'HINH_THUC_CHUYEN_DEN', false, 4000, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'KINH_NGHIEM_GIANG_DAY', false, 4000, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'GIANG_VIEN_DAP_UNG_TT', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'THOI_GIAN_DTTX', false, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TRINH_DO_DAO_TAO_ID', true, 36, 'string', 'DM_TRINH_DO_DAO_TAO', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'CHUYEN_MON_DUOC_DAO_TAO', false, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO', 'CHUC_DANH_KHOA_HOC', false, 36, 'string', 'DM_CHUC_DANH_KHOA_HOC', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGOAI_NGU_ID', false, 36, 'string', 'DM_NGOAI_NGU', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'IS_CONG_CHUC', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'IS_VIEN_CHUC', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'BHXH_SO', false, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_VAO_DANG', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_VAO_DANG_CHINH_THUC', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_NHAP_NGU', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'NGAY_XUAT_NGU', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'THUONG_BINH_HANG_ID', false, 36, 'string', 'DM_HANG_THUONG_BINH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'GIA_DINH_CHINH_SACH_ID', false, 36, 'string', 'DM_HO_GIA_DINH_CHINH_SACH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'CHO_LAM_VIEC_RIENG', true, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TEN_CHUYEN_NGANH', true, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'HE_SO_THAM_GIA', true, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO', 'TONG_HE_SO_THAM_GIA', true, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'TU_NGAY', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'DEN_NGAY', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'DON_VI_CHINH', true, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'DON_VI_GIANG_DAY', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'MA_PHONG_BAN', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'CHUC_VU_ID', true, 36, 'string', 'DM_CHUC_VU', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'HINH_THUC_ID', false, 36, 'string', 'DM_HINH_THUC_BO_NHIEM', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'SO_QUYET_DINH', false, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DON_VI', 'NGAY_QUYET_DINH', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'DON_VI_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'DON_VI_THINH_GIANG_ID', false, 250, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'NAM', false, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'SO_HD_THINH_GIANG', true, 100, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'THOI_GIAN_BAT_DAU', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DONVITG', 'THOI_GIAN_KET_THUC', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'DAO_TAO_GDQPAN', false, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'LOAI_GIANG_VIEN_GDQPAN', true, 36, 'string', 'DM_LOAI_GV_QPAN', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'NAM_BAT_DAU_BIET_PHAI', true, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'QUAN_HAM', false, 36, 'string', 'DM_QUAN_HAM', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'SO_NAM_BIET_PHAI', false, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GIAO_VIEN_QPAN', 'SO_TRUONG_CONG_TAC', false, 255, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GV_NUOC_NGOAI', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GV_NUOC_NGOAI', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GV_NUOC_NGOAI', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GV_NUOC_NGOAI', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GV_NUOC_NGOAI', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GV_NUOC_NGOAI', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GV_NUOC_NGOAI', 'CO_QUAN_CHU_QUAN', false, 2000, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_GV_NUOC_NGOAI', 'NOI_DUNG', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_TRINH_DO_TIENG_DT', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_TRINH_DO_TIENG_DT', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_TRINH_DO_TIENG_DT', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_TRINH_DO_TIENG_DT', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_TRINH_DO_TIENG_DT', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_TRINH_DO_TIENG_DT', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_TRINH_DO_TIENG_DT', 'KHUNG_TRINH_DO', false, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_TRINH_DO_TIENG_DT', 'TIENG_DAN_TOC', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'TEN_KHOA', true, 5000, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'CHUNG_CHI', false, 2550, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'LOAI_BOI_DUONG', true, 255, 'string', 'DM_LOAI_BOI_DUONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'DIA_DIEM_TO_CHUC', false, 5000, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'DON_VI_TO_CHUC', false, 2550, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'NGUON_KINH_PHI', false, 2550, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'NGAY_CAP', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'THOI_GIAN_BAT_DAU', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_BOIDUONGTH', 'THOI_GIAN_KET_THUC', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DANHGIA_90', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DANHGIA_90', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DANHGIA_90', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DANHGIA_90', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DANHGIA_90', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DANHGIA_90', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DANHGIA_90', 'NAM_DG', true, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DANHGIA_90', 'KET_QUA_DG', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'THANG_NAM', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'TRINH_DO_ID', true, 36, 'string', 'DM_TRINH_DO', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'BAC_LUONG_ID', false, 36, 'string', 'DM_BAC_LUONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'HE_SO_LUONG', false, 36, 'string', 'DM_HE_SO_LUONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DBLUONG', 'MUC_LUONG', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'DT_CHINH_SACH_ID', true, 36, 'string', 'DM_DOI_TUONG_CHINH_SACH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'TU_NGAY', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_DTCHINHSACH', 'DEN_NGAY', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'HOC_VIEN_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'CMTND', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'DOI_TUONG', true, 250, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'TRACH_NHIEM_HUONG_DAN', true, 300, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'TG_BAT_DAU', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HD_NVSHV', 'TG_KET_THUC', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'DON_VI_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'HOC_HAM_ID', true, 36, 'string', 'DM_HOC_HAM', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'LOAI_QD_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'SO_QD', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOC_HAM', 'NGAY_QD', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'LOAI_HOP_DONG', true, 36, 'string', 'DM_LOAI_HOP_DONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'SO_HOP_DONG', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'SO_QUYET_DINH', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'NGAY_QUYET_DINH', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'TU_NGAY', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'DEN_NGAY', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'TOAN_THOI_GIAN', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'TRANG_THAI', true, 36, 'string', 'DM_TRANG_THAI_HOP_DONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG', 'TEN_TO_CHUC_KHCN', false, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'SO_HOP_DONG', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'HD_TU_NGAY', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'HD_DEN_NGAY', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'SO_LD', false, 100, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'NGAY_CAP_LD', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'NOI_CAP_LD', false, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'TRANG_THAI', false, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_HOPDONG_THINHGIANG', 'TY_LE_THOI_GIAN', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'NAM', true, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'SO_QUYET_DINH', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'PHUONG_THUC_KHEN_THUONG_ID', true, 36, 'string', 'DM_PHUONG_THUC_KHEN_THUONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'CAP_KHEN_THUONG_ID', true, 36, 'string', 'DM_CAP_KHEN_THUONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'DANH_HIEU_THI_DUA_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KHENTHUONG', 'PHAN_LOAI', true, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'NAM', true, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'LOAI_KY_LUAT_ID', true, 36, 'string', 'DM_LOAI_KY_LUAT', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'CAP_QUYET_DINH', true, 200, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'SO_QUYET_DINH', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'NGAY_QUYET_DINH', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_KYLUAT', 'LY_DO', false, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'DON_VI_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'LINH_VUC_ID', true, 36, 'string', 'DM_LINH_VUC_NGHIEN_CUU', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'NAM_NGHIEN_CUU', false, 300, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_LINHVUCNC', 'IS_CHUYEN_SAU', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANH_DUNG_TEN', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANH_DUNG_TEN', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANH_DUNG_TEN', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANH_DUNG_TEN', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANH_DUNG_TEN', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANH_DUNG_TEN', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANH_DUNG_TEN', 'NGANH_ID', true, 20, 'string', 'DM_NGANH', NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_NGANH_DUNG_TEN', 'TRONG_SO', true, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'NGANH_ID', true, 36, 'string', 'DM_NGANH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'TRINH_DO_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'DON_VI_THINH_GIANG_ID', false, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_NGANHGD', 'IS_NGANH_CHINH', false, NULL, 'bool', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'CCCD', false, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'NGAY_HUONG', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'BAC_LUONG_ID', true, 36, 'string', 'DM_BAC_LUONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'HE_SO_LUONG', false, 36, 'string', 'DM_HE_SO_LUONG', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'PHAN_TRAM_VUOT_KHUNG', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'PHU_CAP_CHUC_VU', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'PHU_CAP_THAM_NIEN', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'PHU_CAP_UU_DAI_NGHE', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'PHU_CAP_THU_HUT_NGHE', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'PHU_CAP_DOC_HAI', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_PHUCAP', 'PHU_CAP_KHAC', false, NULL, 'double', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'DON_VI_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'TU_NGAY', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'DEN_NGAY', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'DON_VI_CONG_TAC', false, 255, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'CHUC_DANH', false, 36, 'string', 'DM_CHUC_DANH', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTCT', 'CHUC_VU', true, 36, 'string', 'DM_CHUC_VU', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'DON_VI_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'CAN_BO_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'CCCD', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'NGANH_ID', false, 200, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'TRINH_DO_ID', true, 36, 'string', 'DM_TRINH_DO', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'CO_SO_DAO_TAO', false, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'QUOC_GIA_ID', false, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'LOAI_HINH_DAO_TAO', false, 36, 'string', 'DM_LOAI_HINH_DAO_TAO', NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'THOI_GIAN_BAT_DAU', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'THOI_GIAN_KET_THUC', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CANBO_HOSO_QTDAOTAO', 'NAM_TOT_NGHIEP', false, NULL, 'int', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'Id', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'Created', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'Modified', true, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'DON_VI_ID', true, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'PARENT_ID', false, NULL, 'guid', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'MA_CAP_CHA', false, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'MA_TO_CHUC_ID', true, 50, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'TEN_TO_CHUC', true, 350, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'LOAI_DON_VI_ID', true, 36, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'SO_QUYET_DINH', false, 500, 'string', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'NGAY_RA_QD', false, NULL, 'date', NULL, NULL, 'GIA LAP - tu YAML D01'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'TRANG_THAI', true, 30, 'string', NULL, NULL, 'GIA LAP - tu YAML D01; can_xac_minh'),
  ('CANBO', '_CO_CAU_TO_CHUC', 'MA_DINH_DANH_DIEN_TU', false, 100, 'string', NULL, NULL, 'GIA LAP - tu YAML D01');

-- HET goi_mot_file.sql
