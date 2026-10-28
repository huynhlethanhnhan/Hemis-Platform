# Nạp thử trên dev-srv (28/10/2026)

Người thực hiện: Trần Tuấn Anh (nhóm Database).
Máy: dev-srv 10.39.4.8 (máy demo nội bộ), container `hemis-postgres`, database `hemis_sync`.
**Không đụng `hemis_noi_bo`.**

## 1. Ứng dụng nạp file YAML quy tắc (FR-VAL-01)

Chạy ứng dụng nhánh `FR-VAL-01` (commit `5987d3a`, "cải tiến module nạp rule qua file yml") bằng tài khoản `hemis_sync_app`, cổng 18080:

```bash
export DB_URL=jdbc:postgresql://<ip-container>:5432/hemis_sync DB_USER=hemis_sync_app APP_PORT=18080
./mvnw -DskipTests spring-boot:run
```

Kết quả:

- Flyway tạo schema `hemis_sync`, chạy V1, V2, V3 thành công. V3 bỏ qua các view đọc từ HEMIS nội bộ, vì dev-srv chưa nối FDW. Đây là trạng thái bình thường.
- Log: `Imported 34 validation rules from cosogiaoduc.yml`, `Total rules imported: 34`.

Kiểm tra bằng `kiem_tra_sau_nap_yaml.sql`. File này **chỉ đọc**, cuối file có `ROLLBACK`.

```bash
docker exec -i hemis-postgres psql -U postgres -d hemis_sync -f - < kiem_tra_sau_nap_yaml.sql
```

| Mục | Kết quả |
|---|---|
| Flyway V1–V3 | thành công |
| Quy tắc theo `ph`/`entity` | `COSOGIAODUC` / `_CO_SO_GIAO_DUC`: 34 trường, 19 bắt buộc |
| `data_type` ngoài 6 kiểu mà `RecordValidator` hiểu | không có |
| `catalog_name` chưa có trong `catalog_hemis` | không có (`cosogiaoduc.yml` không dùng danh mục). Lưu ý: `catalog_hemis` đang trống |
| CANBO (db3) | chưa có file YAML; theo đặc tả còn thiếu 23 mảng / 324 trường |

## 2. Nạp thử dữ liệu Excel thật của Bộ vào `hemis_sync`

Theo yêu cầu của thầy: đưa file dữ liệu thật vào `hemis_sync` để xem có nạp được không. Nếu Excel có dữ liệu thừa so với database thì đề xuất cập nhật database.

- Nguồn: `Export_Doi_Ngu_*.xlsx` (db3, 22 sheet) và `Export_CoSoGiaoDuc_*.xlsx` (db1, 9 sheet). Bỏ qua sheet `HuongDan` và `Danh mục`.
- Đích: schema riêng **`nap_thu`**, không phải schema `hemis_sync` của ứng dụng, nên Flyway không bị ảnh hưởng.
  - `nap_thu.excel_sheet`: mỗi sheet một dòng (tên cột, số dòng).
  - `nap_thu.excel_dong`: mỗi dòng Excel thành một bản ghi `jsonb {tiêu đề cột: giá trị}`, giữ **mọi** cột.

| File | Việc |
|---|---|
| `gen_nap_excel_that.py` | Sinh `nap_excel_that.sql` từ file Excel. Chạy trên máy có file; cần `openpyxl` |
| `nap_excel_that.sql` | **Không có trong git** (`.gitignore`), vì chứa dữ liệu cá nhân thật. Chỉ chép lên dev-srv để nạp, xong thì xoá |
| `bao_cao_nap_excel.sql` | **Chỉ đọc.** Báo cáo số dòng Excel so với số dòng vào DB, cột luôn trống, tiêu đề cột từng sheet. Không in giá trị dữ liệu |

```bash
python -I gen_nap_excel_that.py --out nap_excel_that.sql Export_Doi_Ngu_*.xlsx Export_CoSoGiaoDuc_*.xlsx
docker exec -i hemis-postgres psql -q -U postgres -d hemis_sync -v ON_ERROR_STOP=1 -1 -f - < nap_excel_that.sql
docker exec -i hemis-postgres psql -U postgres -d hemis_sync -f - < bao_cao_nap_excel.sql
```

`nap_excel_that.sql` chạy trong một giao dịch và chạy lại được: dòng cũ của cùng file bị xoá trước khi nạp lại. Bản sinh ngày 28/10 có 333 dòng, gồm 179 dòng đội ngũ và 154 dòng CSGD.

Dọn dữ liệu thử:

```bash
docker exec hemis-postgres psql -U postgres -d hemis_sync -c "DROP SCHEMA nap_thu CASCADE"
```

**Kết quả nạp:** _(cập nhật sau khi chạy trên dev-srv)_

## Việc tiếp theo

- Đối chiếu tiêu đề cột Excel với trường HEMIS trong `../spec/db3_doi_ngu.yaml`, để ra danh sách cột thừa, trường thiếu và đề xuất cập nhật database.
- Nạp `catalog_hemis` (danh mục) để kiểm tra được `catalog_name`.
