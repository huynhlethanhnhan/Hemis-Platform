-- =====================================================================
-- THIET LAP KET NOI TU hemis-platform SANG DATABASE "HEMIS NOI BO"
--
-- KHONG chay bang Flyway. Day la viec cua quan tri co so du lieu, chay MOT LAN
-- cho moi moi truong (phat trien / thu nghiem / san xuat).
--
-- Vi sao tach ra khoi Flyway:
--   1. Can quyen superuser de tao extension.
--   2. Chua mat khau ket noi - khong duoc dua vao kho ma nguon.
--   3. Dia chi may chu khac nhau o moi moi truong.
--
-- Doc truoc: docs/10_THIET_KE_CSDL.md muc 4.
-- =====================================================================


-- ---------------------------------------------------------------------
-- PHAN A - Chay tren DATABASE HEMIS NOI BO
--          Tao tai khoan CHI DOC cho cong tich hop.
-- ---------------------------------------------------------------------

-- A1. Tai khoan rieng, chi doc, khong dung chung voi tai khoan ung dung
CREATE ROLE hemis_reader LOGIN PASSWORD 'DOI_MAT_KHAU_NAY';

-- A2. Chi cho phep ket noi va doc, khong cho ghi
GRANT CONNECT ON DATABASE hemis_noi_bo TO hemis_reader;
GRANT USAGE  ON SCHEMA public          TO hemis_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hemis_reader;

-- A3. Bang tao sau nay cung tu dong duoc quyen doc
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO hemis_reader;

-- A4. Kiem tra: lenh sau phai BAO LOI (tai khoan khong duoc ghi)
--     SET ROLE hemis_reader; INSERT INTO CanBo (Ho) VALUES ('test');


-- ---------------------------------------------------------------------
-- PHAN B - Chay tren DATABASE CUA hemis-platform, bang tai khoan superuser
--          Khai bao may chu tu xa va nap bang ngoai.
-- ---------------------------------------------------------------------

-- B1. Trinh ket noi co so du lieu ngoai
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- B2. Khai bao may chu HEMIS noi bo.
--     Sua host / port / dbname cho dung tung moi truong.
--     Hai database cung mot may chu thi dat host = 'localhost'.
CREATE SERVER IF NOT EXISTS srv_hemis_noi_bo
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        host    'localhost',
        port    '5432',
        dbname  'hemis_noi_bo',
        -- Khong de cho mot truy van treo lam ket dong cong tich hop
        connect_timeout     '10',
        fetch_size          '1000'
    );

-- B3. Tai khoan cua cong tich hop dung tai khoan chi doc o Phan A
CREATE USER MAPPING IF NOT EXISTS FOR hemis
    SERVER srv_hemis_noi_bo
    OPTIONS (user 'hemis_reader', password 'DOI_MAT_KHAU_NAY');

GRANT USAGE ON FOREIGN SERVER srv_hemis_noi_bo TO hemis;

-- B4. Schema chua cac bang ngoai, soi guong schema public ben HEMIS noi bo
CREATE SCHEMA IF NOT EXISTS hemis_noi_bo;
COMMENT ON SCHEMA hemis_noi_bo IS
  'Bang ngoai tro sang database HEMIS noi bo qua postgres_fdw. CHI DOC.';

-- B5. Nap dinh nghia bang tu xa.
--     Chi nap nhung bang thuc su can - khong nap ca 253 bang.
--     LUU Y: PostgreSQL ha ten khong dat trong ngoac kep thanh chu thuong,
--     nen bang "CanBo" ben kia o day la "canbo".
IMPORT FOREIGN SCHEMA public
    LIMIT TO (
        -- Phan he CANBO
        canbo, donvicongtac, hopdonglaodong, quatrinhcongtac, quatrinhdaotao,
        chucdanhkhoahoccanbo, nganhgiangday,
        -- Phan he HOCVIEN
        nguoihoc, hoctapsinhvien, hoctaphocvien, hoctapnghiencuusinh,
        hocbong, khenthuong, kyluat, vieclamsautotnghiep,
        -- Phan he NGANHDT / DAOTAO
        danhsachnganh, chuongtrinhdaotao, namapdung,
        -- Phan he TUYENSINH
        chitieutuyensinh, dulieutrungtuyen,
        -- Danh muc dung de doi chieu
        dm_gioitinh, dm_dantoc, dm_quoctich, dm_tongiao,
        dm_tinhthanhpho, dm_xaphuong
    )
    FROM SERVER srv_hemis_noi_bo
    INTO hemis_noi_bo;

-- B6. Kiem tra ket noi
--     SELECT count(*) FROM hemis_noi_bo.canbo;
--     SELECT count(*) FROM hemis_noi_bo.nguoihoc;


-- ---------------------------------------------------------------------
-- PHAN C - Khi HEMIS noi bo thay doi cau truc
-- ---------------------------------------------------------------------
-- Nap lai dinh nghia cua mot bang:
--     DROP FOREIGN TABLE IF EXISTS hemis_noi_bo.canbo CASCADE;
--     IMPORT FOREIGN SCHEMA public LIMIT TO (canbo)
--         FROM SERVER srv_hemis_noi_bo INTO hemis_noi_bo;
--     -- roi tao lai view trong hemis_src (chay lai V3 hoac sua tay)
--
-- Doi mat khau:
--     ALTER USER MAPPING FOR hemis SERVER srv_hemis_noi_bo
--         OPTIONS (SET password 'MAT_KHAU_MOI');
--
-- Doi dia chi may chu:
--     ALTER SERVER srv_hemis_noi_bo OPTIONS (SET host '10.x.x.x');
