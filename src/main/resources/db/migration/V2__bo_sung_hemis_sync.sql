CREATE SCHEMA IF NOT EXISTS hemis_sync;
SET search_path = hemis_sync, public;

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
-- (Thuc hien migration an toan, khong dung DROP TABLE de bao toan du lieu)
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'hemis_sync' AND table_name = 'entity_map' AND column_name = 'entity_type') THEN
        ALTER TABLE hemis_sync.entity_map ADD COLUMN entity_type VARCHAR(50);
        ALTER TABLE hemis_sync.entity_map ADD COLUMN business_key VARCHAR(200);
        ALTER TABLE hemis_sync.entity_map ADD COLUMN first_sent_at TIMESTAMPTZ;
        UPDATE hemis_sync.entity_map SET entity_type = UPPER(local_table) WHERE entity_type IS NULL;
        UPDATE hemis_sync.entity_map SET business_key = local_id WHERE business_key IS NULL;
        ALTER TABLE hemis_sync.entity_map ALTER COLUMN entity_type SET NOT NULL;
        ALTER TABLE hemis_sync.entity_map ALTER COLUMN business_key SET NOT NULL;
        ALTER TABLE hemis_sync.entity_map DROP CONSTRAINT IF EXISTS pk_entity_map;
        ALTER TABLE hemis_sync.entity_map ADD CONSTRAINT pk_entity_map PRIMARY KEY (entity_type, business_key);
    END IF;
END $$;

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


-- ---------------------------------------------------------------------
-- 2b. dia_gioi_map: anh xa dia gioi cu -> moi theo QD 19/2025 (SV1-04)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hemis_sync.dia_gioi_map (
    id         BIGSERIAL    PRIMARY KEY,
    ma_cu      VARCHAR(50)  NOT NULL,
    ma_moi     VARCHAR(50),
    ten_cu     VARCHAR(200),
    ten_moi    VARCHAR(200),
    loai       VARCHAR(20)  NOT NULL,
    ghi_chu    VARCHAR(500),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_dia_gioi_map UNIQUE (loai, ma_cu),
    CONSTRAINT ck_dia_gioi_map_loai CHECK (loai IN ('TINH', 'HUYEN', 'XA'))
);
CREATE INDEX IF NOT EXISTS ix_dia_gioi_map_lookup ON hemis_sync.dia_gioi_map (loai, ma_cu);

-- Bo sung CHECK constraint cho catalog_map.strategy
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_schema = 'hemis_sync' AND constraint_name = 'ck_catalog_map_strategy') THEN
        ALTER TABLE hemis_sync.catalog_map ADD CONSTRAINT ck_catalog_map_strategy CHECK (strategy IN ('IDENTITY', 'MAPPED', 'MISSING'));
    END IF;
END $$;
