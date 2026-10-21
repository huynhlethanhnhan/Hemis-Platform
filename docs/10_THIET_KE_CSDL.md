# 10. Thiết kế cơ sở dữ liệu — lấy dữ liệu từ kho dữ liệu cũ

Tài liệu này giải thích **vì sao** thiết kế như vậy. Cấu trúc cụ thể nằm trong
`src/main/resources/db/migration/V2__bo_sung_hemis_sync.sql` và `V3__hemis_src_views.sql`.

---

## 1. Hiện trạng HEMIS nội bộ (database `hemis_noi_bo`, mã nguồn HEMIS-DWH-Database)

| Đặc điểm | Thực tế | Hệ quả với thiết kế |
| --- | --- | --- |
| Vị trí | Là một **database riêng** (`hemis_noi_bo`), toàn bộ bảng trong schema `public` | Phải kết nối liên database, không truy vấn chéo schema được |
| Đặt tên | Bảng và cột PascalCase tiếng Việt: `CanBo.SoCCCD`, `NguoiHoc.HoVaTen` | Phải đổi sang tên trường theo đặc tả của Bộ |
| Khóa chính | `ID SERIAL` ở 253 bảng nghiệp vụ/danh mục hiện hữu; các bảng bổ sung dùng `BIGSERIAL` khi cần | **Không dùng làm khóa gửi HEMIS** — xem mục 3 |
| Cột thời gian | `CreatedAt TIMESTAMP`, `UpdatedAt TIMESTAMP NULL` ở toàn bộ bảng | Trích xuất gia tăng được, nhưng phải xử lý `NULL` — xem mục 5 |
| Mã danh mục | `DM_GioiTinh.Ma = '01'`, `DM_DanToc.Ma = 55` — trùng mã HEMIS | Ánh xạ theo ngoại lệ, không khai báo từng mã — xem mục 6 |
| Kiểu mã danh mục | Không nhất quán: `VARCHAR(2)`, `VARCHAR(10)`, `INT` | View phải ép về `text` |
| Triển khai | GitHub Actions chạy `reset_all.sql` — **xóa và tạo lại toàn bộ** | Khóa `SERIAL` thay đổi sau mỗi lần nạp lại — xem mục 3 |
| Khóa tự nhiên | `NguoiHoc.SoCCCD` và `CanBo.SoCCCD` có ràng buộc `UNIQUE` | Dùng làm khóa nghiệp vụ |

---

## 2. Vấn đề phát hiện: thiếu bảng thông tin chung của Trường

Module `co_so_giao_duc` của kho dữ liệu có 13 bảng con và bảng thông tin chung bổ sung — `BanGiamHieu`, `HoiDongTruong`,
`VanBanTuChu`, `ThongTinKiemDinh_CSGD`, `LichSuDoiTenTruong`… — nhưng **không có bảng nào
lưu thông tin chung của chính Trường**: `MA_DON_VI`, `TEN_DON_VI`, `WEBSITE`,
`SO_QD_THANH_LAP`, `LOAI_HINH_ID`, `TINH_THANH_NEW`, `MA_DINH_DANH_ND69`…

**Cập nhật schema ngày 21/10/2026:** bảng `CoSoGiaoDuc` đã được bổ sung vào kho dữ liệu
PostgreSQL với khóa nghiệp vụ `MaDonVi`; vì vậy phần thiếu bảng thông tin chung không còn
là blocker của schema. `hemis_sync.co_so_giao_duc` vẫn được giữ để tương thích dữ liệu
chuyển tiếp của platform và chỉ được dùng theo contract migration tương ứng.

Đây chính là nội dung bắt buộc của mảng `_CO_SO_GIAO_DUC` trong API `db1` — phân hệ được
chọn làm **thí điểm của Giai đoạn 1**. Nguồn dữ liệu nghiệp vụ chuẩn hiện là
`public.cosogiaoduc`, khóa nghiệp vụ `MaDonVi` và có thể lưu một bản ghi cho mỗi đơn vị.

`hemis_sync.co_so_giao_duc` vẫn được giữ ở database tích hợp để phục vụ dữ liệu chuyển tiếp
và kiểm thử độc lập. Bảng staging này có ràng buộc một dòng (`id = 1`) theo contract bàn giao
Giai đoạn 1; nó không thay thế bảng nguồn `public.cosogiaoduc`. Khi cấu hình đọc qua FDW,
`hemis_src.v_co_so_giao_duc` phải đọc nguồn DWH hoặc lớp view tương thích, còn fallback
staging chỉ dùng khi chưa có kết nối nguồn.

