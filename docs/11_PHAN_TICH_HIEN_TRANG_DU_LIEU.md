# 11. Phân tích hiện trạng dữ liệu và ba hệ thống cũ

| | |
| --- | --- |
| **Ngày phân tích** | 19/10/2026 |
| **Phạm vi** | Thư mục `Data HEMIS/` (14 tệp Excel của Bộ) + 3 kho mã `HEMIS-DWH-Backend`, `HEMIS-DWH-Frontend`, `HEMIS-DWH-Database` |
| **Mục đích** | Xác định những gì phải điều chỉnh để dựng HEMIS nội bộ: thu thập dữ liệu từ các đơn vị → làm sạch → đồng bộ qua `hemis-platform` → lên HEMIS của Bộ |

> **Lưu ý**: thư mục `SRS/` hiện chỉ chứa `desktop.ini`, không có tài liệu nào. Phân tích
> dưới đây lấy mã nguồn của ba kho làm đặc tả thực tế. Nếu có bản SRS gốc, cần đối chiếu lại.

---

## 1. Bộ Excel của Bộ — cấu trúc

14 tệp trong `Data HEMIS/`, chia hai nhóm:

| Nhóm | Tệp | Ý nghĩa |
| --- | --- | --- |
| `Export_*` | CoSoGiaoDuc, Doi_Ngu, NganhDT, DaoTao, CSVC, KHCN, HTQT, HTDN, HoiDong | Dữ liệu **đã có** trên HEMIS, tải về |
| `Dữ liệu *` / `Import_*` | Tuyển sinh 2020, Người học 2020, Văn bằng 2022, Tài chính – Tài sản, TCTS 2026 | Mẫu để **nhập lên** HEMIS |

Mỗi tệp có cấu trúc giống nhau:

```
[HuongDan]    huong dan nhap lieu
[<ma bang>]   mot sheet cho moi bang du lieu, tieu de o DONG 2, du lieu tu DONG 3
              dong 3 thuong la DONG MAU cua Bo (vi du "Tran Phuc An")
[Danh mục]    danh muc HEMIS nhung san, tieu de o dong 3-5,
              moi danh muc chiem 2 cot lien tiep: Ma | Ten
```

Kèm theo: `38- 4998-QD-BGDDT.pdf` — quyết định về cấu trúc dữ liệu.

---

## 2. Phát hiện 1 — Dữ liệu trên HEMIS đang rất thiếu

Đếm số dòng **thực sự có dữ liệu** (không tính dòng trống đã định dạng sẵn và dòng mẫu của Bộ):

| Phân hệ | Bảng chính | Dòng có dữ liệu | Nhận xét |
| --- | --- | --- | --- |
| **Đội ngũ** | `TT` (danh sách cán bộ) | **31** | Không thể là toàn bộ đội ngũ của Trường |
| Đội ngũ | `QPAN`, `GVNN`, `NCCS`, `TDT`, `DVTG`, `PC`, `DBL`, `QTDT`, `BDTH`, `HDHV`, `KL`, `DTCS`, `CDKH` | **0** (chỉ có dòng mẫu) | 13/22 bảng con trống |
| **Người học** | `TT` | 4.539 | Tệp ghi "2020", không phải dữ liệu hiện hành |
| Người học | `HT_SV` / `HT_NCS` | 4.153 / 386 | |
| Người học | `GDTC`, `VP`, `HB`, `VL`, `KT`, `KL`, `VTD` | **≈ 0** | 7/10 bảng con trống |
| **Tuyển sinh** | `DLTT` (trúng tuyển) | 12.571 | Dữ liệu 2020 |
| **Văn bằng** | `VanBang` | 2.279 | Dữ liệu 2022 |
| **KHCN** | `BBKH` (bài báo) | 1.144 | Nhóm có dữ liệu tốt nhất |
| KHCN | `SXB` / `TT` / `GTKH` | 265 / 199 / 31 | |
| **Đào tạo** | `CTDT` / `NAD` / `NN` | 432 / 363 / 350 | |
| **Ngành ĐT** | `HTDT` / `LHDT` / `TT` | 379 / 158 / 79 | |
| **CSVC** | `CTK` / `PHGDHT` / `TBIPTN` / `TOANHA` | 301 / 287 / 56 / 54 | `THUVIEN` chỉ 2 dòng |
| **CSGD** | `CCTC` / `KHOAHOC` / `CSGD` / `DMLH` | 50 / 59 / 28 / 25 | |
| **HTQT** | `DCT` / `HTQT` / `TOCHUC` / `TTHT` | 146 / 31 / 31 / 29 | 6/11 bảng trống |
| **Hội đồng** | `HDT` / `HDKH` / `BGH` | 21 / 16 / 5 | |
| **Tài chính** | `CTTHUCHI` / `KCL` / `LTC` | 23 / 7 / 6 | `TSDV`, `CTTSDV`, `HDTC` trống |
| **HTDN** | `TCHTDN` | **0** | Trống hoàn toàn |

