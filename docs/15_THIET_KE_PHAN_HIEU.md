# 15. Thiết kế lại cho trường có nhiều phân hiệu

| | |
| --- | --- |
| **Ngày** | 12/11/2026 |
| **Lý do** | Trường có nhiều phân hiệu, mỗi phân hiệu phải có số liệu riêng |
| **Thay đổi** | `V4__phan_hieu.sql` + điều chỉnh bộ trích xuất + bổ sung cột ở kho dữ liệu |

---

## 1. Kết luận trước khi đọc chi tiết

Tôi đã rà cả ba nguồn. Kết quả:

| Nguồn | Có khái niệm phân hiệu không? |
| --- | --- |
| **Thông tư 83/2026/TT-BGDĐT** | **Có, rất nhiều** — hơn 20 chỗ nhắc tới, có điều khoản riêng |
| **Đặc tả API của Bộ (v2.0)** | **Không có.** Chỉ có `DON_VI_ID` (136 lần), không có trường nào tên phân hiệu |
| **Kho dữ liệu của Trường** | **Không có.** Không bảng nào, cột nào |

Nghĩa là: quy định bắt tách số liệu theo phân hiệu, nhưng **cả API lẫn kho dữ liệu đều chưa
mô hình hóa được**. Đây là khoảng trống thật, phải bổ sung.

---

## 2. Thông tư 83 yêu cầu gì

**Điều 9 khoản 2** là điều khoản quyết định cách thiết kế:

> "**Không đánh giá, kết luận mức độ đáp ứng Chuẩn riêng** đối với phân hiệu và các trường
> thuộc. Dữ liệu của phân hiệu và các trường thuộc **được tổng hợp vào kết quả đánh giá chung**
> của cơ sở đào tạo. Đối với các chỉ số cần xác định theo địa điểm tổ chức đào tạo hoặc kết quả
> hoạt động tại phân hiệu, **kết quả được xác định riêng đối với từng phân hiệu và đồng thời
> được tổng hợp** để xác định kết quả chung của cơ sở đào tạo."

**Phụ lục V**:

> "Đối với chỉ số được quy định tại Mục II phải xác định riêng đối với từng phân hiệu,
> **biểu mẫu tương ứng được lập riêng cho toàn cơ sở đào tạo và cho từng phân hiệu**."

**Điều 9 khoản 3**:

> "Dữ liệu về nguồn lực dùng chung, bao gồm đội ngũ giảng viên, cơ sở vật chất, tài chính và
> nguồn lực đào tạo khác, **được phân bổ theo mức độ sử dụng thực tế, bảo đảm không tính trùng**
> trong cùng kỳ đánh giá."

### Các chỉ số phải tính riêng từng phân hiệu

Đã xác định được từ Phụ lục II và mục IV:

| Chỉ số | Nội dung | Trích dẫn |
| --- | --- | --- |
| 2.2 | Giảng viên cơ hữu trong độ tuổi lao động | "Trường hợp áp dụng cho phân hiệu, số giảng viên cơ hữu được lấy theo số liệu…" |
| 3.1 | Diện tích đất trên người học | "chỉ số được xác định riêng tại từng phân hiệu… và đồng thời xác định chung" |
| 3.2 | Diện tích sàn xây dựng trên người học | "chỉ số được xác định riêng tại từng phân hiệu" |
| 5.4 | Khảo sát người học, người tốt nghiệp | "mẫu khảo sát và kết quả khảo sát phải được xác định riêng đối với từng phân hiệu" |

> Danh sách đầy đủ nằm ở Phụ lục II của Thông tư. **Cần rà lại toàn bộ Phụ lục II** rồi cập
> nhật cột `data_group.tach_theo_phan_hieu` — hiện mới đánh dấu 8 nhóm theo suy luận.

---

## 3. Nguyên tắc thiết kế đã chọn

> **Phân hiệu là một CHIỀU của dữ liệu, không phải một cơ sở đào tạo riêng.**

### Vì sao không mô hình hóa phân hiệu thành nhiều cơ sở đào tạo

| Nếu coi mỗi phân hiệu là một cơ sở riêng | Nếu coi phân hiệu là một chiều (đã chọn) |
| --- | --- |
| Trái Điều 9 khoản 2: Thông tư cấm kết luận Chuẩn riêng cho phân hiệu | Đúng quy định: tách để tính, gộp để kết luận |
| Một giảng viên dạy hai nơi phải nhân bản thành hai bản ghi → **tính trùng**, trái Điều 9 khoản 3 | Một bản ghi, một định danh GUID, phân bổ theo tỷ lệ |
| Mỗi phân hiệu cần một `DON_VI_ID` — Bộ chưa chắc cấp | Chạy được ngay với một `DON_VI_ID` duy nhất |
| Số liệu tổng hợp phải cộng tay từ nhiều nơi | Tổng hợp bằng truy vấn |