---

## 3. Định danh gửi HEMIS: khóa nghiệp vụ, không phải khóa tự tăng

Đây là quyết định thiết kế quan trọng nhất, và là chỗ dễ sai nhất.

HEMIS dùng trường `Id` (GUID) để quyết định **thêm mới hay cập nhật** bản ghi. GUID của một
người phải không đổi qua mọi đợt gửi.

Kho dữ liệu dùng `ID SERIAL`, và được triển khai bằng `reset_all.sql` (xóa, tạo lại). Nghĩa là:

```
Lần nạp 1:  Nguyễn Văn A -> ID = 157
Lần nạp 2:  Nguyễn Văn A -> ID = 203   (thứ tự nạp khác đi)
```

Nếu ánh xạ GUID theo `ID` thì sau lần nạp thứ hai, cùng một người sẽ mang GUID khác →
HEMIS coi là người mới → **dữ liệu bị nhân đôi trên hệ thống của Bộ, không gỡ lại được**.

Vì vậy `entity_map` khóa theo **khóa nghiệp vụ**:

```
entity_map (entity_type, business_key) -> hemis_id
             CAN_BO       SoCCCD          GUID cố định
             NGUOI_HOC    SoCCCD          GUID cố định
             CHUONG_TRINH_DT  MaChuongTrinhDaoTao
```

Cột `first_sent_at`: đã có giá trị nghĩa là GUID này HEMIS đã biết — từ đó trở đi tuyệt đối
không được đổi.

> Hệ quả: bản ghi **thiếu số căn cước công dân thì không gửi được**, vì không có khóa nghiệp
> vụ. Đây là lý do kỹ thuật để ưu tiên chiến dịch làm sạch CCCD, không chỉ vì đặc tả yêu cầu.

---

## 4. Hai database, ba schema

**HEMIS nội bộ và `hemis-platform` là hai database riêng biệt.** Đây là ranh giới quan trọng
nhất của thiết kế: một bên là nơi các đơn vị nhập và làm sạch dữ liệu, một bên là nơi đóng gói
và gửi lên Bộ. Hai việc có vòng đời, quyền truy cập và mức rủi ro khác nhau.

```
   DATABASE "hemis_noi_bo"                DATABASE cua hemis-platform
   ───────────────────────                ───────────────────────────

   public.*                               hemis_noi_bo.*
   253 bang nghiep vu      ◄── fdw ────   bang ngoai, CHI DOC
   Don vi trong truong                    (tao boi db/setup/01_...)
   nhap lieu, lam sach                            │
   Nhom DWH phat trien                            ▼
                                          hemis_src.*
                                          LOP HOP DONG - chi chua VIEW
                                          Ten cot = ten truong cua Bo
                                                   │
                                                   ▼
                                          hemis_sync.*
                                          entity_map, catalog_*, sync_*,
                                          data_group_*, co_so_giao_duc
```

| Database | Ai sở hữu | Ghi được? | Chứa gì |
| --- | --- | --- | --- |
| `hemis_noi_bo` | Nhóm phát triển HEMIS nội bộ | Các đơn vị trong Trường ghi | 253 bảng nghiệp vụ hiện hữu + bảng bổ sung theo migration |
| `hemis-platform` | Phòng Công nghệ thông tin | Chỉ cổng tích hợp ghi | Vùng làm việc đồng bộ |

### Vì sao tách hai database

| | Nếu chung một database | Tách hai database (chọn) |
| --- | --- | --- |
| Quyền | Cổng tích hợp có quyền trên cùng database người dùng đang ghi | Cổng tích hợp chỉ có tài khoản **chỉ đọc** sang bên kia |
| Sự cố | Nhập liệu nặng làm chậm cả việc đồng bộ | Hai bên độc lập |
| Triển khai | Phải đồng bộ lịch nâng cấp của hai nhóm | Mỗi bên nâng cấp riêng |
| Bảo mật dữ liệu cá nhân | Toàn bộ dữ liệu cá nhân nằm chung chỗ với tệp gửi đi | Giới hạn được phạm vi truy cập |
| Nhược điểm | — | Phải thiết lập kết nối liên database, truy vấn chậm hơn |

