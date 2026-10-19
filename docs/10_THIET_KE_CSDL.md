# 10. Thiết kế cơ sở dữ liệu — lấy dữ liệu từ kho dữ liệu cũ

Tài liệu này giải thích **vì sao** thiết kế như vậy. Cấu trúc cụ thể nằm trong
`src/main/resources/db/migration/V2__bo_sung_hemis_sync.sql` và `V3__hemis_src_views.sql`.

---

## 1. Hiện trạng kho dữ liệu cũ (HEMIS-DWH-Database)

| Đặc điểm | Thực tế | Hệ quả với thiết kế |
| --- | --- | --- |
| Schema | Tất cả nằm trong `public`, không tách schema | Cổng tích hợp phải dùng schema riêng để không lẫn |
| Đặt tên | Bảng và cột PascalCase tiếng Việt: `CanBo.SoCCCD`, `NguoiHoc.HoVaTen` | Phải đổi sang tên trường theo đặc tả của Bộ |
| Khóa chính | `ID SERIAL` ở toàn bộ 253 bảng | **Không dùng làm khóa gửi HEMIS** — xem mục 3 |
| Cột thời gian | `CreatedAt TIMESTAMP`, `UpdatedAt TIMESTAMP NULL` ở toàn bộ bảng | Trích xuất gia tăng được, nhưng phải xử lý `NULL` — xem mục 5 |
| Mã danh mục | `DM_GioiTinh.Ma = '01'`, `DM_DanToc.Ma = 55` — trùng mã HEMIS | Ánh xạ theo ngoại lệ, không khai báo từng mã — xem mục 6 |
| Kiểu mã danh mục | Không nhất quán: `VARCHAR(2)`, `VARCHAR(10)`, `INT` | View phải ép về `text` |
| Triển khai | GitHub Actions chạy `reset_all.sql` — **xóa và tạo lại toàn bộ** | Khóa `SERIAL` thay đổi sau mỗi lần nạp lại — xem mục 3 |
| Khóa tự nhiên | `NguoiHoc.SoCCCD` và `CanBo.SoCCCD` có ràng buộc `UNIQUE` | Dùng làm khóa nghiệp vụ |

---

## 2. Vấn đề phát hiện: thiếu bảng thông tin chung của Trường

Module `co_so_giao_duc` của kho dữ liệu có 13 bảng con — `BanGiamHieu`, `HoiDongTruong`,
`VanBanTuChu`, `ThongTinKiemDinh_CSGD`, `LichSuDoiTenTruong`… — nhưng **không có bảng nào
lưu thông tin chung của chính Trường**: `MA_DON_VI`, `TEN_DON_VI`, `WEBSITE`,
`SO_QD_THANH_LAP`, `LOAI_HINH_ID`, `TINH_THANH_NEW`, `MA_DINH_DANH_ND69`…

Đây chính là nội dung bắt buộc của mảng `_CO_SO_GIAO_DUC` trong API `db1` — phân hệ được
chọn làm **thí điểm của Giai đoạn 1**. Không có dữ liệu này thì không chạy được thí điểm.

**Hai phương án:**

| | Phương án A — bổ sung vào kho dữ liệu | Phương án B — đặt tạm ở `hemis_sync` |
| --- | --- | --- |
| Cách làm | Nhóm DWH tạo `public.CoSoGiaoDuc` | Cổng tích hợp tự quản lý bảng `hemis_sync.co_so_giao_duc` |
| Đúng về kiến trúc | Có — đây là dữ liệu nghiệp vụ | Không — dữ liệu nghiệp vụ nằm ngoài kho |
| Thời gian | Phụ thuộc nhóm khác, chưa chắc kịp | Làm ngay |
| Rủi ro | Chậm tiến độ Giai đoạn 1 | Nợ kỹ thuật |

**Chọn phương án B**, có điều kiện: ghi nhận là nợ kỹ thuật, khi kho dữ liệu bổ sung bảng
thì chỉ cần sửa view `hemis_src.v_co_so_giao_duc`, mã nguồn Java không đổi. Đồng thời gửi
đề nghị bổ sung cho nhóm DWH ngay trong tuần này.

Bảng chỉ có **đúng một dòng** (ràng buộc `CHECK (id = 1)`), nhập một lần, do Phòng Tổ chức –
Hành chính cung cấp số liệu.

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

## 4. Ba schema, ba vai trò

```
┌──────────────────────────────────────────────────────────────┐
│  public          KHO DU LIEU HIEN CO (DWH)                   │
│                  253 bang, nhom khac phat trien              │
│                  Cong tich hop CHI DOC, khong ghi            │
└────────────────────────────┬─────────────────────────────────┘
                             │  (chi doc)
┌────────────────────────────▼─────────────────────────────────┐
│  hemis_src       LOP HOP DONG - CHI CHUA VIEW                │
│                  v_co_so_giao_duc, v_can_bo, v_nguoi_hoc     │
│                  Ten cot = ten truong theo dac ta cua Bo     │
└────────────────────────────┬─────────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────────┐
│  hemis_sync      VUNG LAM VIEC CUA CONG TICH HOP             │
│                  entity_map, catalog_*, sync_*, data_group_* │
│                  co_so_giao_duc (tam)                        │
└──────────────────────────────────────────────────────────────┘
```

### Vì sao phải có `hemis_src` thay vì truy vấn thẳng bảng

| Nếu truy vấn thẳng `public.CanBo` | Nếu qua `hemis_src.v_can_bo` |
| --- | --- |
| Nhóm DWH đổi tên cột → ứng dụng Java vỡ, phải sửa và biên dịch lại | Chỉ sửa view, Java không đụng tới |
| Tên cột tiếng Việt lẫn trong mã Java, khó đối chiếu với đặc tả | Tên cột đã là tên trường của Bộ, đọc view là đối chiếu được ngay |
| Mỗi lập trình viên tự viết truy vấn, dễ lệch nhau | Một chỗ duy nhất định nghĩa cách đọc |
| Khó kiểm thử nếu không có kho dữ liệu | Thay view bằng view giả là chạy được |

**Quy tắc bắt buộc của nhóm**: không có câu lệnh SQL nào trong mã Java được nhắc tới
`public.` — nếu thấy, trả lại khi rà soát mã.

### Xử lý khi máy phát triển không có kho dữ liệu

Migration `V3` tự kiểm tra bằng `to_regclass('public.CanBo')`. Không thấy thì bỏ qua các
view đọc từ DWH và in một dòng thông báo — không báo lỗi. Nhờ vậy sinh viên chạy
`docker compose up` trên máy cá nhân vẫn khởi động được ứng dụng.

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
| Kho dữ liệu ở máy chủ riêng | Hiện cùng một máy chủ | Khi tách máy chủ: dùng `postgres_fdw` hoặc bản sao chỉ đọc, view giữ nguyên |
| Chỉ mục phục vụ delta | Dữ liệu còn nhỏ | Khi phân hệ người học chạy thật |