### Hệ quả quan trọng về định danh

**`entity_map` không thay đổi.** Một cán bộ chỉ có **một** GUID gửi Bộ, dù làm việc ở mấy
phân hiệu. Nhân bản GUID theo phân hiệu sẽ làm HEMIS coi là nhiều người khác nhau — đúng
cái lỗi nhân đôi dữ liệu mà toàn bộ thiết kế đang tránh.

---

## 4. Thay đổi trong `hemis_sync` (đã có ở `V4__phan_hieu.sql`)

### Danh sách đơn vị báo cáo của Trường

`V4` đã nạp sẵn bốn dòng:

| Mã | Tên | Loại | Ghi chú |
| --- | --- | --- | --- |
| `TOAN_TRUONG` | Toàn trường (tổng hợp) | `TONG_HOP` | Dòng ảo, không nhập dữ liệu trực tiếp |
| `TRU_SO_CHINH` | Trụ sở chính | `TRU_SO_CHINH` | |
| `PH_LONG_AN` | Phân hiệu Long An | `PHAN_HIEU` | Cần bổ sung địa chỉ, quyết định thành lập |
| `PH_GIA_LAI` | Phân hiệu Gia Lai | `PHAN_HIEU` | Cần bổ sung địa chỉ, quyết định thành lập |

> **Cảnh báo về địa giới hành chính**: cả Long An và Gia Lai đều thuộc diện sắp xếp đơn vị
> hành chính năm 2025. Hai trường bắt buộc `tinh_thanh_new` và `xa_phuong_new` phải tra từ
> danh mục `DM_TINH_NEW`, `DM_XA_NEW` của HEMIS — **không dùng mã tỉnh cũ**, sẽ bị từ chối.


| Bảng | Thay đổi | Mục đích |
| --- | --- | --- |
| `don_vi_bao_cao` | **Bảng mới** | Danh sách trụ sở chính và các phân hiệu |
| `co_so_giao_duc` | Thêm `don_vi_bao_cao_code` | Mỗi đơn vị được Bộ cấp Id riêng có một dòng thông tin chung |
| `sync_batch` | Thêm `don_vi_bao_cao_code` | Biết đợt đồng bộ này đại diện đơn vị nào |
| `data_group_status` | Thêm `don_vi_bao_cao_code` vào khóa duy nhất | Bảng 1C lập riêng từng phân hiệu và một bản tổng |
| `data_group` | Thêm `tach_theo_phan_hieu` | Đánh dấu nhóm nào Thông tư bắt tách |
| `phan_bo_nguon_luc` | **Bảng mới** | Chống tính trùng nguồn lực dùng chung |
| `sync_record`, `sync_error` | Thêm `don_vi_bao_cao_code` | Truy vết và gửi lỗi đúng nơi xử lý |

### Dòng `TOAN_TRUONG`

`don_vi_bao_cao` có một dòng đặc biệt `TOAN_TRUONG` loại `TONG_HOP`. Đây là **dòng ảo**,
không nhập dữ liệu trực tiếp — dùng làm khóa cho bản Bảng 1C tổng hợp, đúng yêu cầu "lập
riêng cho toàn cơ sở đào tạo **và** cho từng phân hiệu".

### Bảng `phan_bo_nguon_luc` — chống tính trùng

Một giảng viên dạy 60% thời gian ở trụ sở chính, 40% ở phân hiệu:

```
entity_type  business_key   don_vi_bao_cao_code  ky_danh_gia  ty_le
CAN_BO       0790xxxxxxxx   TRU_SO_CHINH         2026         60.00
CAN_BO       0790xxxxxxxx   PH_LONG_AN           2026         40.00
```

Khi tính số giảng viên quy đổi của từng đơn vị thì **cộng theo tỷ lệ**, không đếm đầu người.

View `v_phan_bo_sai_tong` liệt kê đối tượng có tổng tỷ lệ khác 100%. **View này phải rỗng
trước khi chốt số liệu kỳ đánh giá** — đưa vào danh mục kiểm tra.

---

