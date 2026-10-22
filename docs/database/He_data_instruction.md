# He_data_instruction — Hướng dẫn đưa database thử nghiệm `hemis_sync` lên proxywaf

| | |
|---|---|
| **Dùng cho** | Người được giao nạp dữ liệu thử nghiệm lên proxywaf (10.39.4.4) |
| **Kết quả** | Database riêng `hemis_sync` (schema `hemis_sync` + `hemis_src`, migration V1–V3 của thầy, dữ liệu giả) |
| **Không đụng** | Database `hemis` mà ứng dụng Java đang dùng |
| **Thời gian** | Khoảng 10 phút |
| **Đã chạy thật** | 22/10/2026, tất cả kiểm tra đạt |

## 0. Chuẩn bị

- Gói nằm ở `database/hemis_sync_thu_nghiem/`. Chỉ cần 2 file:
  - `goi_mot_file.sql`, sha256 `dcddcf8fc9a2b06ee26160336355aa5b1fd940ff21e4f4efb55069452d51d677`;
  - `kiem_tra.sql`, sha256 `dc305145d8518118fde2f505d9d2a45c02c02f2f5f7581b82f1be83aca268c5e`.
- Tài khoản SSH `nckh` trên proxywaf, và khoá hoặc mật khẩu do thầy cấp.
- **Ở trường** (mạng `10.39.4.x`): SSH thẳng vào proxywaf.
- **Ở nhà qua OpenVPN**: tường lửa proxywaf chỉ nhận SSH từ `10.39.4.0/24`, nên SSH thẳng sẽ báo *Connection timed out*. Phải nhảy qua monitor-srv bằng `-J coreteam@10.39.4.7`.
- Không cần `sudo`. Không cài thêm gì trên server.

## 1. Chép file lên server (PowerShell trên laptop)

Ở nhà (qua VPN):
```powershell
scp -J coreteam@10.39.4.7 -i <duong-dan-khoa> <thu-muc-repo>\database\hemis_sync_thu_nghiem\goi_mot_file.sql <thu-muc-repo>\database\hemis_sync_thu_nghiem\kiem_tra.sql nckh@10.39.4.4:~/
```
Ở trường: bỏ phần `-J coreteam@10.39.4.7`.

## 2. Vào server
```powershell
ssh -J coreteam@10.39.4.7 -i <duong-dan-khoa> nckh@10.39.4.4
```

## 3. Kiểm tra file
```bash
cd ~ && sha256sum goi_mot_file.sql kiem_tra.sql
```
Hai mã phải khớp với mục 0. Không khớp thì **dừng** và chép lại.

## 4. Chụp trạng thái trước khi nạp
```bash
docker exec hemis-postgres psql -U hemis -d postgres -Atc "select datname from pg_database order by 1" | tee ~/truoc.txt
docker exec hemis-postgres psql -U hemis -d hemis -Atc "select schemaname, count(*) from pg_tables group by 1 order by 1" | tee -a ~/truoc.txt
```
Danh sách in ra phải **chưa có** `hemis_sync`. Nếu đã có, xem mục 9.

## 5. Tạo database riêng
```bash
docker exec hemis-postgres psql -U hemis -d postgres -c "CREATE DATABASE hemis_sync"
```
Kết quả đúng: `CREATE DATABASE`.

## 6. Nạp gói (một giao dịch)
```bash
docker exec -i hemis-postgres psql -U hemis -d hemis_sync -v ON_ERROR_STOP=1 -1 -f - < goi_mot_file.sql
```
Kết quả đúng là không có dòng `ERROR`, và cuối cùng là:
```
INSERT 0 1
INSERT 0 35
INSERT 0 324
```
Dòng `NOTICE: Chua thiet lap ket noi toi HEMIS noi bo - BO QUA ...` là **bình thường**: kho `hemis_noi_bo` chưa có.

Mất kết nối giữa chừng thì cũng không hỏng gì, vì giao dịch tự huỷ. Vào lại rồi chạy lại đúng lệnh ở mục 6, không cần tạo lại database.

## 7. Kiểm tra sau khi nạp (chỉ đọc)
```bash
docker exec -i hemis-postgres psql -U hemis -d hemis_sync -v ON_ERROR_STOP=1 -f - < kiem_tra.sql
```
Kết quả đúng: 26 dòng `NOTICE: OK ...`, kết thúc bằng `kiem_tra.sql: TAT CA DAT`. Có dòng `SAI` thì lệnh thoát với lỗi; khi đó chụp lại kết quả và xem mục 9.

## 8. So trước và sau
```bash
docker exec hemis-postgres psql -U hemis -d postgres -Atc "select datname from pg_database order by 1" > ~/sau.txt
docker exec hemis-postgres psql -U hemis -d hemis -Atc "select schemaname, count(*) from pg_tables group by 1 order by 1" >> ~/sau.txt
diff ~/truoc.txt ~/sau.txt
```
Kết quả đúng chỉ có đúng một dòng khác:
```
1a2
> hemis_sync
```
Nếu số bảng của DB `hemis` thay đổi, **dừng lại và báo thầy**.

## 9. Gỡ bỏ hoặc nạp lại

Lệnh xoá dưới đây chỉ xoá database thử nghiệm, không đụng DB `hemis`:
```bash
docker exec hemis-postgres psql -U hemis -d postgres -c "DROP DATABASE hemis_sync"
```
Muốn nạp lại thì chạy lại từ mục 5. Gói tự từ chối khi:
- database hiện tại không phải `hemis_sync`;
- dữ liệu đã có sẵn (để tránh nhân đôi).

## 10. Dọn sau khi xong (tuỳ chọn)
```bash
rm ~/goi_mot_file.sql ~/kiem_tra.sql ~/truoc.txt ~/sau.txt
```

## 11. Khi thầy đưa kho `hemis_noi_bo` lên (làm sau)

1. Thầy (hoặc người có quyền quản trị PostgreSQL) chạy `db/setup/01_ket_noi_hemis_noi_bo.sql` của repo platform trên database `hemis_sync` để tạo kết nối `postgres_fdw`.
2. Tạo lại các view của V3: chạy lại `V3` với `PGOPTIONS='-c search_path=hemis_sync'`.
3. Kiểm tra: `select * from hemis_sync.kiem_tra_ket_noi_noi_bo();` phải trả `OK`, và `hemis_src.v_can_bo`, `hemis_src.v_nguoi_hoc` phải có dữ liệu.
