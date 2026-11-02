# 13. Hướng dẫn kết nối dữ liệu từ kho HEMIS nội bộ

|                          |                                                           |
| ------------------------ | --------------------------------------------------------- |
| **Người đọc**            | Người quản trị cơ sở dữ liệu; người viết bộ trích xuất    |
| **Lý do thiết kế**       | [10_THIET_KE_CSDL.md](10_THIET_KE_CSDL.md)                |
| **Lệnh thiết lập**       | `src/main/resources/db/setup/01_ket_noi_hemis_noi_bo.sql` |
| **Lớp đọc cho ứng dụng** | `src/main/resources/db/migration/V3__hemis_src_views.sql` |

Kho dữ liệu (repo `HEMIS-DWH-Database`) và cổng tích hợp (`hemis-platform`) là **hai database PostgreSQL riêng**. Cổng chỉ được đọc kho. Mã Java chỉ được đọc view trong schema `hemis_src`, không đọc bảng gốc của kho và không đọc bảng ngoại `hemis_noi_bo.*`.

---

## 1. Đường dữ liệu

```
Kho HEMIS noi bo                         Database cua hemis-platform
public.CanBo, public.NguoiHoc, ...
        |  postgres_fdw, tai khoan chi doc
        v
                                 hemis_noi_bo.canbo, hemis_noi_bo.nguoihoc, ...
                                 (bang ngoai, chi doc)
                                        |
                                        v
                                 hemis_src.v_can_bo, v_nguoi_hoc, v_co_so_giao_duc
                                 (view - ten cot dung ten truong cua Bo)
                                        |
                                        v
                                 hemis_sync.entity_map, catalog_map, sync_batch
                                 (vung lam viec cua cong tich hop)
```

| Chỗ                 | Ai ghi                                                        | Ứng dụng Java có được đọc?                |
| ------------------- | ------------------------------------------------------------- | ----------------------------------------- |
| `public.*` trên kho | Đơn vị trong Trường, qua HEMIS-DWH                            | Không                                     |
| `hemis_noi_bo.*`    | Không ai ghi. PostgreSQL lấy dữ liệu từ kho khi có câu SELECT | Không. Chỉ view và hàm kiểm tra được dùng |
| `hemis_src.*`       | Không. Chỉ là view                                            | Có. Đây là hợp đồng đọc                   |
| `hemis_sync.*`      | Cổng tích hợp                                                 | Có, cho nhật ký, ánh xạ, quy tắc          |

Tên database kho trong script mẫu là `hemis_noi_bo`. Môi trường kiểm thử của repo kho đang dùng tên `hemis_dwh_test`. Khi làm, sửa `dbname` cho đúng database đang chạy, không đổi tên bảng trong view cho khớp tên database.

---

## 2. Phân hệ nào lấy từ kho

| Phân hệ                        | Nguồn hiện tại                                                                                      | View                                                       |
| ------------------------------ | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Cơ sở giáo dục (`COSOGIAODUC`) | Bảng `hemis_sync.co_so_giao_duc`, **không** lấy từ kho. Kho chưa có bảng thông tin chung của Trường | `hemis_src.v_co_so_giao_duc` — có ngay cả khi chưa nối kho |
| Đội ngũ (`CANBO`)              | `public.CanBo`                                                                                      | `hemis_src.v_can_bo` — chỉ được tạo sau khi đã nối kho     |
| Người học (`HOCVIEN`)          | `public.NguoiHoc`                                                                                   | `hemis_src.v_nguoi_hoc` — cùng điều kiện                   |

Các bảng con khác (hợp đồng, quá trình công tác, học tập…) được khai trong danh sách nạp bảng ngoại, nhưng **chưa có view**. Chưa có view thì chưa viết extractor.

`CoSoGiaoDucExtractor` hiện vẫn đọc cấu hình ứng dụng, chưa đọc `hemis_src.v_co_so_giao_duc`. Nối kho xong chưa làm lệnh `chuan-bi` ra dữ liệu kho. Việc sửa extractor là bước mã sau bước kết nối này.

---

## 3. Điều kiện trước khi nối

1. Hai database thông nhau trên cổng 5432. Cổng tích hợp chủ động mở kết nối sang kho.
2. Người chạy có quyền superuser trên database của `hemis-platform` (để `CREATE EXTENSION postgres_fdw`).
3. Người chạy có quyền tạo role trên database kho.
4. Bảng `CanBo` và `NguoiHoc` đã có trên kho. Script tạo bảng không đặt tên trong ngoặc kép, PostgreSQL hạ thành `canbo`, `nguoihoc`.
5. Mật khẩu tài khoản chỉ đọc **không** ghi vào git. Script trong repo để sẵn chữ `DOI_MAT_KHAU_NAY`. Sửa trên máy chủ rồi chạy, không commit bản đã điền mật khẩu.