**Tổng ≈ 29.000 dòng**, trong đó phần lớn thuộc hai bảng Tuyển sinh và Người học của năm 2020.

### Vì sao con số này nghiêm trọng

Thông tư 83/2026 tính các chỉ số **trực tiếp từ dữ liệu trên HEMIS**:

| Chỉ số | Ngưỡng | Lấy từ bảng | Tình trạng |
| --- | --- | --- | --- |
| 1.3 Tỷ lệ trường dữ liệu bắt buộc cập nhật | **100%** | Toàn bộ | Còn rất xa |
| 2.1 Người học quy đổi / giảng viên quy đổi | ≤ 40 | Đội ngũ `TT` + Người học `HT_SV` | 31 giảng viên → tỷ lệ sai nghiêm trọng |
| 2.2 Giảng viên cơ hữu trong độ tuổi lao động | ≥ 70% | Đội ngũ `TT`, `HDLD` | Mẫu quá nhỏ |
| 2.3 Giảng viên có trình độ tiến sĩ | ≥ 20–40% | Đội ngũ `TT` | Mẫu quá nhỏ |
| 3.2 Giảng viên có chỗ làm việc riêng ≥ 70% | | Đội ngũ `TT` cột 61 | Trống |
| 6.2 Công bố WoS/Scopus trên giảng viên | ≥ 0,3 | KHCN `BBKH` ÷ Đội ngũ `TT` | Mẫu số sai → chỉ số sai |

> Dữ liệu đội ngũ chỉ có 31 dòng làm **sai lệch mẫu số của ít nhất 5 chỉ số** thuộc 3 tiêu
> chuẩn khác nhau. Đây là việc phải xử lý trước mọi việc kỹ thuật khác.

---

## 3. Phát hiện 2 — Excel dùng TÊN, API dùng MÃ

Dòng mẫu của Bộ trong sheet Người học:

```
Gioi tinh: "Nam"            <- TEN, khong phai ma "01"
Quoc tich: "Viet Nam"       <- TEN, khong phai ma "704"
Dan toc  : "Kinh"           <- TEN, khong phai ma "55"
Tinh     : "Thanh pho Ha Noi"
Xa       : "Xa Dong Xuan"
```

Trong khi API yêu cầu **mã danh mục**: `GIOI_TINH_ID = "01"`, `QUOC_TICH_ID = "704"`.

| | Đường Excel | Đường API |
| --- | --- | --- |
| Giá trị gửi | Tên hiển thị | Mã danh mục |
| Ai đổi tên → mã | Hệ thống của Bộ | **Hệ thống của Trường** |
| Sai chính tả, thừa dấu cách | Bộ có thể vẫn nhận | Bị từ chối |

**Hệ quả**: không thể lấy nguyên dữ liệu đã nhập bằng Excel để đẩy qua API. Phải có bước
đổi tên → mã, và đây là nguồn lỗi lớn nhất khi chuyển từ nhập tay sang tự động.

### Cảnh báo cụ thể về mã giới tính

| Nguồn | Mã Nam | Mã Nữ |
| --- | --- | --- |
| Sheet `Danh mục` trong Excel của Bộ | `1` | `2` |
| Ví dụ trong tài liệu đặc tả API | `01` | — |
| `DM_GioiTinh` trong kho dữ liệu của Trường | `01` | `02` |

Lệch nhau ở số 0 đứng đầu. Phải xác minh với Cục KHCN&TT trước khi gửi — ghi vào mục
"Điểm cần làm rõ" của [01_DAC_TA_API_HEMIS.md](01_DAC_TA_API_HEMIS.md). Khả năng tương tự
xảy ra với các danh mục mã số khác.

---

## 4. Phát hiện 3 — Danh mục HEMIS đã có sẵn trong các tệp Excel

Sheet `Danh mục` của mỗi tệp chứa chính các danh mục dùng chung của HEMIS:

| Tệp | Kích thước sheet danh mục | Số danh mục |
| --- | --- | --- |
| `Export_Doi_Ngu` | 11.185 dòng × 174 cột | ~55 |
| `Export_CoSoGiaoDuc` | 11.165 dòng × 97 cột | ~30 |
| `Export_KHCN` | 1.000 dòng × 81 cột | ~27 |
| `Export_NganhDT` | 1.438 dòng × 53 cột | ~17 |
| Các tệp khác | | ~13 mỗi tệp |

