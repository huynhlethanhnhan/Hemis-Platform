# He_data_tasks — Báo cáo công việc nhóm Database (dữ liệu thử nghiệm HEMIS)

| | |
|---|---|
| **Người thực hiện** | Trần Tuấn Anh, nhóm Database |
| **Người nhận** | Thầy hướng dẫn, các nhóm Platform, Backend, Frontend |
| **Ngày** | 22/10/2026 |
| **Phạm vi** | Phần database của repo platform (`Hemis-Platform`): `hemis_sync`, `hemis_src`. Kho `hemis_noi_bo` do thầy đưa lên sau |
| **Dữ liệu** | Toàn bộ là **dữ liệu giả** tự tạo. Không có CCCD, tên người hay dữ liệu thật |

## 1. Kết quả chính

Đã tạo database thử nghiệm **`hemis_sync`** trên máy proxywaf (10.39.4.4), trong container PostgreSQL `hemis-postgres` có sẵn. Database này dùng bộ schema của thầy (migration V1, V2, V3) và được nạp dữ liệu giả. Tất cả kiểm tra đều đạt.

| Hạng mục | Kết quả |
|---|---|
| Database mới | `hemis_sync`, **tách riêng**, không đụng database `hemis` mà ứng dụng Java đang dùng |
| Schema `hemis_sync` | 14 bảng: `api_log`, `catalog_diff`, `catalog_hemis`, `catalog_map`, `co_so_giao_duc`, `data_group`, `data_group_status`, `entity_map`, `sign_job`, `sync_batch`, `sync_error`, `sync_record`, `sync_watermark`, `validation_rule` |
| Schema `hemis_src` | 1 view `v_co_so_giao_duc` (34 cột, tên cột IN HOA đúng đặc tả HEMIS) và 2 hàm kiểm tra |
| Dữ liệu giả | 1 cơ sở giáo dục giả, 35 dòng danh mục (14 danh mục), 324 quy tắc kiểm tra cho 23 mảng của db3 Cán bộ (riêng `_CANBO_HOSO` có đủ 71 trường) |
| Dữ liệu V2 tự nạp | `data_group` 14 dòng, `data_group_status` 14 dòng |
| Kiểm tra sau khi nạp | `kiem_tra.sql`: **26/26 mục OK** ("TAT CA DAT") |
| Ảnh hưởng tới hệ thống có sẵn | So trước và sau: chỉ thêm **một** database `hemis_sync`. Database `hemis` giữ nguyên (schema `hemis_sync` của nó vẫn 15 bảng) |

## 2. Các việc đã làm

### 2.1 Chuẩn bị gói (trên laptop)
1. Chép nguyên văn 3 migration V1, V2, V3 của thầy (repo `Hemis-Platform`, commit `22b99be`). Không sửa nội dung.
2. Sinh dữ liệu giả **từ đặc tả**, không gõ tay:
   - quy tắc kiểm tra lấy từ `docs/spec/db3_doi_ngu.yaml`, tức file YAML trích từ đặc tả API HEMIS chính thức;
   - danh mục lấy từ dữ liệu mẫu của HEMIS giả lập (WireMock).
3. Gộp tất cả thành **một file** `goi_mot_file.sql`, chạy trong **một giao dịch**, nên lỗi ở bất kỳ đâu thì không để lại gì. File có khoá an toàn:
   - từ chối chạy nếu database hiện tại không phải `hemis_sync`;
   - từ chối nếu dữ liệu đã có sẵn, để tránh nhân đôi.
4. Viết `kiem_tra.sql`, gồm 26 kiểm tra **chỉ đọc**.
5. Chạy thử trên PostgreSQL 16 dùng một lần (Docker) trên laptop bằng `test.sh`: **66 OK / 0 FAIL**. Bộ test có cả các trường hợp từ chối: sai database, nạp lần hai, chạy nhầm vào `hemis`.