## 5. Thay đổi cần làm ở kho dữ liệu (HEMIS nội bộ)

Đây là phần bắt buộc, vì chiều phân hiệu phải có **từ gốc dữ liệu**, không suy ra được ở
cổng tích hợp.

### Cột cần bổ sung

```text
-- KHUNG MAU, chua chay duoc: thay <TenBang> bang ten bang that
ALTER TABLE <TenBang>
    ADD COLUMN MaDonViBaoCao VARCHAR(20) NULL;
```

| Bảng | Ý nghĩa của cột | Chỉ số liên quan |
| --- | --- | --- |
| `CanBo` | Nơi làm việc chính | 2.1, 2.2, 2.3 |
| `DonViCongTac` | Nơi công tác theo từng giai đoạn | 2.2 |
| `HocTapSinhVien`, `HocTapHocVien`, `HocTapNghienCuuSinh` | **Nơi học**, không phải nơi cư trú | mẫu số của 2.1, 3.1, 3.2 |
| `DatDai` | Khuôn viên thuộc đơn vị nào | 3.1 |
| `ToaNha`, `CongTrinhCoSoVatChat`, `PhongHocGiangDuongHoiTruong` | Vị trí công trình | 3.2 |
| `KyTucXa`, `PhongThiNghiem`, `PhongXuongThucHanh`, `ThuVienTrungTamHocLieu` | Vị trí | 3.x |
| `ViecLamSauTotNghiep` | Người tốt nghiệp thuộc đơn vị nào | 5.4 |
| `ChiTieuTuyenSinh`, `DuLieuTrungTuyen` | Tuyển sinh cho đơn vị nào | 5.1, 5.2 |

### Hai cái bẫy khi điền cột này

**1. Người học gắn với nơi HỌC, không phải nơi ở.** Cột `MaTinhThuongTru` là nơi thường trú —
không liên quan. Nơi học nằm ở bảng học tập, theo chương trình và địa điểm tổ chức đào tạo.

**2. Giảng viên có thể thuộc nhiều nơi.** Cột `MaDonViBaoCao` trên `CanBo` chỉ ghi **nơi làm
việc chính**. Trường hợp dạy nhiều nơi phải khai thêm vào `phan_bo_nguon_luc`, nếu không sẽ
tính trùng hoặc bỏ sót.

### Bảng danh mục mới

```sql
CREATE TABLE DM_DonViBaoCao (
    Ma VARCHAR(20) PRIMARY KEY,
    TenDonVi VARCHAR(250) NOT NULL,
    LoaiDonVi VARCHAR(20) NOT NULL,
    DangHoatDong BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

Mã phải **trùng** với `hemis_sync.don_vi_bao_cao.code` để ghép được hai bên.

---

## 6. Thay đổi ở lớp hợp đồng và bộ trích xuất

### View `hemis_src.*`

Mỗi view thêm cột `don_vi_bao_cao`:

```text
-- Them vao danh sach cot cua tung view trong V3:
cb.MaDonViBaoCao  AS don_vi_bao_cao,
```

### Bộ trích xuất

Mỗi lớp `PhanHeExtractor` nhận thêm tham số đơn vị:

```java
// Truoc
Result extract();