Cấu trúc: mỗi danh mục chiếm 2 cột liền nhau `Mã | Tên`, tiêu đề ở dòng 3–5.

**Cơ hội**: có thể nạp `catalog_hemis` **ngay bây giờ** từ các tệp này, không phải chờ Bộ cấp
tài khoản API. Khi có tài khoản thì tải lại qua API và đối chiếu bằng bảng `catalog_diff`.

Đây là việc gỡ được nút thắt lớn nhất của tiến độ hiện nay — đề xuất bổ sung thành nhiệm vụ
**SV1-05b** trong kế hoạch bàn giao.

---

## 5. Phát hiện 4 — Không có ảnh chụp dữ liệu nhất quán

| Tệp | Năm dữ liệu | Ngày xuất |
| --- | --- | --- |
| Tuyển sinh | 2020 | 08/01/2026 |
| Người học | 2020 | 22/04/2026 |
| Văn bằng | 2022 | 12/01/2026 |
| Đội ngũ | — | 13/01/2026 |
| KHCN | — | 29/03/2026 |
| Ngành ĐT | — | 04/06/2026 |

Sáu thời điểm xuất khác nhau, trải từ tháng 1 đến tháng 6/2026, dữ liệu thuộc nhiều năm khác nhau.

Thông tư 83/2026 Điều 13 yêu cầu **chốt số liệu tại ngày 31/12 hằng năm**. Hiện chưa có cơ
chế nào bảo đảm các phân hệ cùng phản ánh một thời điểm. Đây là lý do kỹ thuật cho yêu cầu
ảnh chụp theo kỳ đánh giá (RÀNG BUỘC-10 trong [08_SRS.md](08_SRS.md)).

---

## 6. Hiện trạng ba hệ thống cũ

### 6.1 HEMIS-DWH-Database

| Điểm mạnh | Điểm yếu |
| --- | --- |
| 13 module, 100 bảng nghiệp vụ sau bổ sung, 156 bảng danh mục sau bổ sung, mô hình hóa theo chuẩn HEMIS | Bảng thông tin chung và schema địa giới mới đã có; dữ liệu `DM_TinhNew`/`DM_XaNew` vẫn cần nạp/đối chiếu từ nguồn chính thức |
| Có `CreatedAt`/`UpdatedAt` trên toàn bộ 253 bảng hiện hữu; bảng bổ sung dùng `TIMESTAMPTZ` | `UpdatedAt` của bảng cũ cho phép NULL — bẫy khi lấy delta |
| Bảng `CanBo` có 86 cột, nhiều hơn 62 cột Excel yêu cầu | Dữ liệu địa giới mới cần quy trình nạp và đối chiếu mã trước khi gửi |
| Mã danh mục phần lớn trùng mã HEMIS | Khóa `SERIAL`, triển khai bằng `reset_all.sql` |
| 297 hàm, 99 view | Chưa có cơ chế duyệt, phân quyền theo đơn vị |

**Kết luận**: schema đủ dùng, không cần làm lại. Cần bổ sung chứ không cần thay thế.

**Cập nhật schema ngày 21/10/2026:** đã bổ sung các thành phần còn thiếu đã được chốt trong
docs 10–11: bảng thông tin chung `CoSoGiaoDuc`, hai danh mục địa giới mới
`DM_TinhNew`/`DM_XaNew`, cùng các cột dùng chung `IsDeleted`, `DeletedAt` và `IsPublic`
theo đúng phạm vi từng nhóm bảng. Các cột và bảng hiện hữu không bị đổi kiểu hoặc xóa.

### 6.2 HEMIS-DWH-Backend

12 module có đủ `imports / views / updates / deletes`; riêng `khoa_hoc_cong_nghe` chỉ có
`updates.py` — **chưa hoàn chỉnh**. Tiện ích `excel.py` còn, nên vẫn nhập được bằng Excel.

Thiếu: xác thực người dùng, phân quyền theo đơn vị, quy trình duyệt, nhật ký thay đổi.

### 6.3 HEMIS-DWH-Frontend

