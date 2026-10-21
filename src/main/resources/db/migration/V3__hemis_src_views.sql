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
    em.hemis_id                     AS "ID",
    csgd.ma_don_vi                  AS "MA_DON_VI",
    csgd.ten_don_vi                 AS "TEN_DON_VI",
    csgd.ten_tieng_anh              AS "TEN_TIENG_ANH",
    csgd.ten_don_vi_cha             AS "TEN_DON_VI_CHA",
    csgd.website                    AS "WEBSITE",
    csgd.email                      AS "EMAIL",
    csgd.so_dien_thoai              AS "SO_DIEN_THOAI",
    csgd.fax                        AS "FAX",
    csgd.dia_chi                    AS "DIA_CHI",
    csgd.tinh_thanh_id              AS "TINH_THANH_ID",
    csgd.quan_huyen_id              AS "QUAN_HUYEN_ID",
    csgd.xa_phuong_id               AS "XA_PHUONG_ID",
    csgd.tinh_thanh_new             AS "TINH_THANH_NEW",
    csgd.xa_phuong_new              AS "XA_PHUONG_NEW",
    csgd.so_qd_thanh_lap            AS "SO_QD_THANH_LAP",
    csgd.ngay_qd_thanh_lap          AS "NGAY_QD_THANH_LAP",
    csgd.so_qd_chuyen_doi_loai_hinh AS "SO_QD_CHUYEN_DOI_LOAI_HINH",
    csgd.ngay_qd_chuyen_doi         AS "NGAY_QD_CHUYEN_DOI",
    csgd.so_qd_cap_phep_hoat_dong   AS "SO_QD_CAP_PHEP_HOAT_DONG",
    csgd.ngay_duoc_cap_phep_hoat_dong AS "NGAY_DUOC_CAP_PHEP_HOAT_DONG",
    csgd.loai_hinh_id               AS "LOAI_HINH_ID",
    csgd.hinh_thuc_thanh_lap        AS "HINH_THUC_THANH_LAP",
    csgd.loai_co_so                 AS "LOAI_CO_SO",
    csgd.is_loi_nhuan               AS "IS_LOI_NHUAN",
    csgd.tu_chu                     AS "TU_CHU",
    csgd.truong_dac_thu             AS "TRUONG_DAC_THU",
    csgd.so_gv_gdtc                 AS "SO_GV_GDTC",
    csgd.qd_ban_hanh_quy_che        AS "QD_BAN_HANH_QUY_CHE",
    csgd.ngay_qd_ban_hanh_quy_che   AS "NGAY_QD_BAN_HANH_QUY_CHE",
    csgd.ma_dinh_danh_dien_tu       AS "MA_DINH_DANH_DIEN_TU",
    csgd.ma_dinh_danh_nd69          AS "MA_DINH_DANH_ND69",
    csgd.created_at::date           AS "Created",
    COALESCE(csgd.updated_at, csgd.created_at)::date AS "Modified",
    COALESCE(csgd.updated_at, csgd.created_at)       AS "delta_ts"
FROM hemis_sync.co_so_giao_duc csgd
INNER JOIN hemis_sync.entity_map em
    ON em.entity_type = 'CO_SO_GIAO_DUC'
   AND em.business_key = csgd.ma_don_vi;

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
DECLARE
    v_canbo_tbl TEXT := NULL;
    v_nguoihoc_tbl TEXT := NULL;
BEGIN
    IF to_regclass('hemis_noi_bo.canbo') IS NOT NULL THEN
        v_canbo_tbl := 'hemis_noi_bo.canbo';
    ELSIF to_regclass('public.canbo') IS NOT NULL THEN
        v_canbo_tbl := 'public.canbo';
    END IF;

    IF to_regclass('hemis_noi_bo.nguoihoc') IS NOT NULL THEN
        v_nguoihoc_tbl := 'hemis_noi_bo.nguoihoc';
    ELSIF to_regclass('public.nguoihoc') IS NOT NULL THEN
        v_nguoihoc_tbl := 'public.nguoihoc';
    END IF;

    IF v_canbo_tbl IS NULL AND v_nguoihoc_tbl IS NULL THEN
        RAISE NOTICE 'Chua thiet lap ket noi toi HEMIS noi bo hoac DWH - bo qua view doc tu ben do.';
        RETURN;
    END IF;

    IF v_canbo_tbl IS NOT NULL THEN
        EXECUTE format($v$
        CREATE OR REPLACE VIEW hemis_src.v_can_bo AS
        SELECT
            em.hemis_id                         AS "ID",
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
            map_tinh.ma_moi                     AS "HK_TINH_NEW",
            map_xa.ma_moi                       AS "HK_XA_NEW",
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
            COALESCE(cb.UpdatedAt, cb.CreatedAt)       AS "delta_ts",
            cb.ID                               AS nguon_id
        FROM %s cb
        INNER JOIN hemis_sync.entity_map em
            ON em.entity_type = 'CAN_BO'
           AND em.business_key = cb.SoCCCD
        LEFT JOIN hemis_sync.dia_gioi_map map_tinh
            ON map_tinh.loai = 'TINH'
           AND map_tinh.ma_cu = cb.MaTinhCuTru::text
        LEFT JOIN hemis_sync.dia_gioi_map map_xa
            ON map_xa.loai = 'XA'
           AND map_xa.ma_cu = cb.MaXaPhuongCuTru::text
        WHERE cb.isdeleted = FALSE;
        $v$, v_canbo_tbl);
    END IF;

    IF v_nguoihoc_tbl IS NOT NULL THEN
        EXECUTE format($v$
        CREATE OR REPLACE VIEW hemis_src.v_nguoi_hoc AS
        SELECT
            em.hemis_id                         AS "ID",
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
            map_tinh.ma_moi                     AS "TINH_THANH_NEW",
            map_xa.ma_moi                       AS "XA_PHUONG_NEW",
            nh.NoiSinh                          AS "NOI_SINH",
            nh.QueQuan                          AS "QUE_QUAN",
            nh.NgayVaoDoan                      AS "NGAY_VAO_DOAN",
            nh.NgayVaoDang                      AS "NGAY_VAO_DANG",
            nh.NgayVaoDangChinhThuc             AS "NGAY_VAO_DANG_CHINH_THUC",
            nh.CreatedAt::date                  AS "Created",
            COALESCE(nh.UpdatedAt, nh.CreatedAt)::date AS "Modified",
            COALESCE(nh.UpdatedAt, nh.CreatedAt)       AS "delta_ts",
            nh.ID                               AS nguon_id
        FROM %s nh
        INNER JOIN hemis_sync.entity_map em
            ON em.entity_type = 'NGUOI_HOC'
           AND em.business_key = nh.SoCCCD
        LEFT JOIN hemis_sync.dia_gioi_map map_tinh
            ON map_tinh.loai = 'TINH'
           AND map_tinh.ma_cu = nh.MaTinhThuongTru::text
        LEFT JOIN hemis_sync.dia_gioi_map map_xa
            ON map_xa.loai = 'XA'
           AND map_xa.ma_cu = nh.MaXaPhuongThuongTru::text
        WHERE nh.isdeleted = FALSE;
        $v$, v_nguoihoc_tbl);
    END IF;
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
