# hemis_sync — database thử nghiệm riêng, dữ liệu giả

Người thực hiện: Trần Tuấn Anh (nhóm Database). Đã nạp lên proxywaf ngày 22/10/2026.

## Mục đích

- Database **riêng** tên `hemis_sync`, cùng cụm PostgreSQL với database `hemis` trên proxywaf nhưng **không** đụng `hemis`.
- Chứa schema `hemis_sync` (14 bảng) và `hemis_src` (view `v_co_so_giao_duc`), tạo bằng chính V1, V2, V3 trong `src/main/resources/db/migration/` (commit `22b99be`), cùng **dữ liệu giả**.
- Dùng để thử bộ schema với dữ liệu giả mà không làm bẩn `hemis`.
- Dữ liệu giả: trường `TRUONG DAI HOC GIA LAP`, `https://example.test`, email `@example.test`, điện thoại `0000...`, mã tỉnh/xã `GIA-...`. Không có CCCD, không có tên người.
- **Không chạy qua Flyway**: V1–V3 được áp bằng `psql`, nên không có `flyway_schema_history`. Vì vậy `hemis_sync` có 14 bảng, còn DB `hemis` có 15.
- Kho `hemis_noi_bo` chưa có: V3 in `NOTICE ... BO QUA cac view doc tu ben do` và bỏ qua `v_can_bo`, `v_nguoi_hoc`. Đây là trạng thái bình thường; `kiem_tra_ket_noi_noi_bo()` trả `CHUA_THIET_LAP`.

> Thư mục này **không** nằm trong `db/migration` nên Flyway của ứng dụng không chạy nó.

## Có gì trong thư mục

| Đường dẫn | Việc |
|---|---|
| `goi_mot_file.sql` | Một file SQL, chạy trong **một giao dịch**: khối bảo vệ + `create schema` + V1 + V2 + V3 + seed giả. 86 755 byte, sha256 `dcddcf8fc9a2b06ee26160336355aa5b1fd940ff21e4f4efb55069452d51d677` |
| `kiem_tra.sql` | **Chỉ đọc.** 26 kiểm tra (OK/SAI); có SAI thì thoát khác 0. sha256 `dc305145d8518118fde2f505d9d2a45c02c02f2f5f7581b82f1be83aca268c5e` |
| `seed/01_du_lieu_gia.sql`, `seed/EXPECTED.json` | Phần seed giả (đã gộp sẵn trong `goi_mot_file.sql`) và số dòng kỳ vọng |
| `spec/db3_doi_ngu.yaml` | Bảng trường db3 Cán bộ trích từ đặc tả API HEMIS chính thức (23 mảng, `_CANBO_HOSO` 71 trường). Là nguồn sinh 324 dòng `validation_rule` |

## Dữ liệu giả

| Bảng | Dòng | Nguồn |
|---|---|---|
| `co_so_giao_duc` | 1 | trường giả, `hemis_id` = `ffffffff-0000-4000-8000-00000000a001` |
| `catalog_hemis` | 35 (14 danh mục) | dữ liệu mẫu danh mục của HEMIS giả lập |
| `validation_rule` | 324 (23 mảng) | `spec/db3_doi_ngu.yaml`: `ph='CANBO'`; `required` ← `bat_buoc` (213 dòng true); `max_length` chỉ với kiểu string (138 dòng); `catalog_name` ← `danh_muc` (48 dòng); `note` bắt đầu `GIA LAP` |

V2 tự nạp `data_group` 14 dòng và `data_group_status` 14 dòng. Các bảng còn lại rỗng.

## Cách dùng

Hướng dẫn đầy đủ từng bước: [`docs/database/He_data_instruction.md`](../../docs/database/He_data_instruction.md). Tóm tắt:

```bash
docker exec hemis-postgres psql -U hemis -d postgres -c "CREATE DATABASE hemis_sync"
docker exec -i hemis-postgres psql -U hemis -d hemis_sync -v ON_ERROR_STOP=1 -1 -f - < goi_mot_file.sql
docker exec -i hemis-postgres psql -U hemis -d hemis_sync -v ON_ERROR_STOP=1 -f - < kiem_tra.sql   # kỳ vọng: TAT CA DAT
```

Khối bảo vệ đầu file **từ chối** (DB không đổi) nếu database hiện tại không phải `hemis_sync`, hoặc `hemis_sync`/`hemis_src` đã có bảng/view.

Xoá (chỉ database này, không bao giờ `DROP` trên `hemis`):

```bash
docker exec hemis-postgres psql -U hemis -d postgres -c "DROP DATABASE hemis_sync"
```

## Lưu ý khi áp V1–V3 bằng tay

- Phải dùng `search_path = hemis_sync` (không có `public`). `goi_mot_file.sql` tự đặt.
- V2 có `DROP TABLE IF EXISTS entity_map;`. Với `search_path = hemis_sync` lệnh này chỉ chạm `hemis_sync.entity_map`.
- V3 dùng `CREATE OR REPLACE`, nên khi có `hemis_noi_bo` và đã chạy `db/setup/01_ket_noi_hemis_noi_bo.sql` thì chạy lại V3 để tạo `v_can_bo`, `v_nguoi_hoc`.

## Đã kiểm tra

- Trên PostgreSQL 16 dùng một lần (Docker): 66 kiểm tra đạt, gồm các trường hợp từ chối (sai database, nạp lần hai, chạy nhầm vào `hemis`).
- Trên proxywaf 22/10/2026: `kiem_tra.sql` 26/26 OK; so trước/sau chỉ thêm database `hemis_sync`, DB `hemis` không đổi.