| Phân hệ HEMIS | Có giao diện? | Đơn vị nhập liệu |
| --- | --- | --- |
| Cơ sở giáo dục | ✔ `co-so-dao-tao` | P. Tổ chức – Hành chính |
| Đội ngũ | ✔ `can-bo` | P. Tổ chức – Hành chính |
| Ngành đào tạo | ✔ `nganh-dao-tao` | P. Đào tạo |
| Chương trình đào tạo | ✔ `chuong-trinh-dao-tao` | P. Đào tạo |
| Tuyển sinh | ✔ `tuyen-sinh` | P. Đào tạo |
| Người học | ✔ `nguoi-hoc` | P. Đào tạo |
| **Hội đồng** | ✘ | P. Tổ chức – Hành chính |
| **Cơ sở vật chất** | ✘ | P. Quản trị CSVC |
| **Khoa học công nghệ** | ✘ | P. Quản lý khoa học |
| **Tài chính – Tài sản** | ✘ | P. Kế hoạch – Tài chính |
| **Hợp tác quốc tế** | ✘ | P. Hợp tác quốc tế |
| **Hợp tác doanh nghiệp** | ✘ | P. Hợp tác quốc tế |
| **Văn bằng chứng chỉ** | ✘ | P. Đào tạo |

**7 trên 13 phân hệ không có màn hình nhập liệu.** Đây chính là lý do các bảng tương ứng
trên HEMIS đang trống: đơn vị không có chỗ nào để nhập.

---

## 7. Khoảng trống để dựng HEMIS nội bộ

Mục tiêu: đơn vị trong Trường nhập liệu → làm sạch và duyệt → kho dữ liệu → `hemis-platform`
→ API của Bộ.

```
Don vi trong truong          HEMIS noi bo              hemis-platform         HEMIS Bo
──────────────────           ─────────────             ──────────────         ────────
P. TCHC    ─┐                                                                      ▲
P. Dao tao ─┤   nhap lieu    ┌──────────────┐          ┌────────────┐              │
P. QTCSVC  ─┼──────────────► │ Giao dien    │  duyet   │ hemis_src  │   ky so      │
P. QLKH    ─┤   hoac Excel   │ + lam sach   ├─────────►│ hemis_sync ├──────────────┘
P. KHTC    ─┤                │ + phan quyen │          │ + kiem tra │
P. HTQT    ─┘                └──────┬───────┘          └────────────┘
                                    │
                             ┌──────▼───────┐
                             │ Kho du lieu  │
                             │ (public)     │
                             └──────────────┘
```

Những thứ **chưa có**:

| # | Khoảng trống | Hệ quả nếu không làm | Ưu tiên |
| --- | --- | --- | --- |
| 1 | Giao diện nhập liệu cho 7 phân hệ | Đơn vị không nhập được → bảng trống vĩnh viễn | **Rất cao** |
| 2 | Đăng nhập và phân quyền theo đơn vị | Không giao trách nhiệm được; ai cũng sửa được dữ liệu của phòng khác | **Rất cao** |
| 3 | Quy trình duyệt dữ liệu (nháp → trình → duyệt → chốt) | Không ai chịu trách nhiệm về số liệu gửi Bộ | **Cao** |
| 4 | Nhập hàng loạt từ chính mẫu Excel của Bộ | Nhập tay 4.500 người học là không khả thi | **Cao** |
| 5 | Đổi tên → mã danh mục khi nhập | Dữ liệu nhập vào không gửi API được | **Cao** |
| 6 | Bảng điều khiển mức độ đầy đủ theo đơn vị | Không biết phòng nào còn thiếu gì trước 31/12 | **Cao** |
| 7 | Nhật ký thay đổi (ai sửa gì, khi nào) | Không đối soát được khi số liệu lệch | Trung bình |
| 8 | Ảnh chụp theo kỳ đánh giá | Không giữ được số liệu chốt 31/12 | Trung bình |
| 9 | Hoàn thiện module KHCN ở backend | Phân hệ có dữ liệu tốt nhất lại chưa quản lý được | Trung bình |

---

## 8. Những điều chỉnh đề xuất

### 8.1 Không làm lại từ đầu

Ba hệ thống cũ **dùng tiếp được**. Cụ thể:

| Thành phần | Quyết định | Lý do |
| --- | --- | --- |
| `HEMIS-DWH-Database` | **Giữ**, bổ sung | Schema đã theo chuẩn HEMIS, 99 bảng đã có |
| `HEMIS-DWH-Backend` | **Giữ**, bổ sung xác thực và phân quyền | 12 module đã chạy, viết lại là lãng phí |
| `HEMIS-DWH-Frontend` | **Giữ**, thêm 7 zone còn thiếu | Khung monorepo đã sẵn, thêm zone theo mẫu có sẵn |
| `hemis-platform` | Giữ nguyên vai trò | Chỉ lo kết nối Bộ, không lo nhập liệu |

### 8.2 Danh sách điều chỉnh theo thứ tự ưu tiên