### Kết nối giữa hai database

Dùng `postgres_fdw` — trình kết nối cơ sở dữ liệu ngoài có sẵn của PostgreSQL. Bảng bên
HEMIS nội bộ hiện ra như bảng thường trong schema `hemis_noi_bo`, nhưng chỉ đọc.

Thiết lập **một lần** bằng `db/setup/01_ket_noi_hemis_noi_bo.sql`, **không** chạy qua Flyway vì:

- cần quyền `superuser` để tạo extension;
- chứa mật khẩu kết nối, không được đưa vào kho mã nguồn;
- địa chỉ máy chủ khác nhau ở mỗi môi trường.

Phía HEMIS nội bộ tạo một tài khoản riêng `hemis_reader` **chỉ có quyền SELECT**. Cổng tích
hợp không bao giờ ghi sang bên đó.

### Phương án thay thế nếu không dùng được `postgres_fdw`

| Phương án | Khi nào dùng | Đánh đổi |
| --- | --- | --- |
| `postgres_fdw` (chọn) | Hai database thông mạng, được bật extension | Truy vấn qua mạng chậm hơn; HEMIS nội bộ dừng thì view lỗi |
| Nguồn dữ liệu thứ hai trong ứng dụng | Không được bật extension | Phải viết thêm mã sao chép; `hemis_src` thành bảng tạm thay vì view |
| Nhân bản logic (logical replication) | Dữ liệu lớn, cần đọc nhiều | Phải cấu hình bên HEMIS nội bộ; trễ vài giây |
| Xuất tệp định kỳ | Hai bên không thông mạng | Rời rạc nhất, khó bảo đảm đúng hạn |

Cả bốn phương án đều **giữ nguyên lớp `hemis_src`**, nên đổi phương án không phải sửa mã Java.

### Vì sao phải có `hemis_src` thay vì truy vấn thẳng bảng

| Nếu truy vấn thẳng `hemis_noi_bo.canbo` | Nếu qua `hemis_src.v_can_bo` |
| --- | --- |
| Nhóm DWH đổi tên cột → ứng dụng Java vỡ, phải sửa và biên dịch lại | Chỉ sửa view, Java không đụng tới |
| Tên cột tiếng Việt lẫn trong mã Java, khó đối chiếu với đặc tả | Tên cột đã là tên trường của Bộ, đọc view là đối chiếu được ngay |
| Mỗi lập trình viên tự viết truy vấn, dễ lệch nhau | Một chỗ duy nhất định nghĩa cách đọc |
| Khó kiểm thử nếu không có kho dữ liệu | Thay view bằng view giả là chạy được |

**Quy tắc bắt buộc của nhóm**: không có câu lệnh SQL nào trong mã Java được nhắc tới
`hemis_noi_bo.` — nếu thấy, trả lại khi rà soát mã. Chỉ `hemis_src.*` được phép.

### Xử lý khi máy phát triển không có kho dữ liệu

Migration `V3` tự kiểm tra bằng `to_regclass('hemis_noi_bo.canbo')`. Chưa thiết lập kết nối
thì bỏ qua các view đọc từ HEMIS nội bộ và in một dòng thông báo — không báo lỗi. Nhờ vậy
sinh viên chạy `docker compose up` trên máy cá nhân vẫn khởi động được ứng dụng.

Hàm `hemis_sync.kiem_tra_ket_noi_noi_bo()` cho biết kết nối đang ở trạng thái nào; gắn vào
điểm kiểm tra sức khỏe để HEMIS nội bộ tạm dừng không làm sập cổng tích hợp.

---

## 5. Trích xuất gia tăng — một cái bẫy

Cột `UpdatedAt` trong kho dữ liệu **cho phép NULL** (bản ghi chưa từng được sửa). Truy vấn
delta viết theo phản xạ sẽ sai:

```sql
-- SAI: bỏ sót toàn bộ bản ghi chưa từng được cập nhật
WHERE UpdatedAt > :moc

-- ĐÚNG
WHERE COALESCE(UpdatedAt, CreatedAt) > :moc
```

View `hemis_src.*` đã tính sẵn cột `delta_ts = COALESCE(UpdatedAt, CreatedAt)` để không ai
phải nhớ quy tắc này. Mốc lưu ở bảng `sync_watermark` theo từng phân hệ.