### 2.2 Đưa lên server (22/10/2026)
| Bước | Việc | Kết quả |
|---|---|---|
| 1 | Chép `goi_mot_file.sql`, `kiem_tra.sql` lên proxywaf (qua monitor-srv, vì SSH từ VPN bị tường lửa giới hạn) | Xong |
| 2 | Đối chiếu mã sha256 của 2 file | Khớp |
| 3 | Chụp danh sách database và số bảng của DB `hemis` trước khi nạp | Chưa có `hemis_sync`; `hemis.hemis_sync` có 15 bảng |
| 4 | `CREATE DATABASE hemis_sync` | `CREATE DATABASE` |
| 5 | Nạp `goi_mot_file.sql` | Không có lỗi. Chèn 14 + 14 + 1 + 35 + 324 dòng |
| 6 | Chạy `kiem_tra.sql` | 26/26 OK |
| 7 | So trước và sau (`diff`) | Chỉ khác dòng `> hemis_sync` |

## 3. Ghi chú kỹ thuật

- **Thông báo "Chua thiet lap ket noi toi HEMIS noi bo"** khi chạy V3 là bình thường. Kho `hemis_noi_bo` chưa có trên server nên V3 bỏ qua các view `v_can_bo`, `v_nguoi_hoc`; hàm `kiem_tra_ket_noi_noi_bo()` trả `CHUA_THIET_LAP`. Khi thầy đưa kho lên cần làm 2 việc:
  - chạy `db/setup/01_ket_noi_hemis_noi_bo.sql` (tạo kết nối `postgres_fdw`);
  - tạo lại các view của V3.
- **Không dùng Flyway** cho database thử nghiệm này: V1–V3 được áp bằng `psql`, nên không có bảng `flyway_schema_history`. Vì vậy `hemis_sync` có 14 bảng, còn DB `hemis` có 15.
- **Gỡ bỏ** (nếu cần) chỉ bằng một lệnh, không ảnh hưởng DB `hemis`:
  ```
  docker exec hemis-postgres psql -U hemis -d postgres -c "DROP DATABASE hemis_sync"
  ```
- Gói nằm ở `database/hemis_sync_thu_nghiem/` trên nhánh này. Mã sha256 của `goi_mot_file.sql`: `dcddcf8fc9a2b06ee26160336355aa5b1fd940ff21e4f4efb55069452d51d677`.

## 4. Các việc database đã làm trước đó (để thầy nắm)

| Mã | Việc | Trạng thái |
|---|---|---|
| D01 | Chuyển bảng trường db3 Cán bộ trong đặc tả API HEMIS thành YAML (`docs/spec/`), có script đếm và đối chiếu | Xong |
| D02 | Đối chiếu cột kho cũ ↔ trường HEMIS db3 (`docs/analysis/doi_chieu_can_bo.md` và 2 file CSV) | Xong |
| D07' / D07b | Dựng kho `hemis_noi_bo` **giả** trên laptop (cấu trúc theo tài liệu 09/10/11 của thầy, dữ liệu giả) để thử V3 và kết nối FDW | Xong, chờ thầy đưa kho thật lên server |
| D00 | Bản nháp hợp đồng dữ liệu DB ↔ Backend (`docs/contracts/HOP_DONG_DB_BE.md`) | Nháp, chờ họp với Backend |
| — | Gói câu hỏi cho thầy (`docs/de-xuat-thay/00_CAU_HOI_GOP.md`) | Chờ gửi |

## 5. Việc tiếp theo

1. Khi thầy đưa `hemis_noi_bo` lên: thiết lập kết nối FDW và tạo lại view V3, rồi kiểm tra `v_can_bo`, `v_nguoi_hoc`.
2. Mở rộng dữ liệu giả cho `catalog_map` và các view `hemis_src` của 21 mảng con db3, sau khi thống nhất với nhóm Backend.
3. Phân quyền (role chỉ đọc) và phương án sao lưu cho database platform.
