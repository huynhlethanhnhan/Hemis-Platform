-- =====================================================================
-- V3 - Schema hemis_src: LOP HOP DONG giua kho du lieu cu (DWH) va
--      cong tich hop HEMIS.
--
-- NGUYEN TAC QUAN TRONG:
--   Cong tich hop KHONG BAO GIO truy van thang bang cua DWH (public.*).
--   Moi truy cap deu di qua view trong hemis_src.
--
-- Vi sao:
--   - DWH do nhom khac phat trien va con thay doi. Neu ma nguon Java truy
--     van thang bang thi moi lan DWH doi ten cot la ung dung vo.
--   - View la hop dong: DWH doi cau truc thi chi sua view, Java khong sua.
--   - Ten cot trong view dat theo DAC TA CUA BO (UPPER_SNAKE), nen doc view
--     la doi chieu duoc ngay voi tai lieu dac ta, khong phai dich hai lan.
--
-- CHAY O DAU:
--   Migration nay tu phat hien co DWH hay khong. Tren may phat trien chi co
--   co so du lieu rong (docker compose), cac view se duoc BO QUA kem mot
--   dong thong bao. Tren may chu co DWH, view duoc tao day du.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS hemis_src;
COMMENT ON SCHEMA hemis_src IS
  'Lop hop dong doc du lieu tu DWH. Chi chua VIEW, khong chua bang.';

-- ---------------------------------------------------------------------
-- 1. CO SO GIAO DUC (phan he COSOGIAODUC - API db1)
--
-- Doc tu hemis_sync.co_so_giao_duc vi DWH chua co bang nay (xem V2 muc 1).
-- Khi DWH bo sung public.CoSoGiaoDuc, chi can sua view nay.
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
  'Phan he COSOGIAODUC (db1). Tam doc tu hemis_sync vi DWH chua co bang thong tin chung Truong.';

-- ---------------------------------------------------------------------
-- 2, 3. Cac view doc tu DWH - chi tao khi DWH ton tai trong cung CSDL
-- ---------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.CanBo') IS NULL THEN
        RAISE NOTICE 'Khong tim thay bang public.canbo - BO QUA cac view doc tu DWH. '
                     'Day la trang thai binh thuong tren may phat trien. '
                     'Tren may chu, nap DWH roi chay lai: SELECT hemis_src.tao_view_dwh();';
        RETURN;
    END IF;

    -- -----------------------------------------------------------------
    -- 2. DOI NGU (phan he CANBO - API db3)
    --
    -- Khoa nghiep vu: SoCCCD. KHONG dung CanBo.ID (SERIAL) vi DWH trien
    -- khai bang reset_all.sql, ID se doi sau moi lan nap lai.
    --
    -- Ten cot cua DWH: Ho, Ten, NgaySinh, SoCCCD, MaCanBo, MaGioiTinh,
    -- MaQuocTich, MaDanToc, MaTonGiao, MaTinhCuTru, MaXaPhuongCuTru...
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
        NULL::text                          AS "HK_TINH_NEW",   -- TODO: dia gioi moi, chua co trong DWH
        NULL::text                          AS "HK_XA_NEW",     -- TODO: dia gioi moi, chua co trong DWH
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
        cb.ID                               AS dwh_id
    FROM public.CanBo cb
    $v$;

    COMMENT ON VIEW hemis_src.v_can_bo IS
      'Phan he CANBO (db3) - ho so chinh. business_key = SoCCCD. delta_ts dung cho trich xuat gia tang.';

    -- -----------------------------------------------------------------
    -- 3. NGUOI HOC (phan he HOCVIEN - API db7)
    -- Khoa nghiep vu: SoCCCD (da co rang buoc UNIQUE trong DWH).
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
        NULL::text                          AS "TINH_THANH_NEW",  -- TODO: dia gioi moi
        NULL::text                          AS "XA_PHUONG_NEW",   -- TODO: dia gioi moi
        nh.NoiSinh                          AS "NOI_SINH",
        nh.QueQuan                          AS "QUE_QUAN",
        nh.NgayVaoDoan                      AS "NGAY_VAO_DOAN",
        nh.NgayVaoDang                      AS "NGAY_VAO_DANG",
        nh.NgayVaoDangChinhThuc             AS "NGAY_VAO_DANG_CHINH_THUC",
        nh.CreatedAt::date                  AS "Created",
        COALESCE(nh.UpdatedAt, nh.CreatedAt)::date AS "Modified",
        COALESCE(nh.UpdatedAt, nh.CreatedAt)       AS delta_ts,
        nh.ID                               AS dwh_id
    FROM public.NguoiHoc nh
    $v$;

    COMMENT ON VIEW hemis_src.v_nguoi_hoc IS
      'Phan he HOCVIEN (db7) - thong tin hoc vien. business_key = SoCCCD.';

    RAISE NOTICE 'Da tao cac view hemis_src doc tu DWH.';
END $$;

-- ---------------------------------------------------------------------
-- 4. Ham kiem tra cac truong bat buoc con thieu
--
-- Dung cho FR-DQ-03 (bao cao khoang trong du lieu). Chay bat ky luc nao,
-- khong can tao dot dong bo.
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