Giai đoạn 1 có thể gửi toàn bộ (phân hệ thí điểm chỉ có 1 bản ghi); cơ chế delta cần cho
phân hệ người học và đội ngũ ở giai đoạn sau.

---

## 6. Ánh xạ danh mục theo ngoại lệ

Kho dữ liệu đã được mô hình hóa theo chuẩn HEMIS nên **phần lớn mã đã trùng**:

```
DM_GioiTinh.Ma = '01'  <->  HEMIS GIOI_TINH_ID = '01'   ✔
DM_DanToc.Ma   = 55    <->  HEMIS DAN_TOC_ID   = '55'   ✔ (khác kiểu, phải ép text)
```

Vì vậy **không khai báo ánh xạ cho từng mã** (hơn 175 danh mục, hàng chục nghìn dòng).
Thay vào đó:

| `strategy` | Ý nghĩa |
| --- | --- |
| `IDENTITY` | Mặc định — mã nội bộ dùng thẳng làm mã HEMIS |
| `MAPPED` | Có ánh xạ riêng, khai trong `catalog_map.hemis_code` |
| `MISSING` | Chưa có mã HEMIS tương ứng — **lỗi mức chặn**, phải xử lý trước khi gửi |

Bảng `catalog_diff` lưu kết quả đối chiếu tự động giữa danh mục của kho dữ liệu và danh mục
tải về từ HEMIS. Chạy lại sau mỗi lần tải danh mục; chỉ những dòng `CHI_CO_DWH` hoặc
`LECH_TEN` mới cần người xem.

> Chưa có trong kho dữ liệu: `DM_TINH_NEW`, `DM_XA_NEW` (địa giới theo Quyết định
> 19/2025/QĐ-TTg). Các cột `*_NEW` trong view đang trả `NULL` kèm ghi chú `TODO`. Đây là
> khoảng trống bắt buộc phải lấp — xem nhiệm vụ SV1-04.

---

## 7. Theo dõi Bảng 1C (Thông tư 83/2026)

Hai bảng `data_group` (14 nhóm, nạp sẵn) và `data_group_status` (trạng thái theo kỳ đánh giá)
cho phép sinh thẳng Bảng 1C mà không tổng hợp tay.

Chỉ hai cột nhập tay: `bat_buoc` và `ngay_phai_cap_nhat`. Còn lại tính tự động:

| Cột Bảng 1C | Tính từ đâu |
| --- | --- |
| Ngày cập nhật thực tế | Đợt đồng bộ thành công gần nhất của phân hệ (`sync_batch.sent_at`) |
| Đúng hạn | So `ngay_cap_nhat_thuc_te` với `ngay_phai_cap_nhat` |
| Đầy đủ (%) | `so_truong_dat / so_truong_bat_buoc` từ kết quả kiểm tra |
| Tin cậy (%) | Tỷ lệ bản ghi không có lỗi mức `WARN` |
| Đạt điều kiện | Đúng hạn **và** đầy đủ = 100% |

Hạn nội bộ đặt **15/12/2026**, sớm hơn hạn của Bộ 15 ngày, để còn thời gian đối soát và
khắc phục. Riêng hai nhóm tài chính `B4A`, `B6B` đặt 15/3/2027.

Cột `ph` của ba nhóm `B1B`, `B3D` để `NULL` vì chưa có phân hệ API tương ứng — xem
RÀNG BUỘC-09 trong [08_SRS.md](08_SRS.md).

---

## 8. Những gì cố ý chưa làm

| Hạng mục | Lý do | Khi nào |
| --- | --- | --- |
| View cho 9 phân hệ còn lại | Giai đoạn 1 chỉ thí điểm 1 phân hệ | Theo tiến độ từng phân hệ |
| Hàm `kiem_tra_khoang_trong` | Mới là khung, cần `validation_rule` đầy đủ trước | Nhiệm vụ SV2-03 |
| Ảnh chụp dữ liệu theo kỳ | Tệp `payload.json` đã lưu, đủ làm minh chứng cho Giai đoạn 1 | Giai đoạn 2 |
| Nhân bản dữ liệu về cục bộ | `postgres_fdw` đọc trực tiếp đủ dùng ở quy mô hiện nay | Khi phân hệ người học chạy thật, nếu chậm thì chuyển sang nhân bản logic |
| Chỉ mục phục vụ delta | Dữ liệu còn nhỏ | Khi phân hệ người học chạy thật |