// Sau
Result extract(String donViBaoCaoCode);   // null = toan truong
```

Khi `donViBaoCaoCode` là `null` thì lấy toàn bộ (để gửi Bộ dưới một `DON_VI_ID`); khi có giá
trị thì lọc theo đơn vị (để lập biểu mẫu riêng cho phân hiệu).

> **Lưu ý**: dữ liệu **gửi lên Bộ** vẫn là toàn trường, không tách. Việc tách chỉ phục vụ
> biểu mẫu tự đánh giá theo Thông tư 83 — trừ khi Bộ cấp `DON_VI_ID` riêng cho phân hiệu
> (xem câu hỏi số 1 ở mục 8).

---

## 7. Kế hoạch thực hiện

| TT | Việc | Nơi làm | Ngày công | Khi nào |
| --- | --- | --- | --- | --- |
| 1 | Hỏi Bộ: phân hiệu có được cấp `DON_VI_ID` riêng không | Phòng CNTT | 0,5 | **Ngay** |
| 2 | Bổ sung địa chỉ, quyết định thành lập, mã địa giới mới cho 02 phân hiệu | Phòng TCHC + CNTT | 1 | Tuần này |
| 3 | Rà Phụ lục II, chốt danh sách chỉ số tách theo phân hiệu | Phòng CNTT | 1 | Tuần này |
| 4 | Chạy `V4__phan_hieu.sql` | Phòng CNTT | 0,5 | Sau việc 2 |
| 5 | Bổ sung `MaDonViBaoCao` vào 14 bảng ở kho dữ liệu | Nhóm HEMIS nội bộ | 3 | Tuần 2 |
| 6 | Điền dữ liệu cột mới cho bản ghi hiện có | Các đơn vị | 5 | Tuần 2-3 |
| 7 | Sửa view `hemis_src` và 3 bộ trích xuất | Phòng CNTT | 2 | Tuần 3 |
| 8 | Khai `phan_bo_nguon_luc` cho giảng viên dạy nhiều nơi | Phòng TCHC | 2 | Tuần 3 |
| 9 | Báo cáo Bảng 1C theo từng đơn vị và bản tổng | Phòng CNTT | 2 | Tuần 4 |
| | **Cộng** | | **17** | |

17 ngày công nằm trong 7 tuần của Giai đoạn 2, nhưng **làm tăng khối lượng** so với báo cáo
đã trình. Cần báo cáo bổ sung Hiệu trưởng.

---

## 8. Câu hỏi phải làm rõ

| # | Câu hỏi | Hỏi ai | Vì sao quyết định |
| --- | --- | --- | --- |
| **1** | **Phân hiệu có được cấp `DON_VI_ID` riêng trên HEMIS không?** | Cục KHCN&TT | Có → mỗi phân hiệu một đợt đồng bộ riêng, một tài khoản riêng. Không → gửi gộp, chỉ tách khi lập biểu mẫu |
| 2 | Đặc tả API không có trường phân hiệu. Bộ dự kiến nhận số liệu theo phân hiệu bằng cách nào? | Cục KHCN&TT | Nếu không có đường nào thì biểu mẫu Thông tư 83 phải nộp riêng ngoài HEMIS |
| 3 | Danh sách đầy đủ chỉ số phải tính riêng theo phân hiệu ở Phụ lục II gồm những gì? | Đọc Phụ lục II | Quyết định cột `tach_theo_phan_hieu` |
| 4 | Mã tỉnh/xã **mới** của Long An và Gia Lai sau sắp xếp đơn vị hành chính 2025 | Danh mục `DM_TINH_NEW`, `DM_XA_NEW` của HEMIS | Trường bắt buộc; dùng mã cũ sẽ bị từ chối |
| 5 | Nguồn lực dùng chung phân bổ theo căn cứ nào (quyết định, bảng phân công, giờ giảng)? | Phòng TCHC, Phòng Đào tạo | Căn cứ khai `phan_bo_nguon_luc`, phải kiểm chứng được |

Câu hỏi số 1 là then chốt: **trả lời khác nhau dẫn tới hai cách triển khai khác nhau**.
Thiết kế trong `V4` chịu được cả hai (cột `hemis_don_vi_id` để `NULL` hay có giá trị), nhưng
bộ trích xuất và quy trình ký số thì phải chọn một đường.

---

## 9. Danh mục kiểm tra

| TT | Nội dung | Đạt |
| --- | --- | --- |
| 1 | `don_vi_bao_cao` có đủ trụ sở chính và toàn bộ phân hiệu đang hoạt động | ☐ |
| 2 | Đã có trả lời của Bộ về việc cấp `DON_VI_ID` riêng | ☐ |
| 3 | Cột `tach_theo_phan_hieu` khớp danh sách chỉ số ở Phụ lục II | ☐ |
| 4 | 14 bảng ở kho dữ liệu đã có cột `MaDonViBaoCao` | ☐ |
| 5 | Không còn bản ghi nào có `MaDonViBaoCao` rỗng ở các bảng bắt buộc | ☐ |
| 6 | Người học gắn theo **nơi học**, đã kiểm tra bằng mẫu | ☐ |
| 7 | View `v_phan_bo_sai_tong` **rỗng** | ☐ |
| 8 | Lập được Bảng 1C cho từng phân hiệu và bản tổng | ☐ |
| 9 | Tổng số liệu các đơn vị bằng số liệu toàn trường (không thiếu, không trùng) | ☐ |
| 10 | Định danh GUID của cán bộ dạy nhiều phân hiệu vẫn là **một** | ☐ |

Mục 9 và 10 là hai phép thử quan trọng nhất: sai mục 9 là tính trùng hoặc bỏ sót, sai mục 10
là nhân đôi dữ liệu trên hệ thống của Bộ.