| TT | Việc | Nơi làm | Ước lượng |
| --- | --- | --- | --- |
| 1 | Nạp `catalog_hemis` từ sheet `Danh mục` của các tệp Excel | `hemis-platform` | 2 ngày |
| 2 | Bộ nhập hàng loạt đọc **đúng mẫu Excel của Bộ**, tự đổi tên → mã, báo lỗi theo dòng | Backend | 10 ngày |
| 3 | Đăng nhập + phân quyền theo đơn vị và theo phân hệ | Backend + Frontend | 10 ngày |
| 4 | 7 zone giao diện còn thiếu (ưu tiên CSVC, KHCN, Tài chính) | Frontend | 20 ngày |
| 5 | Quy trình duyệt: nháp → trình → duyệt → chốt | Backend + Frontend | 8 ngày |
| 6 | Bảng điều khiển mức độ đầy đủ theo đơn vị và theo nhóm Bảng 1C | `hemis-platform` | 5 ngày |
| 7 | Bổ sung `DM_TINH_NEW`, `DM_XA_NEW` và ánh xạ địa giới | Database | 3 ngày |
| 8 | Bổ sung bảng thông tin chung của Trường | Database | 1 ngày |
| 9 | Hoàn thiện module KHCN ở backend | Backend | 4 ngày |
| 10 | Nhật ký thay đổi | Backend | 4 ngày |

Tổng ≈ **67 ngày công**, chưa tính thời gian các đơn vị nhập và làm sạch dữ liệu.

### 8.3 Điều chỉnh quan trọng nhất về cách làm

**Dùng chính mẫu Excel của Bộ làm giao diện thu thập dữ liệu cho giai đoạn trước mắt.**

Lý do: còn khoảng 10 tuần đến 31/12/2026; không kịp xây 7 giao diện rồi mới đi thu thập.

| Giai đoạn | Cách thu thập | Thời gian |
| --- | --- | --- |
| **Ngay** – 30/11/2026 | Gửi mẫu Excel của Bộ cho từng đơn vị; bộ nhập hàng loạt đọc vào kho dữ liệu, kiểm tra và trả lỗi theo dòng | Song song với làm giao diện |
| 12/2026 – 3/2027 | Giao diện của 7 phân hệ dần thay thế Excel | |
| Từ 4/2027 | Kết nối trực tiếp hệ thống nguồn (nhân sự, tài chính, LMS, thư viện) theo Điều 8 Thông tư 83 | |

Cách này tận dụng được việc các đơn vị **đã quen mẫu Excel của Bộ**, và biến việc nhập liệu
thành việc một lần, không phải chờ phần mềm.

---

## 9. Ba việc làm ngay trong tuần này

1. **Xác minh dữ liệu đội ngũ.** 31 dòng không thể là toàn bộ đội ngũ. Cần biết: HEMIS đang
   thực sự có bao nhiêu cán bộ của Trường, và vì sao bản xuất chỉ có 31 dòng (xuất lọc? xuất
   lỗi? hay dữ liệu trên HEMIS đúng là như vậy?). Đây là con số quyết định ít nhất 5 chỉ số
   của Thông tư 83.

2. **Nạp danh mục từ Excel** vào `catalog_hemis`. Gỡ được phụ thuộc vào việc Bộ cấp tài khoản.

3. **Gửi mẫu Excel kèm hạn cho 6 đơn vị** theo phân công tại Phụ lục I của Kế hoạch. Không
   chờ phần mềm — việc thu thập và làm sạch dữ liệu mất nhiều thời gian hơn việc lập trình.

---

## 10. Câu hỏi còn mở

| # | Câu hỏi | Hỏi ai |
| --- | --- | --- |
| 1 | Mã giới tính là `1`/`2` hay `01`/`02`? Các danh mục mã số khác có bị lệch số 0 đầu không? | Cục KHCN&TT |
| 2 | Bản xuất đội ngũ chỉ có 31 dòng — do xuất lọc hay dữ liệu trên HEMIS đúng như vậy? | Cục KHCN&TT / người từng xuất |
| 3 | Dữ liệu các năm cũ (2020, 2022) có phải nộp lại theo ảnh chụp 31/12/2026 không? | Cục KHCN&TT |
| 4 | Dữ liệu nhập bằng Excel và dữ liệu nhập qua API có ghi đè nhau không? | Cục KHCN&TT |
| 5 | Nội dung `QĐ 4998/QĐ-BGDĐT` có ràng buộc gì thêm về cấu trúc dữ liệu? | Đọc tệp trong `Data HEMIS/` |

Câu 4 đặc biệt quan trọng: nếu hai đường ghi đè nhau thì phải chốt **một** đường duy nhất
cho mỗi phân hệ, tránh dữ liệu nhảy qua nhảy lại.