Máy phát triển không có kho vẫn chạy được ứng dụng. Migration V3 thấy chưa có `hemis_noi_bo.canbo` thì bỏ qua view đội ngũ và người học, in dòng `Chua thiet lap ket noi toi HEMIS noi bo`. Đó là trạng thái bình thường, không phải lỗi.

---

## 4. Các bước thiết lập

Chạy một lần cho mỗi môi trường. Làm trên bản sao của `01_ket_noi_hemis_noi_bo.sql` đã sửa host, port, tên database và mật khẩu.

### Bước 1 — Tài khoản chỉ đọc, trên database kho

```sql
CREATE ROLE hemis_reader LOGIN PASSWORD 'mat-khau-chi-dung-tren-may-chu';

GRANT CONNECT ON DATABASE hemis_noi_bo TO hemis_reader;
GRANT USAGE  ON SCHEMA public TO hemis_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO hemis_reader;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO hemis_reader;
```

Đổi `hemis_noi_bo` nếu database kho mang tên khác. Kiểm tra tài khoản không ghi được: đăng nhập bằng `hemis_reader` rồi `INSERT` một dòng phải bị từ chối.

### Bước 2 — Khai báo máy chủ kho, trên database của hemis-platform

```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

CREATE SERVER IF NOT EXISTS srv_hemis_noi_bo
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        host 'dia-chi-may-kho',
        port '5432',
        dbname 'hemis_noi_bo',
        connect_timeout '10',
        fetch_size '1000'
    );

CREATE USER MAPPING IF NOT EXISTS FOR hemis
    SERVER srv_hemis_noi_bo
    OPTIONS (user 'hemis_reader', password 'mat-khau-chi-dung-tren-may-chu');

GRANT USAGE ON FOREIGN SERVER srv_hemis_noi_bo TO hemis;

CREATE SCHEMA IF NOT EXISTS hemis_noi_bo;
```

`FOR hemis` là role mà ứng dụng Spring dùng để đăng nhập database cổng (`DB_USER`). Role ứng dụng khác tên thì đổi cho khớp, nếu không câu SELECT của ứng dụng không đi được qua liên kết.

Hai database cùng một máy thì `host` là `localhost`.

### Bước 3 — Nạp bảng cần đọc

Không nạp cả 253 bảng. Danh sách hiện có trong script:

```sql
IMPORT FOREIGN SCHEMA public
    LIMIT TO (
        canbo, donvicongtac, hopdonglaodong, quatrinhcongtac, quatrinhdaotao,
        chucdanhkhoahoccanbo, nganhgiangday,
        nguoihoc, hoctapsinhvien, hoctaphocvien, hoctapnghiencuusinh,
        hocbong, khenthuong, kyluat, vieclamsautotnghiep,
        danhsachnganh, chuongtrinhdaotao, namapdung,
        chitieutuyensinh, dulieutrungtuyen,
        dm_gioitinh, dm_dantoc, dm_quoctich, dm_tongiao,
        dm_tinhthanhpho, dm_xaphuong
    )
    FROM SERVER srv_hemis_noi_bo
    INTO hemis_noi_bo;
```

Tên trong `LIMIT TO` là tên đã hạ chữ thường. Bảng kho không có trong danh sách thì lệnh báo không tìm thấy quan hệ. Đối chiếu tên thật:

```sql
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

chạy trên database kho.

### Bước 4 — Tạo lại view

Flyway đã chạy V3 từ trước, lúc chưa có bảng ngoại, nên view `v_can_bo` và `v_nguoi_hoc` chưa tồn tại. Chạy lại **nội dung** file `V3__hemis_src_views.sql` bằng `psql` trên database của cổng. File dùng `CREATE OR REPLACE` và khối `DO` kiểm tra `hemis_noi_bo.canbo`. Không sửa bảng `flyway_schema_history` để bắt Flyway chạy lại.

Kỳ vọng: thông báo `Da tao cac view hemis_src doc tu HEMIS noi bo.`

### Bước 5 — Kiểm tra

```sql
SELECT * FROM hemis_sync.kiem_tra_ket_noi_noi_bo();
```

| `trang_thai`     | Ý nghĩa                                                                                                                              |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `CHUA_THIET_LAP` | Chưa có bảng ngoại `hemis_noi_bo.canbo`. Quay lại bước 3                                                                             |
| `LOI`            | Có bảng ngoại nhưng không đọc được. Xem `chi_tiet`: sai mật khẩu, sai host, kho tắt, hoặc role ứng dụng không có `USAGE` trên server |
| `OK`             | Đọc được bảng cán bộ. `chi_tiet` ghi số dòng                                                                                         |

Sau `OK`:

```sql
SELECT count(*) FROM hemis_src.v_can_bo;
SELECT count(*) FROM hemis_src.v_nguoi_hoc;
SELECT "MA_DON_VI", "TEN_DON_VI" FROM hemis_src.v_co_so_giao_duc;
```

`v_co_so_giao_duc` không phụ thuộc kết nối kho. Bảng `hemis_sync.co_so_giao_duc` chưa có dòng thì view này rỗng. Đó là dữ liệu nhập một lần cho Trường, không phải lỗi FDW.

Dòng cán bộ hoặc người học thiếu `SoCCCD` sẽ có `business_key` rỗng. Bản ghi đó không được đưa vào `entity_map` và không gửi. Khóa gửi Bộ là số căn cước, không phải cột `ID` tự tăng. Kho nạp lại bằng `reset_all.sql` thì `ID` đổi, số căn cước không đổi.

---

## 5. Cách ứng dụng được phép đọc

Một bộ trích xuất chỉ SELECT trên `hemis_src`. Ví dụ đội ngũ:

```sql
SELECT "CCCD", "HO_DEM", "TEN_GOI", "NGAY_SINH", "GIOI_TINH_ID", delta_ts
FROM hemis_src.v_can_bo;
```

Quy ước cột:

| Cột                                    | Dùng để                                                                                                                                        |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Tên viết hoa (`"CCCD"`, `"HO_DEM"`, …) | Trường JSON gửi Bộ. XML lấy cùng giá trị, đổi sang PascalCase                                                                                  |
| `business_key`                         | Khóa nghiệp vụ đưa vào `entity_map`. Với cán bộ và người học là số căn cước                                                                    |
| `delta_ts`                             | Mốc trích xuất gia tăng: `COALESCE(UpdatedAt, CreatedAt)`. Không lọc `UpdatedAt > mốc` vì bản ghi chưa sửa có `UpdatedAt` null và sẽ bị bỏ sót |
| `nguon_id`                             | Chỉ để truy ngược dòng gốc trong kho. Không ghi vào tệp gửi Bộ                                                                                 |

Mã danh mục trong view đã ép sang chữ (`MaDanToc::text`). Phần lớn mã kho trùng mã HEMIS, chiến lược mặc định là `IDENTITY`. Mã không có trong danh mục Bộ thì ghi `catalog_map` với chiến lược `MISSING` và chặn trước khi gửi. Cột `HK_TINH_NEW`, `HK_XA_NEW`, `TINH_THANH_NEW`, `XA_PHUONG_NEW` đang trả `NULL`: kho chưa có danh mục địa giới theo Quyết định 19/2025/QĐ-TTg.

Cấm trong mã Java: chuỗi `hemis_noi_bo.`, tên bảng `CanBo` / `NguoiHoc`, và cột `ID` của kho dùng làm `Id` gửi Bộ.

---

## 6. Khi kho đổi cấu trúc hoặc mật khẩu

Đổi mật khẩu tài khoản chỉ đọc:

```sql
ALTER USER MAPPING FOR hemis
    SERVER srv_hemis_noi_bo
    OPTIONS (SET password 'mat-khau-moi');
```

Đổi địa chỉ máy kho:

```sql
ALTER SERVER srv_hemis_noi_bo OPTIONS (SET host '10.x.x.x');
```

Kho thêm hoặc sửa cột của một bảng đã nạp:

```sql
DROP FOREIGN TABLE IF EXISTS hemis_noi_bo.canbo CASCADE;
IMPORT FOREIGN SCHEMA public LIMIT TO (canbo)
    FROM SERVER srv_hemis_noi_bo INTO hemis_noi_bo;
```

`CASCADE` xóa view đang trỏ vào bảng đó. Chạy lại phần view tương ứng trong V3. Nếu kho đổi tên cột, sửa view cho khớp tên trường của Bộ. Không sửa extractor để đuổi theo tên cột kho.

Bảng tạo mới trên kho không tự xuất hiện bên cổng. `ALTER DEFAULT PRIVILEGES` chỉ cấp quyền SELECT cho `hemis_reader`. Muốn đọc bảng mới thì thêm tên (chữ thường) vào `IMPORT FOREIGN SCHEMA` và viết view trong `hemis_src`.

---

## 7. Việc chưa nằm trong bước nối này

- Sửa `CoSoGiaoDucExtractor` để đọc `hemis_src.v_co_so_giao_duc`.
- Viết extractor đội ngũ và người học. Chưa viết khi `kiem_tra_ket_noi_noi_bo()` chưa trả `OK`.
- View cho chín phân hệ còn lại.
- Điền mã địa giới mới vào các cột `*_NEW`.
- Ảnh xạ `entity_map` lúc trích xuất. View chỉ đưa `business_key`, chưa sinh GUID.
