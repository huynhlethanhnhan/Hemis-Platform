# 08. Đặc tả yêu cầu phần mềm (SRS) — hemis-platform

| | |
| --- | --- |
| **Mã tài liệu** | HCMUE-CNTT-HEMIS-SRS |
| **Phiên bản** | 1.1 |
| **Ngày** | 12/10/2026 |
| **Người đọc** | Nhóm phát triển, kiểm thử, vận hành |
| **Trạng thái** | Áp dụng cho Giai đoạn 1 (12/10 – 11/11/2026); đã cập nhật theo Thông tư 83/2026/TT-BGDĐT |

> Tài liệu này dành cho **người viết mã**, không phải cho lãnh đạo hay khách hàng. Nó nói
> *phần mềm phải làm gì và làm sao biết là đã làm đúng*. Phần tiến độ, nhân sự, kinh phí
> nằm ở `../plan/PA_Ky_thuat_GD1_Ket_noi_API_HEMIS.docx`, không nhắc lại ở đây.

---

## 1. Phạm vi và cách dùng tài liệu

### 1.1 Mục đích

Xác định yêu cầu chức năng và phi chức năng của `hemis-platform` ở mức đủ chi tiết để:

- lập trình viên biết phải viết gì, không phải đoán;
- người kiểm thử viết được ca kiểm thử mà không cần hỏi lại;
- khi đặc tả của Bộ thay đổi, biết ngay phải sửa những yêu cầu nào.

### 1.2 Quy ước đánh mã

```
FR-<NHÓM>-<số>     Yêu cầu chức năng
NFR-<NHÓM>-<số>    Yêu cầu phi chức năng
RÀNG BUỘC-<số>     Ràng buộc thiết kế
MỞ-<số>            Điểm chưa rõ, chờ Bộ trả lời
```

### 1.3 Mức ưu tiên

| Mức | Ý nghĩa |
| --- | --- |
| **M** (Must) | Bắt buộc có để nghiệm thu Giai đoạn 1. Thiếu = không kết nối được |
| **S** (Should) | Nên có trong Giai đoạn 1; thiếu thì vẫn nghiệm thu được nhưng phải ghi nhận |
| **L** (Later) | Giai đoạn 2 trở đi. Ghi ở đây để thiết kế không chặn đường |

### 1.4 Tài liệu tham chiếu

| Mã | Tài liệu |
| --- | --- |
| [ĐT] | Tài liệu đặc tả kỹ thuật tích hợp dữ liệu qua API từ cơ sở đào tạo, Cục KHCN&TT, 2026 |
| [KS] | Hướng dẫn sử dụng ký số HEMIS, Bộ GDĐT, 2026 |
| [CV] | Công văn BGDĐT-KHCNTT hướng dẫn kết nối API, đồng bộ dữ liệu với HEMIS |
| **[TT83]** | **Thông tư 83/2026/TT-BGDĐT quy định Chuẩn cơ sở giáo dục đại học** (thay thế TT 01/2024/TT-BGDĐT) |
| [PA] | Phương án kỹ thuật Giai đoạn 1 |
| [W3C] | XML Signature Syntax and Processing, W3C |

> **[TT83] là văn bản chi phối toàn bộ dự án, không chỉ là tài liệu tham khảo.** Đọc mục 1.5
> trước khi làm bất cứ việc gì.

### 1.5 Thông tư 83/2026 đổi gì — phần mọi người phải biết

[TT83] biến việc cập nhật dữ liệu lên HEMIS từ *nghĩa vụ báo cáo* thành *tiêu chí bị chấm điểm*.

| Điều khoản | Nội dung | Hệ quả với dự án |
| --- | --- | --- |
| Điều 6, **Tiêu chí 1.3** | Dữ liệu người học, giảng viên, CTĐT, CSVC, cơ sở thực hành, địa điểm đào tạo, điều kiện bảo đảm chất lượng, kết quả hoạt động phải "kết nối liên thông, cập nhật **đầy đủ, chính xác, đúng thời hạn, đúng định dạng và nhất quán**" trên HEMIS | 5 điều kiện, không phải chỉ "gửi thành công" |
| Phụ lục II, **Chỉ số 1.3** | *Tỷ lệ trường dữ liệu bắt buộc đáp ứng yêu cầu cập nhật trên HEMIS*, ngưỡng **100%** | Không có mức "đạt một phần". Thiếu một trường bắt buộc là trượt chỉ số |
| Điều 13.2a | Thời điểm xác định số liệu: **31/12 hằng năm**; riêng tài chính **31/3 năm sau** | Hạn thực sự của dữ liệu năm 2026 là **31/12/2026** |
| Điều 14.3 | **Kỳ đánh giá đầu tiên theo Thông tư này là năm dữ liệu 2026** | Áp dụng ngay, không có năm chuyển tiếp |
| Điều 13.1b | Bộ công bố kết quả trước **30/6 hằng năm** sau khi rà soát, đối sánh trên HEMIS | Sai sót phát hiện sau 31/12 gần như không sửa kịp |
| Điều 5 | Dữ liệu phục vụ đánh giá Chuẩn **cập nhật vào HEMIS** | HEMIS là kênh duy nhất, không báo cáo song song |
| Điều 8 | Nguồn dữ liệu chính thức: hệ thống quản trị số tập trung (nhân sự, tài chính, đào tạo), LMS, phần mềm thư viện, kết quả khảo sát và kiểm toán, hệ thống của cơ sở thực hành | Phải ghi nhận nguồn gốc dữ liệu để kiểm chứng được |
| Phụ lục V, **Bảng 1C** | 14 nhóm dữ liệu, mỗi nhóm khai: *ngày phải cập nhật, ngày cập nhật thực tế, đúng hạn (1/0), đầy đủ (%), tin cậy (%), đạt điều kiện (1/0)* | Hệ thống phải sinh được bảng này từ nhật ký, xem FR-DQ |

**Điều này đổi gì so với kế hoạch ban đầu**

| | Trước khi có [TT83] | Sau khi có [TT83] |
| --- | --- | --- |
| Mốc ràng buộc | Báo cáo tiến độ 30/9/2026 | **31/12/2026** — toàn bộ dữ liệu bắt buộc năm 2026 phải có trên HEMIS |
| Mức đạt | "Kết nối được, gửi thử 1 phân hệ" | **100%** trường dữ liệu bắt buộc, đủ 5 điều kiện |
| Phạm vi | Ưu tiên 5 phân hệ, phần còn lại sang 2027 | Mọi nhóm dữ liệu trong Bảng 1C đều tính vào chỉ số |
| Việc của phần mềm | Gửi được dữ liệu | Gửi được **và chứng minh được** là đúng hạn, đầy đủ, nhất quán |

Giai đoạn 1 (hoàn thành 11/11/2026) vì vậy không còn là đích, mà là **bước đệm**: sau đó còn
khoảng 7 tuần để đẩy đủ dữ liệu 12 phân hệ trước 31/12/2026. Phần điều chỉnh kế hoạch và
nguồn lực thuộc thẩm quyền lãnh đạo — tài liệu này chỉ nêu hệ quả kỹ thuật.

Thuật ngữ: xem [06_THUAT_NGU.md](06_THUAT_NGU.md).

---

## 2. Tổng quan hệ thống

### 2.1 Bối cảnh

```
                    ┌──────────────────────────────┐
  He thong nguon ──►│  HEMIS-DWH (schema dwh)      │
  QLDT, nhan su     │  13 module, 99 bang          │
  tai chinh         └──────────────┬───────────────┘
                                   │ doc
                                   ▼
                    ┌──────────────────────────────┐        ┌─────────────────┐
                    │  hemis-platform              │───────►│  API HEMIS      │
                    │  schema hemis_sync           │  HTTPS │  Bo GDDT        │
                    └──────┬───────────────▲───────┘        └─────────────────┘
                           │               │
                    (keo viec)      (tra XML da ky)
                           ▼               │
                    ┌──────────────────────┴───────┐
                    │  Tram ky so (Windows)        │
                    │  USB token + XmlSignerTriNam │
                    └──────────────────────────────┘
```

### 2.2 Tác nhân

| Tác nhân | Vai trò với hệ thống |
| --- | --- |
| Cán bộ kỹ thuật | Tạo đợt đồng bộ, theo dõi, xử lý sự cố |
| Cán bộ quản lý dữ liệu (data steward) | Xem danh sách lỗi, sửa dữ liệu nguồn, xác nhận đợt |
| Người ký số | Cắm USB token, nhập mã PIN, phê duyệt đợt |
| Tác nhân ký số (phần mềm) | Kéo việc ký, gọi plugin, trả tệp đã ký |
| HEMIS (hệ thống ngoài) | Tiếp nhận tệp XML và thân JSON |
| Lịch chạy (scheduler) | Tải danh mục định kỳ |

### 2.3 Giả định

| # | Giả định | Nếu sai thì sao |
| --- | --- | --- |
| GĐ-1 | Bộ cấp tài khoản, `client_secret`, `DON_VI_ID`, tên miền SSO trước 19/10/2026 | Phát triển trên WireMock, không nghiệm thu được FR-SND |
| GĐ-2 | Trường có chứng thư số tổ chức còn hạn | Dùng ký thủ công (FR-SGN-05), không đạt FR-SGN-03 |
| GĐ-3 | Máy chủ ra được Internet tới `*.moet.gov.vn` | Không gọi được API thật |
| GĐ-4 | Schema `dwh` có đủ trường bắt buộc của phân hệ COSOGIAODUC | FR-EXT-02 lùi, dùng dữ liệu từ cấu hình |
| GĐ-5 | Đặc tả [ĐT] không đổi trong tháng 10–11/2026 | Bộ chuyển đổi phải nâng phiên bản |

### 2.4 Phụ thuộc bên ngoài

| Phụ thuộc | Rủi ro | Giảm thiểu |
| --- | --- | --- |
| API HEMIS (môi trường thử nghiệm) | Chưa có tài khoản; có thể đổi địa chỉ | WireMock; địa chỉ trong cấu hình |
| Plugin XmlSignerTriNam | Chỉ chạy Windows, chỉ nghe `127.0.0.1:64005` | Tác nhân kéo việc (FR-SGN-03) |
| Trình quản lý USB token của nhà cung cấp | Mỗi nhà cung cấp một phần mềm | Tài liệu cài đặt trong `02_KY_SO_XML_DSIG.md` |
| Schema `dwh` | Có thể thay đổi | Truy vấn qua lớp trích xuất riêng, không rải khắp mã |

---

## 3. Yêu cầu chức năng

Mỗi yêu cầu ghi: mô tả · xử lý · **tiêu chí chấp nhận** (điều kiện kiểm thử được) · truy vết.

### 3.1 FR-AUTH — Xác thực với HEMIS

#### FR-AUTH-01 · Lấy access token · **M**

| | |
| --- | --- |
| **Mô tả** | Hệ thống lấy access token từ máy chủ SSO của Bộ theo OAuth 2.0 Resource Owner Password Credentials Grant |
| **Đầu vào** | `grant_type=password`, `scope=password`, `client_id`, `client_secret`, `username`, `password` (từ biến môi trường) |
| **Xử lý** | `POST {sso-url}/connect/token`, `Content-Type: application/x-www-form-urlencoded` |
| **Đầu ra** | Chuỗi `access_token` dùng cho header `Authorization: Bearer <token>` |
| **Tiêu chí chấp nhận** | 1. Gọi thành công trả về token không rỗng.<br>2. `access_token` rỗng hoặc thiếu → ném lỗi có thông điệp nêu rõ máy chủ SSO không trả token.<br>3. Không ghi `client_secret`, `password`, nội dung token vào nhật ký. |
| **Truy vết** | [ĐT] mục 1 · `client/HemisAuthClient.java` |

#### FR-AUTH-02 · Lưu đệm và tự làm mới token · **M**

| | |
| --- | --- |
| **Mô tả** | Token được dùng lại cho nhiều lần gọi và tự làm mới trước khi hết hạn |
| **Xử lý** | Thời hạn sử dụng = `min(expires_in, hemis.token.max-lifetime-seconds) − refresh-margin-seconds`, tối thiểu 30 giây |
| **Lý do** | [ĐT] ghi `expires_in = 900000`; nếu là giây thì hơn 10 ngày, rất khó đúng. Xem MỞ-03 |
| **Tiêu chí chấp nhận** | 1. Hai lần gọi liên tiếp trong thời hạn chỉ phát sinh **một** lệnh gọi `/connect/token`.<br>2. Khi `expires_in = 900000` và `max-lifetime-seconds = 900`, thời hạn thực tế ≤ 900 giây.<br>3. Truy cập đồng thời từ nhiều luồng không tạo nhiều token (có khóa). |
| **Truy vết** | `HemisAuthClient.accessToken()` |

#### FR-AUTH-03 · Xử lý lỗi 401 · **M**

| | |
| --- | --- |
| **Mô tả** | Khi API nghiệp vụ trả 401, hệ thống lấy token mới và thử lại |
| **Xử lý** | Xóa token đệm, gọi lại `/connect/token`, thử lại lệnh gọi ban đầu |
| **Tiêu chí chấp nhận** | 1. Thử lại **không quá** `hemis.http.max-retries` lần.<br>2. Sau khi hết số lần thử, ném lỗi ghi rõ số lần đã thử.<br>3. 401 do `DON_VI_ID` sai (không phải token hết hạn) không lặp vô hạn. |
| **Truy vết** | `HemisSyncClient.withRetry()` · [ĐT] mục 4.2 |

---

### 3.2 FR-CAT — Danh mục dùng chung

#### FR-CAT-01 · Tải toàn bộ danh mục · **M**

| | |
| --- | --- |
| **Mô tả** | Tải hơn 175 danh mục dùng chung trong một lần gọi |
| **Xử lý** | `POST {gateway}/danhmucbeta/v5/DM_BAC_LUONG/getDanhMucHemis`, thân `{}` |
| **Tiêu chí chấp nhận** | 1. `success = true` và `data` chứa ≥ 175 thuộc tính.<br>2. Thời gian chờ đọc ≥ 180 giây (phản hồi rất lớn).<br>3. Ghi nhật ký số lượng danh mục và thời gian tải. |
| **Truy vết** | [ĐT] mục 2 · `client/HemisCatalogClient.java` |

#### FR-CAT-02 · Lưu và cập nhật danh mục · **M**

| | |
| --- | --- |
| **Mô tả** | Lưu từng phần tử danh mục vào bảng `catalog_hemis` |
| **Xử lý** | Với mỗi thuộc tính `DM_XXX` trong `data`: đọc `Id`, `Code`, `MA_<TÊN>`, `TEN_<TÊN>`, `ISPUBLIC`, `IsDeleted`, `Modified`. Tên trường mã và tên **phụ thuộc tên danh mục**, phải suy ra động, không gắn cứng |
| **Tiêu chí chấp nhận** | 1. Chạy hai lần liên tiếp không tạo bản ghi trùng (khóa duy nhất `dm_name` + `ma`).<br>2. Phần tử có `IsDeleted = true` được đánh dấu xóa, không xóa vật lý.<br>3. Giữ nguyên bản ghi gốc trong cột `raw_json` để đối chiếu. |
| **Trạng thái** | **Chưa làm** — tuần 2 |
| **Truy vết** | `V1__hemis_sync.sql` bảng `catalog_hemis` |

#### FR-CAT-03 · Ánh xạ mã nội bộ sang mã HEMIS · **M**

| | |
| --- | --- |
| **Mô tả** | Mọi trường `*_ID` gửi đi phải mang mã danh mục của HEMIS |
| **Xử lý** | Tra bảng `catalog_map (dm_name, local_code) → hemis_code` |
| **Tiêu chí chấp nhận** | 1. Mã nội bộ không có trong `catalog_map`, hoặc `hemis_code IS NULL` → sinh lỗi **mức chặn** trong `sync_error`, mã quy tắc `CATALOG`.<br>2. Báo cáo được danh sách mã chưa ánh xạ theo từng danh mục. |
| **Trạng thái** | **Chưa làm** — tuần 2 |

#### FR-CAT-04 · Tải danh mục định kỳ · **S**

Tải lại hằng ngày, so sánh theo `Modified`, ghi nhật ký các thay đổi. Giai đoạn 1 chấp nhận chạy tay.

---

### 3.3 FR-EXT — Trích xuất dữ liệu

#### FR-EXT-01 · Giao diện chung cho mọi phân hệ · **M**

| | |
| --- | --- |
| **Mô tả** | Mỗi phân hệ là một lớp thực thi `PhanHeExtractor`, tự đăng ký qua `@Component` |
| **Tiêu chí chấp nhận** | 1. Thêm một phân hệ mới **không** phải sửa `SyncOrchestrator`.<br>2. Gọi `chuanBi("XXX")` với phân hệ chưa có bộ trích xuất → lỗi nêu rõ tên phân hệ. |
| **Truy vết** | `staging/PhanHeExtractor.java` |

#### FR-EXT-02 · Trích xuất phân hệ COSOGIAODUC · **M**

| | |
| --- | --- |
| **Mô tả** | Đọc dữ liệu cơ sở giáo dục từ schema `dwh` và chuyển sang mô hình HEMIS |
| **Phạm vi GĐ1** | Bắt buộc: `_CO_SO_GIAO_DUC` (thông tin chung). Nên có: `_CSGD_KHEN_THUONG`, `_CSGD_KHOA_HOC`, `_CSGD_LICH_SU_DTEN`, `_CSGD_DS_DAU_MOI_LH`, `_CSGD_THONG_TIN_KIEM_DINH`, `_VAN_BAN_TRIEN_KHAI_THUC_HIEN_QUYEN_TU_CHU` |
| **Trường bắt buộc** | `Id`, `Created`, `Modified`, `MA_DON_VI`, `TEN_DON_VI`, `WEBSITE`, `SO_DIEN_THOAI`, `EMAIL`, `DIA_CHI`, `SO_QD_THANH_LAP`, `NGAY_QD_THANH_LAP`, `NGAY_DUOC_CAP_PHEP_HOAT_DONG`, `LOAI_HINH_ID`, `HINH_THUC_THANH_LAP`, `LOAI_CO_SO`, `TRUONG_DAC_THU`, `TINH_THANH_NEW`, `XA_PHUONG_NEW`, `MA_DINH_DANH_ND69` |
| **Tiêu chí chấp nhận** | 1. Thiếu bất kỳ trường bắt buộc nào → lỗi mức chặn, không đóng gói.<br>2. Mọi trường `*_ID` đã là mã HEMIS.<br>3. `TINH_THANH_NEW`, `XA_PHUONG_NEW` lấy từ `DM_TINH_NEW`, `DM_XA_NEW` (địa giới theo QĐ 19/2025/QĐ-TTg), không phải danh mục cũ. |
| **Trạng thái** | Khung đã có, đọc từ cấu hình. **Nối với schema `dwh`: tuần 2** |
| **Truy vết** | [ĐT] mục 4 · `staging/CoSoGiaoDucExtractor.java` |

#### FR-EXT-03 · Định danh GUID ổn định · **M**

| | |
| --- | --- |
| **Mô tả** | Mỗi bản ghi gửi lên HEMIS mang một GUID **không đổi** qua các đợt |
| **Xử lý** | Tra `entity_map (local_table, local_id)`; chưa có thì sinh mới và lưu lại |
| **Lý do** | HEMIS dùng `Id` để quyết định thêm mới hay cập nhật. GUID đổi → dữ liệu nhân bản trên HEMIS |
| **Tiêu chí chấp nhận** | 1. Trích xuất cùng một bản ghi hai lần cho ra cùng một GUID.<br>2. Không có đường nào trong mã sinh GUID cho bản ghi nghiệp vụ mà không qua `entity_map`.<br>3. Xóa và nạp lại dữ liệu nguồn không làm đổi GUID (khóa theo `local_id` nghiệp vụ, không theo khóa tự tăng). |
| **Trạng thái** | Bảng đã có, **logic chưa làm** — tuần 2 |

#### FR-EXT-04 · Trích xuất gia tăng · **S**

Chỉ lấy bản ghi có `Modified` sau lần đồng bộ thành công gần nhất của phân hệ đó. Giai đoạn 1 chấp nhận gửi toàn bộ (phân hệ COSOGIAODUC chỉ có 1 bản ghi).

#### FR-EXT-05 · XML và JSON sinh từ cùng một nguồn · **M**

| | |
| --- | --- |
| **Mô tả** | Hai định dạng gửi đi phải cùng nội dung |
| **Xử lý** | `PhanHeExtractor.Result` trả về đồng thời `xmlLists` và `jsonBody`, dựng từ cùng một đối tượng trong bộ nhớ |
| **Tiêu chí chấp nhận** | 1. Không tồn tại hai đoạn mã độc lập đọc dữ liệu cho XML và cho JSON.<br>2. Có kiểm thử so khớp: mọi trường trong `jsonBody` đều xuất hiện trong XML dưới tên PascalCase tương ứng. |
| **Trạng thái** | Cơ chế đã có; **kiểm thử so khớp chưa làm** |

---

### 3.4 FR-VAL — Kiểm tra dữ liệu

> HEMIS **không trả lỗi theo từng bản ghi** — chỉ một cờ `success` cho cả đợt. Vì vậy
> bộ kiểm tra phía Trường là lớp phòng vệ duy nhất. Đây là nhóm yêu cầu quan trọng nhất
> về mặt chất lượng dữ liệu.

#### FR-VAL-01 · Nạp quy tắc từ cấu hình · **M**

| | |
| --- | --- |
| **Mô tả** | Quy tắc kiểm tra lấy từ bảng `validation_rule`, nạp từ tệp YAML sinh theo bảng trường của [ĐT] |
| **Tiêu chí chấp nhận** | 1. Thêm/sửa quy tắc **không** phải biên dịch lại mã.<br>2. Khóa duy nhất `(ph, entity, field)`. |

#### FR-VAL-02 · Các loại kiểm tra · **M**

| Mã quy tắc | Kiểm tra | Mức |
| --- | --- | --- |
| `REQUIRED` | Trường bắt buộc không rỗng | Chặn |
| `MAX_LENGTH` | Độ dài không vượt quá đặc tả | Chặn |
| `DATA_TYPE` | Đúng kiểu: `string`, `int`, `double`, `date`, `bool`, `guid` | Chặn |
| `CATALOG` | Giá trị tồn tại trong danh mục HEMIS tương ứng | Chặn |
| `CONDITIONAL` | Bắt buộc theo điều kiện, ví dụ `SO_QD_TOT_NGHIEP` bắt buộc khi `TRANG_THAI_ID = '04'` | Chặn |
| `FORMAT` | Định dạng ngày, số căn cước công dân, email | Cảnh báo |

**Tiêu chí chấp nhận**: mỗi loại quy tắc có ít nhất một ca kiểm thử đạt và một ca kiểm thử trượt.

#### FR-VAL-03 · Ghi lỗi theo bản ghi · **M**

| | |
| --- | --- |
| **Xử lý** | Mỗi vi phạm tạo một dòng `sync_error`: `batch_id`, `entity`, `local_id`, `field`, `rule_code`, `severity`, `message`, `owner_unit` |
| **Tiêu chí chấp nhận** | 1. Còn ít nhất một lỗi `severity = BLOCK` → đợt chuyển trạng thái `CHO_SUA_LOI`, **không** đóng gói, **không** đưa vào hàng đợi ký số.<br>2. Chỉ có lỗi `WARN` → vẫn tiếp tục, ghi nhật ký cảnh báo.<br>3. Thông điệp lỗi nêu rõ bản ghi nào, trường nào, vi phạm quy tắc gì. |
| **Trạng thái** | **Chưa làm** — tuần 3 |

#### FR-VAL-04 · Báo cáo lỗi cho đơn vị quản lý dữ liệu · **S**

Xuất danh sách lỗi theo `owner_unit` dưới dạng bảng để gửi cho phòng ban sửa dữ liệu nguồn.

---

### 3.5 FR-PKG — Đóng gói

#### FR-PKG-01 · Sinh IKS và tách k1/k2 · **M**

| | |
| --- | --- |
| **Mô tả** | Mỗi đợt có một `IKS` (GUID 36 ký tự) duy nhất, tách thành `k1` (18 ký tự đầu) và `k2` (18 ký tự cuối) |
| **Tiêu chí chấp nhận** | 1. `k1.length == 18` và `k2.length == 18`.<br>2. `k1 + k2 == IKS` với mọi GUID (kiểm thử 1000 giá trị ngẫu nhiên).<br>3. `Iks.join(k1, k2)` khôi phục đúng IKS.<br>4. Ghép thiếu ký tự → ném `IllegalArgumentException`. |
| **Truy vết** | [ĐT] mục 3.4 · `packaging/Iks.java` · `IksTest.java` (**đã có, 5 ca đạt**) |

#### FR-PKG-02 · Cấu trúc tệp XML · **M**

Sáu quy tắc bắt buộc, sai một là HEMIS từ chối:

| # | Quy tắc | Kiểm thử |
| --- | --- | --- |
| 1 | `DuLieuKySo` có thuộc tính `Id="data"` | `coThuocTinhIdData` ✔ |
| 2 | `k1` là node con **đầu tiên**, `k2` là node con **cuối cùng** | `k1DauTienK2CuoiCung` ✔ |
| 3 | `k1 + k2` khớp IKS của đợt | `ghepLaiRaIksBanDau` ✔ |
| 4 | Thẻ `DanhSachXXX` và tên trường viết **PascalCase** | `danhSachNamGiuaK1VaK2` ✔ |
| 5 | Thẻ `KySo` **ngang hàng** với `DuLieuKySo`, không lồng bên trong | `XmlDsigVerifier.checkStructure()` ✔ |
| 6 | Trong `X509Data`, `X509SubjectName` đứng **trước** `X509Certificate` | `XmlDsigVerifier.checkStructure()` ✔ |

**Truy vết**: [ĐT] mục 3.4 · `packaging/XmlPackager.java` · `XmlPackagerTest.java` (**đã có, 6 ca đạt**)

#### FR-PKG-03 · Chỉ xuất danh sách có dữ liệu · **M**

Danh sách rỗng không được sinh thẻ `DanhSachXXX`. **Kiểm thử**: `boQuaDanhSachRong` ✔

#### FR-PKG-04 · Định dạng giá trị · **M**

| Kiểu | Định dạng | Ghi chú |
| --- | --- | --- |
| Ngày | `yyyy-MM-dd` | Xem MỞ-02 |
| Ngày giờ | `yyyy-MM-dd'T'HH:mm:ss` | Giờ Việt Nam (UTC+7) |
| Đúng/Sai | `true` / `false` | |
| `null` | **Không xuất thẻ** | Không xuất thẻ rỗng |

**Kiểm thử**: `dinhDangGiaTri` ✔

#### FR-PKG-05 · Thân JSON · **M**

| | |
| --- | --- |
| **Cấu trúc** | `t_k` (= IKS), `DomainConnect`, rồi các trường `_XXX` của phân hệ |
| **Tiêu chí chấp nhận** | 1. `t_k` luôn bằng IKS của đợt.<br>2. Tên trường `UPPER_SNAKE`, giữ **nguyên văn** theo đặc tả kể cả khi không nhất quán (`_KHCH_SACH_XUAT_BAN`, `CMTND`).<br>3. Không gửi các trường `CONFIG_VALUE`, `CONFIG_KEY`, `UserName`, `CERTPEM` (API không xử lý). |

#### FR-PKG-06 · Lưu gói dữ liệu · **M**

```
{storage-dir}/{PH}/{IKS}/
  ├── payload.xml           XML chưa ký
  ├── payload.signed.xml    XML đã ký
  └── payload.json          thân JSON
```

**Tiêu chí chấp nhận**: đường dẫn ba tệp được ghi vào `sync_batch`; băm SHA-256 của XML lưu ở `payload_sha256`.

---

### 3.6 FR-SGN — Ký số

#### FR-SGN-01 · Hàng đợi ký số · **M**

| | |
| --- | --- |
| **Xử lý** | Đóng gói xong tạo một `sign_job` trạng thái `PENDING`; đợt chuyển sang `CHO_KY_SO` |
| **Trạng thái job** | `PENDING → LEASED → SIGNED` hoặc `→ FAILED` |
| **Tiêu chí chấp nhận** | 1. Một đợt chỉ có một job đang hoạt động.<br>2. Job `LEASED` quá 30 phút được trả về `PENDING` (tránh kẹt khi trạm ký số tắt giữa chừng). |
| **Trạng thái** | Bảng và API đã có; **cơ chế thu hồi job treo chưa làm** |

#### FR-SGN-02 · API cho tác nhân ký số · **M**

| Lệnh | Đường dẫn | Phản hồi |
| --- | --- | --- |
| Lấy việc | `GET /internal/sign/jobs` | Tối đa 10 job `PENDING` |
| Nhận việc | `POST /internal/sign/jobs/{id}/lease` | XML chưa ký + IKS; job → `LEASED` |
| Trả kết quả | `POST /internal/sign/jobs/{id}/result` | Nhận XML đã ký hoặc thông điệp lỗi |

**Tiêu chí chấp nhận**:
1. Thiếu hoặc sai header `X-Agent-Token` → `401`.
2. `lease` một job không ở trạng thái `PENDING` → `409 Conflict`.
3. Đường dẫn `/internal/**` bị chặn ở reverse proxy, chỉ mở trong mạng nội bộ.

**Truy vết**: `signing/SignAgentController.java` (**đã có**)

#### FR-SGN-03 · Tác nhân ký số trên trạm ký số · **M**

| | |
| --- | --- |
| **Mô tả** | Chương trình chạy trên Windows, kéo việc từ cổng tích hợp, gọi plugin XmlSignerTriNam tại `127.0.0.1:64005`, trả tệp đã ký |
| **Lý do thiết kế kéo** | Plugin chỉ nghe `127.0.0.1`; cơ chế kéo không cần mở cổng vào trạm ký số |
| **Tiêu chí chấp nhận** | 1. Chạy như Windows Service, tự khởi động cùng máy.<br>2. Mất kết nối tới cổng tích hợp → thử lại, không làm hỏng job đang giữ.<br>3. Plugin trả lỗi → gọi `result` với `error`, job → `FAILED`, đợt → `THAT_BAI`.<br>4. Không ghi mã PIN ra tệp hay nhật ký. |
| **Trạng thái** | **Chưa làm** — tuần 2 |
| **Truy vết** | [KS] · `02_KY_SO_XML_DSIG.md` mục 4 |

#### FR-SGN-04 · Tự xác minh trước khi chấp nhận · **M**

| | |
| --- | --- |
| **Mô tả** | Tệp do tác nhân trả về phải qua kiểm tra trước khi ghi nhận |
| **Kiểm tra** | Cấu trúc (6 quy tắc FR-PKG-02) + chữ ký hợp lệ về mặt mật mã + `k1+k2` khớp IKS của đợt |
| **Tiêu chí chấp nhận** | 1. Tệp sai cấu trúc → `400`, job → `FAILED`, **không** ghi đè `payload.signed.xml`.<br>2. Tệp bị sửa sau khi ký → phát hiện được (chữ ký không hợp lệ).<br>3. Ký nhầm tệp của đợt khác → phát hiện qua đối chiếu IKS.<br>4. Chỉ tắt được bằng cấu hình `verify-before-send`, mặc định **bật**. |
| **Truy vết** | `signing/XmlDsigVerifier.java` (**đã có**) |

#### FR-SGN-05 · Chế độ ký thủ công · **S**

| | |
| --- | --- |
| **Mô tả** | Khi `hemis.signing.mode = manual`: hệ thống xuất tệp XML để người dùng ký trên cổng HEMIS theo [KS], rồi nạp lại tệp đã ký |
| **Tiêu chí chấp nhận** | 1. Tải được tệp `payload.xml` từ API quản trị.<br>2. Nạp tệp đã ký lên vẫn đi qua FR-SGN-04. |
| **Trạng thái** | **Chưa làm** |

#### FR-SGN-06 · Lưu trữ tệp đã ký · **M**

Tệp `payload.signed.xml` cùng phản hồi của HEMIS lưu tối thiểu 05 năm, đặt quyền chỉ đọc sau khi ghi. Theo [CV] mục 3.

---

### 3.7 FR-SND — Gửi dữ liệu

#### FR-SND-01 · Nộp tệp XML đã ký (db16) · **M**

| | |
| --- | --- |
| **Xử lý** | `POST {gateway}/dongbodulieubeta/v5/co_so_giao_duc_input/db16/{DON_VI_ID}/{IKS}/{PH}`, `multipart/form-data`, trường `file` |
| **Tiêu chí chấp nhận** | 1. Phần multipart có **tên tệp** (thiếu tên tệp thì máy chủ từ chối).<br>2. `success = true` → đợt chuyển `DA_GUI_XML`.<br>3. `success = false` → đợt `THAT_BAI`, ghi `message` của HEMIS vào `sync_batch.message`. |
| **Truy vết** | [ĐT] mục 3 · `HemisSyncClient.uploadSignedXml()` (**đã có**) |

#### FR-SND-02 · Gửi thân JSON (dbN) · **M**

| | |
| --- | --- |
| **Xử lý** | `POST .../{api}/{DON_VI_ID}/{IdKey}`, `application/json`, thân có `t_k = IKS` |
| **Tiêu chí chấp nhận** | 1. Chỉ gọi khi đợt đã ở trạng thái `DA_GUI_XML`.<br>2. `success = true` → `DA_GUI_JSON`, ghi `sent_at`.<br>3. Mã API lấy từ `PhanHeExtractor.api()`, không gắn cứng. |
| **Truy vết** | [ĐT] mục 4–15 · `HemisSyncClient.syncJson()` (**đã có**) |

#### FR-SND-03 · Thứ tự bắt buộc · **M**

| | |
| --- | --- |
| **Mô tả** | Luôn gọi db16 **trước** dbN với cùng IKS |
| **Tiêu chí chấp nhận** | Gọi `gui()` khi đợt chưa ở trạng thái `DA_KY_SO` → ném lỗi nêu rõ trạng thái hiện tại |
| **Ghi chú** | [ĐT] ghi db3 "hiện KHÔNG xác thực `t_k`" — vẫn giữ thứ tự cho thống nhất. Xem MỞ-08 |

#### FR-SND-04 · Chống gửi trùng · **M**

| | |
| --- | --- |
| **Mô tả** | IKS là khóa chống gửi trùng của HEMIS |
| **Tiêu chí chấp nhận** | 1. `sync_batch.iks` có ràng buộc duy nhất.<br>2. Thử lại một đợt **không** sinh IKS mới.<br>3. HEMIS trả "Dữ liệu đã tồn tại" → ghi rõ trong `message`, **không** tự động sinh IKS mới và gửi lại. |

#### FR-SND-05 · Thử lại có kiểm soát · **M**

| | |
| --- | --- |
| **Xử lý** | Tối đa `max-retries` lần; chờ tăng dần `retry-backoff-seconds × lần thử`; 401 thì lấy token mới trước khi thử lại |
| **Tiêu chí chấp nhận** | 1. Không thử lại vô hạn.<br>2. Mỗi lần thử ghi một dòng cảnh báo trong nhật ký.<br>3. Hết số lần thử → ném lỗi kèm nguyên nhân lần cuối. |

#### FR-SND-06 · Nén gzip · **S**

Bật bằng `hemis.upload.gzip`; khi bật, tên tệp kết thúc `.gz`. Theo [ĐT] mục 3.3.

---

### 3.8 FR-JRN — Nhật ký

> [CV] mục 3 yêu cầu: *"có cơ chế ghi nhận nhật ký kết nối, theo dõi trạng thái đồng bộ và
> lưu thông tin lỗi để phục vụ kiểm tra, đối soát và xử lý sự cố"*. Đây là yêu cầu **pháp lý**,
> không phải tùy chọn kỹ thuật.

#### FR-JRN-01 · Trạng thái đợt đồng bộ · **M**

```
KHOI_TAO ─► DA_DONG_GOI ─► CHO_KY_SO ─► DA_KY_SO ─► DA_GUI_XML ─► DA_GUI_JSON ─► DA_DOI_SOAT
                │                            │             │              │
                ▼                            ▼             ▼              ▼
          CHO_SUA_LOI                    THAT_BAI      THAT_BAI       THAT_BAI
```

**Tiêu chí chấp nhận**: mọi chuyển trạng thái đều được ghi; không có đường nào đi từ `KHOI_TAO` thẳng tới `DA_GUI_XML`.

#### FR-JRN-02 · Nhật ký gọi API · **M**

| | |
| --- | --- |
| **Ghi gì** | `batch_id`, `method`, `url`, `http_status`, `success`, `request_bytes`, `duration_ms`, trích yếu phản hồi, lỗi |
| **Tiêu chí chấp nhận** | 1. Mỗi lần gọi db16 và dbN đều có một dòng `api_log`, **kể cả khi thất bại**.<br>2. Trích yếu phản hồi cắt ngắn ≤ 2000 ký tự. |

#### FR-JRN-03 · Bảo vệ dữ liệu cá nhân trong nhật ký · **M**

| | |
| --- | --- |
| **Mô tả** | Không ghi số căn cước công dân, mật khẩu, mã PIN, `client_secret`, nội dung token vào nhật ký hoặc bảng `api_log` |
| **Căn cứ** | Nghị định 13/2023/NĐ-CP; [CV] mục 3 |
| **Tiêu chí chấp nhận** | Rà soát mã: không có lệnh ghi nhật ký nào xuất các trường trên. Có kiểm thử cho hàm che dữ liệu. |
| **Trạng thái** | Nguyên tắc đã áp dụng; **hàm che và kiểm thử chưa làm** |

---

### 3.9 FR-ADM — Quản trị và theo dõi

#### FR-ADM-01 · API quản trị · **M**

| Lệnh | Đường dẫn | Mức |
| --- | --- | --- |
| Kiểm tra kết nối | `POST /api/v1/hemis/kiem-tra-token` | M |
| Tải danh mục | `POST /api/v1/hemis/danh-muc/tai-ve` | M |
| Chuẩn bị đợt | `POST /api/v1/hemis/dot/{ph}/chuan-bi` | M |
| Gửi đợt | `POST /api/v1/hemis/dot/{id}/gui` | M |
| Danh sách đợt | `GET /api/v1/hemis/dot?ph=&limit=` | M |
| Chi tiết đợt | `GET /api/v1/hemis/dot/{id}` | M |
| Nhật ký đợt | `GET /api/v1/hemis/dot/{id}/nhat-ky` | M |
| Danh sách lỗi | `GET /api/v1/hemis/dot/{id}/loi` | S — **chưa làm** |
| Tải tệp gói | `GET /api/v1/hemis/dot/{id}/tep/{loai}` | S — **chưa làm** |

#### FR-ADM-02 · Màn hình theo dõi · **S**

Một trang hiển thị: danh sách đợt gần nhất với trạng thái, số bản ghi, thời điểm; chi tiết một đợt kèm nhật ký và danh sách lỗi. Giai đoạn 1 chấp nhận giao diện tối thiểu.

#### FR-ADM-03 · Xác thực người dùng · **L**

Giai đoạn 1 chạy trong mạng nội bộ, chưa có đăng nhập. Giai đoạn 3 tích hợp SSO của Trường và phân quyền theo vai trò (xem, sửa, duyệt gửi, ký).

---

### 3.10 FR-DQ — Đo chất lượng cập nhật dữ liệu (Chuẩn cơ sở giáo dục đại học)

> Nhóm yêu cầu này sinh ra từ [TT83]. Mục đích: phần mềm không chỉ gửi được dữ liệu mà còn
> **chứng minh được** dữ liệu đã cập nhật đầy đủ, đúng hạn, đúng định dạng, hợp lệ và nhất quán
> — đúng 5 điều kiện của Tiêu chí 1.3, và sinh ra Bảng 1C mà không phải tổng hợp thủ công.

#### FR-DQ-01 · Theo dõi trạng thái cập nhật theo nhóm dữ liệu · **M**

| | |
| --- | --- |
| **Mô tả** | Hệ thống quản lý danh sách nhóm dữ liệu của Bảng 1C và trạng thái cập nhật từng nhóm trong kỳ đánh giá |
| **Dữ liệu theo dõi** | `nhom_du_lieu`, `bat_buoc` (1/0), `ngay_phai_cap_nhat`, `ngay_cap_nhat_thuc_te`, `dung_han` (1/0), `day_du` (%), `tin_cay` (%), `dat_dieu_kien` (1/0), `ky_danh_gia` (năm) |
| **Xử lý** | `ngay_cap_nhat_thuc_te` lấy từ đợt đồng bộ **thành công gần nhất** của phân hệ tương ứng; `dung_han` tính tự động bằng cách so với `ngay_phai_cap_nhat` |
| **Tiêu chí chấp nhận** | 1. Đợt đồng bộ đạt `DA_GUI_JSON` tự động cập nhật `ngay_cap_nhat_thuc_te` của nhóm tương ứng.<br>2. `dung_han` tính tự động, không nhập tay.<br>3. Một nhóm chưa từng đồng bộ thành công → `dat_dieu_kien = 0`. |
| **Truy vết** | [TT83] Phụ lục V Bảng 1C |
| **Trạng thái** | **Chưa làm** — cần bảng mới trong schema, xem RÀNG BUỘC-09 |

#### FR-DQ-02 · Tính độ đầy đủ theo trường bắt buộc · **M**

| | |
| --- | --- |
| **Mô tả** | Tính `đầy đủ (%)` = số trường bắt buộc có giá trị hợp lệ / tổng số trường bắt buộc thuộc phạm vi áp dụng |
| **Nguồn tổng số** | Danh sách trường bắt buộc trong `validation_rule` (`required = true`) theo từng phân hệ |
| **Tiêu chí chấp nhận** | 1. Trường bắt buộc rỗng, sai định dạng, hoặc mã danh mục chưa ánh xạ đều **không** tính là đạt.<br>2. Kết quả truy ngược được tới từng bản ghi và từng trường qua `sync_error`.<br>3. Tính được cho cả nhóm chưa gửi (dựa trên dữ liệu trong kho, không cần gửi mới biết thiếu). |
| **Lý do** | Chỉ số 1.3 yêu cầu **100%**; phải biết thiếu gì **trước** 31/12, không phải sau khi Bộ đối sánh |
| **Trạng thái** | **Chưa làm** — phụ thuộc FR-VAL |

#### FR-DQ-03 · Báo cáo khoảng trống dữ liệu · **M**

| | |
| --- | --- |
| **Mô tả** | Báo cáo cho biết còn thiếu những trường bắt buộc nào, thuộc bản ghi nào, đơn vị nào chịu trách nhiệm |
| **Tiêu chí chấp nhận** | 1. Nhóm theo `owner_unit` để gửi thẳng cho phòng, ban.<br>2. Xuất được ra bảng để đính kèm văn bản.<br>3. Chạy được **bất kỳ lúc nào**, không cần tạo đợt đồng bộ. |
| **Ưu tiên** | Cao — đây là công cụ chính để đạt 100% trước 31/12/2026 |
| **Trạng thái** | **Chưa làm** |

#### FR-DQ-04 · Sinh Bảng 1C · **S**

| | |
| --- | --- |
| **Mô tả** | Xuất Bảng 1C theo đúng mẫu [TT83] Phụ lục V cho một kỳ đánh giá |
| **Tiêu chí chấp nhận** | 1. Đủ 14 dòng nhóm dữ liệu, đúng thứ tự mẫu.<br>2. Mọi cột tính tự động từ nhật ký, chỉ `bat_buoc` và `ngay_phai_cap_nhat` nhập tay.<br>3. Xuất được ra Excel. |
| **Trạng thái** | **Chưa làm** — Giai đoạn 2 |

#### FR-DQ-05 · Ghi nhận nguồn gốc dữ liệu · **S**

| | |
| --- | --- |
| **Mô tả** | Mỗi nhóm dữ liệu ghi rõ lấy từ hệ thống nguồn nào trong 5 nguồn chính thức của [TT83] Điều 8 |
| **Lý do** | [TT83] Điều 4.5 yêu cầu dữ liệu "được kiểm chứng độc lập, truy xuất và đối soát" |
| **Tiêu chí chấp nhận** | Mỗi dòng trong bảng theo dõi nhóm dữ liệu có trường `he_thong_nguon` và `ngay_trich_xuat` |
| **Trạng thái** | **Chưa làm** |

#### FR-DQ-06 · Không tính trùng · **S**

| | |
| --- | --- |
| **Mô tả** | [TT83] Điều 4.5 và Điều 7.3: không tính trùng giữa các đơn vị, chương trình đào tạo hoặc địa điểm đào tạo trong cùng kỳ đánh giá |
| **Tiêu chí chấp nhận** | Kiểm thử phát hiện được một người học hoặc một giảng viên xuất hiện hai lần trong cùng một đợt |
| **Trạng thái** | **Chưa làm** |

---

### 3.11 FR-REC — Đối soát

#### FR-REC-01 · Ghi nhận kết quả đối soát · **S**

Sau khi gửi, cán bộ quản lý dữ liệu kiểm tra trên giao diện HEMIS và ghi kết quả vào hệ thống; đợt chuyển trạng thái `DA_DOI_SOAT`. Theo [CV] mục 2c, thực hiện trong 03 ngày làm việc.

#### FR-REC-02 · Đối soát tự động · **L**

Phụ thuộc MỞ-05 — hiện chưa rõ HEMIS có API tra cứu kết quả theo `IdKey` hay không.

---

## 4. Yêu cầu phi chức năng

### NFR-PER — Hiệu năng

| Mã | Yêu cầu | Cách đo |
| --- | --- | --- |
| NFR-PER-01 | Một đợt phân hệ COSOGIAODUC (≈ 1 bản ghi) hoàn tất dưới 30 giây, không tính thời gian ký số | Đo `duration_ms` trong `api_log` |
| NFR-PER-02 | Một đợt 30.000 bản ghi (phân hệ người học) đóng gói và gửi dưới 15 phút, có bật gzip | Kiểm thử hiệu năng, Giai đoạn 2 |
| NFR-PER-03 | Tải hơn 175 danh mục hoàn tất trong thời gian chờ đọc 180 giây | Nhật ký của FR-CAT-01 |
| NFR-PER-04 | Bộ nhớ: đóng gói 30.000 bản ghi không vượt 2 GB heap | Giai đoạn 2, dùng ghi theo luồng nếu cần |

### NFR-REL — Độ tin cậy

| Mã | Yêu cầu |
| --- | --- |
| NFR-REL-01 | Gửi lại một đợt đã gửi thành công **không** tạo dữ liệu trùng trên HEMIS (bảo đảm bằng IKS duy nhất) |
| NFR-REL-02 | Ứng dụng khởi động lại giữa chừng không làm mất đợt đang xử lý; trạng thái phục hồi từ cơ sở dữ liệu |
| NFR-REL-03 | Trạm ký số tắt không làm hỏng cổng tích hợp; job treo được thu hồi sau 30 phút |
| NFR-REL-04 | Lỗi mạng tạm thời được thử lại tự động; lỗi nghiệp vụ **không** thử lại |

### NFR-SEC — An toàn thông tin

| Mã | Yêu cầu | Căn cứ |
| --- | --- | --- |
| NFR-SEC-01 | Bí mật (`client_secret`, mật khẩu, mã PIN, token tác nhân) lấy từ biến môi trường hoặc kho bí mật, **không** nằm trong mã nguồn hay kho mã | [CV] mục 3 |
| NFR-SEC-02 | Không có bí mật nào bị commit; `.gitignore` chặn `.env`, `*.p12`, `*.pfx`, `*.jks`, `*.key`, `*.pem` | |
| NFR-SEC-03 | Đường dẫn `/internal/**` chỉ truy cập được từ mạng nội bộ, bắt buộc header `X-Agent-Token` | |
| NFR-SEC-04 | Mọi kết nối ra HEMIS dùng HTTPS; không tắt kiểm tra chứng thư TLS | |
| NFR-SEC-05 | Không ghi dữ liệu cá nhân vào nhật ký (xem FR-JRN-03) | NĐ 13/2023 |
| NFR-SEC-06 | Tài khoản cơ sở dữ liệu của ứng dụng chỉ có quyền cần thiết trên `hemis_sync` và quyền đọc trên `dwh` | |
| NFR-SEC-07 | Chỉ cho phép kết nối ra Internet tới `*.moet.gov.vn` và nhà cung cấp chữ ký số | [PA] mục II.5 |

### NFR-OPS — Vận hành

| Mã | Yêu cầu |
| --- | --- |
| NFR-OPS-01 | Có điểm kiểm tra sức khỏe `/actuator/health` và số liệu `/actuator/prometheus` |
| NFR-OPS-02 | Cảnh báo qua email khi: đợt thất bại, không lấy được token, HEMIS trả 4xx/5xx |
| NFR-OPS-03 | Sao lưu cơ sở dữ liệu hằng ngày, kiểm thử khôi phục tối thiểu 01 lần trong Giai đoạn 1 |
| NFR-OPS-04 | Thay đổi địa chỉ máy chủ của Bộ chỉ cần sửa cấu hình, **không** phải biên dịch lại |
| NFR-OPS-05 | Nhật ký ứng dụng ghi dạng dòng, có mã đợt/IKS để truy vết |

### NFR-MNT — Khả năng bảo trì

| Mã | Yêu cầu |
| --- | --- |
| NFR-MNT-01 | Thêm một phân hệ mới chỉ cần thêm một lớp `PhanHeExtractor`, không sửa `SyncOrchestrator` |
| NFR-MNT-02 | Mọi quy tắc cấu trúc trong [ĐT] đều có ít nhất một kiểm thử tự động |
| NFR-MNT-03 | Mỗi chỗ cố ý chưa làm đều có ghi chú `TODO` kèm tuần dự kiến trong mã nguồn |
| NFR-MNT-04 | Thay đổi cơ sở dữ liệu qua Flyway, không sửa trực tiếp trên máy chủ |
| NFR-MNT-05 | Bộ chuyển đổi từng phân hệ có phiên bản, chịu được việc đặc tả của Bộ thay đổi |

### NFR-CMP — Tuân thủ

| Mã | Yêu cầu | Căn cứ |
| --- | --- | --- |
| NFR-CMP-01 | Dữ liệu được ký số trước khi đồng bộ | [CV] mục 1 |
| NFR-CMP-02 | Có nhật ký kết nối, trạng thái đồng bộ, thông tin lỗi | [CV] mục 3 |
| NFR-CMP-03 | Lưu tệp đã ký và phản hồi tối thiểu 05 năm | [CV] mục 3 |
| NFR-CMP-04 | Bảo vệ dữ liệu cá nhân | NĐ 13/2023/NĐ-CP |
| NFR-CMP-05 | Dữ liệu năm đánh giá chốt tại 31/12 (tài chính 31/3 năm sau) phải có trên HEMIS đầy đủ, đúng hạn, đúng định dạng, hợp lệ, nhất quán | [TT83] Điều 6 Tiêu chí 1.3, Điều 13.2a |
| NFR-CMP-06 | Hệ thống phải chứng minh được mức đạt của chỉ số 1.3 bằng số liệu truy xuất từ nhật ký, không phải bằng tổng hợp thủ công | [TT83] Phụ lục II chỉ số 1.3, Phụ lục V Bảng 1C |
| NFR-CMP-07 | Dữ liệu phải truy xuất được về hệ thống nguồn và kiểm chứng độc lập được | [TT83] Điều 4.5, Điều 8 |

---

## 5. Ràng buộc thiết kế

| Mã | Ràng buộc | Nguồn |
| --- | --- | --- |
| RÀNG BUỘC-01 | Plugin ký số chỉ chạy Windows và chỉ nghe `127.0.0.1:64005` → bắt buộc có trạm ký số riêng và tác nhân kéo việc | [KS] |
| RÀNG BUỘC-02 | Một lần gọi API danh mục trả về hơn 175 danh mục → phải đặt thời gian chờ dài và xử lý phản hồi lớn | [ĐT] mục 2 |
| RÀNG BUỘC-03 | HEMIS không trả lỗi theo bản ghi → bắt buộc kiểm tra phía Trường và đối soát sau khi gửi | [ĐT] |
| RÀNG BUỘC-04 | Tên trường XML (PascalCase) khác tên trường JSON (UPPER_SNAKE) → phải sinh hai dạng từ một nguồn | [ĐT] mục 3.4 |
| RÀNG BUỘC-05 | Giữ nguyên schema `dwh` hiện có, không sửa cấu trúc | [PA] |
| RÀNG BUỘC-06 | Không thay thế backend FastAPI trong Giai đoạn 1 | [PA] mục III.2 |
| RÀNG BUỘC-07 | Chạy trên hạ tầng hiện có, không chờ mua sắm | [PA] mục I.3 |
| RÀNG BUỘC-08 | Spring Boot 4 dùng Jackson 3 (`tools.jackson.*`), không phải Jackson 2 | Môi trường |
| RÀNG BUỘC-09 | 14 nhóm dữ liệu của Bảng 1C **không trùng khớp 1:1** với 12 phân hệ của API HEMIS (ví dụ Bảng 3D "Hạ tầng CNTT và hệ thống học tập số", Bảng 5C/KS "Khảo sát việc làm và hài lòng người học" không có phân hệ API tương ứng rõ ràng) → cần một bảng ánh xạ do nghiệp vụ quyết định, **chưa tự quyết trong mã** | [TT83] Phụ lục V |
| RÀNG BUỘC-10 | Thời điểm chốt số liệu 31/12 hằng năm (tài chính 31/3 năm sau) → hệ thống phải lưu được **ảnh chụp theo kỳ đánh giá**, không chỉ trạng thái hiện tại | [TT83] Điều 13.2a |

---

## 6. Ma trận truy vết

| Yêu cầu | [ĐT] mục | Mã nguồn | Kiểm thử | Tuần | Trạng thái |
| --- | --- | --- | --- | --- | --- |
| FR-AUTH-01..03 | 1 | `client/HemisAuthClient` | *chưa có* | 1 | Xong mã, thiếu test |
| FR-CAT-01 | 2 | `client/HemisCatalogClient` | *chưa có* | 1 | Xong mã, thiếu test |
| FR-CAT-02..03 | 2 | — | — | 2 | **Chưa làm** |
| FR-EXT-01 | — | `staging/PhanHeExtractor` | — | 1 | Xong |
| FR-EXT-02 | 4 | `staging/CoSoGiaoDucExtractor` | *chưa có* | 2 | Khung |
| FR-EXT-03 | — | bảng `entity_map` | — | 2 | **Chưa làm** |
| FR-EXT-05 | — | `PhanHeExtractor.Result` | *chưa có* | 2 | Cơ chế có |
| FR-VAL-01..04 | mọi mục | bảng `validation_rule` | — | 3 | **Chưa làm** |
| FR-PKG-01 | 3.4 | `packaging/Iks` | `IksTest` (5 ca) | 1 | **Xong** ✔ |
| FR-PKG-02..04 | 3.4 | `packaging/XmlPackager` | `XmlPackagerTest` (6 ca) | 1 | **Xong** ✔ |
| FR-PKG-05..06 | 4.3 | `sync/SyncOrchestrator` | *chưa có* | 1 | Xong mã |
| FR-SGN-01..02 | — | `signing/SignAgentController` | *chưa có* | 1 | Xong mã |
| FR-SGN-03 | [KS] | *tác nhân Windows* | — | 2 | **Chưa làm** |
| FR-SGN-04 | 3.4 | `signing/XmlDsigVerifier` | *chưa có* | 1 | Xong mã |
| FR-SND-01..05 | 3, 4–15 | `client/HemisSyncClient` | *chưa có* | 3 | Xong mã |
| FR-JRN-01..02 | — | `journal/*` | *chưa có* | 1 | Xong mã |
| FR-JRN-03 | [CV] 3 | — | — | 3 | **Chưa làm** |
| FR-ADM-01 | — | `api/AdminController` | *chưa có* | 1 | Một phần |
| FR-ADM-02 | — | — | — | 4 | **Chưa làm** |
| FR-DQ-01..03 | [TT83] 1.3, Bảng 1C | — | — | **sau GĐ1** | **Chưa làm** |
| FR-DQ-04..06 | [TT83] Phụ lục V | — | — | GĐ2 | **Chưa làm** |
| FR-REC-01 | [CV] 2c | — | — | 4 | **Chưa làm** |

**Khoảng trống lớn nhất hiện nay**: chỉ có 11 ca kiểm thử, phủ FR-PKG. Các nhóm FR-AUTH,
FR-SND, FR-SGN đã có mã nhưng **chưa có kiểm thử** — ưu tiên bổ sung bằng WireMock trong tuần 2.

---

## 7. Điểm chưa rõ — chờ Bộ trả lời

Không được tự đoán rồi viết mã theo phỏng đoán. Khi có câu trả lời, cập nhật bảng này
kèm ngày và sửa yêu cầu liên quan.

| Mã | Câu hỏi | Ảnh hưởng tới | Xử lý tạm thời |
| --- | --- | --- | --- |
| MỞ-01 | Có bắt buộc gọi db16 trước dbN không? HEMIS có đối chiếu nội dung hai bản? | FR-SND-03, FR-EXT-05 | Luôn gọi db16 trước; sinh hai bản từ một nguồn |
| MỞ-02 | Định dạng ngày chính thức: `yyyy-MM-dd` (bảng trường) hay `dd/MM/yyyy` (ví dụ XML)? | FR-PKG-04 | Dùng `yyyy-MM-dd`, đổi được qua hằng số |
| MỞ-03 | `expires_in = 900000` là giây hay mili giây? | FR-AUTH-02 | Lấy `min(expires_in, 900)` giây |
| MỞ-04 | "Tệp XML mã hóa dưới dạng chuỗi JSON string" nghĩa là gì? | FR-SND-01 | Gửi XML nguyên bản; bật được bằng cấu hình |
| MỞ-05 | Có API tra cứu kết quả theo `IdKey` và lỗi theo bản ghi? | FR-REC-02 | Đối soát thủ công trên giao diện |
| MỞ-06 | Khi nào chuyển từ `gwdev/...beta` sang môi trường chính thức? | NFR-OPS-04 | Địa chỉ trong cấu hình |
| MỞ-07 | `_CO_CAU_TO_CHUC` đang vô hiệu hóa — khi nào có hiệu lực? | FR-EXT-02 | Chưa gửi |
| MỞ-08 | db3 ghi "không xác thực `t_k`" — có đổi không? | FR-SND-03 | Vẫn gọi db16 trước |

---

## 8. Tiêu chí nghiệm thu Giai đoạn 1

Ánh xạ sang 10 tiêu chí trong [PA] mục V. Giai đoạn 1 đạt khi **toàn bộ** mục dưới đây đạt:

| # | Tiêu chí | Yêu cầu liên quan | Cách kiểm chứng |
| --- | --- | --- | --- |
| 1 | Lấy và tự làm mới được token | FR-AUTH-01..03 | Chạy thử + `api_log` |
| 2 | Tải và lưu được hơn 175 danh mục | FR-CAT-01..02 | Truy vấn `catalog_hemis` |
| 3 | Sinh XML đúng 6 quy tắc cấu trúc | FR-PKG-02 | `./mvnw test` + đối chiếu tệp mẫu của Bộ |
| 4 | Ký số bằng USB token qua tác nhân, tự xác minh đạt | FR-SGN-03..04 | Chạy thử + nhật ký trạm ký số |
| 5 | Gửi thành công db16 và db1 cho COSOGIAODUC | FR-SND-01..02 | `success = true` trong `api_log` |
| 6 | Dữ liệu hiển thị đúng trên HEMIS, đối soát khớp | FR-REC-01 | Biên bản đối soát |
| 7 | Nhật ký đầy đủ theo mã phiên, lưu tệp gửi và phản hồi | FR-JRN-01..02, FR-PKG-06 | Kiểm tra thư mục + `sync_batch` |
| 8 | Có màn hình theo dõi trạng thái và danh sách lỗi | FR-ADM-01..02 | Trình diễn |
| 9 | Sao lưu hằng ngày, đã kiểm thử khôi phục 01 lần | NFR-OPS-03 | Biên bản |
| 10 | Có tài liệu vận hành và quy trình ký số | — | Hồ sơ bàn giao |

> **Giai đoạn 1 đạt không có nghĩa là xong.** Theo [TT83], đích thực sự là 31/12/2026 với
> chỉ số 1.3 đạt 100%. Mục 8 này chỉ nghiệm thu phần *kỹ thuật kết nối*.

---

## 9. Sau Giai đoạn 1 — việc bắt buộc để đạt chỉ số 1.3 trước 31/12/2026

Không thuộc phạm vi nghiệm thu Giai đoạn 1 nhưng phải lên kế hoạch ngay, vì chỉ còn
khoảng 7 tuần sau khi Giai đoạn 1 kết thúc.

| # | Việc | Phụ thuộc | Vì sao không hoãn được |
| --- | --- | --- | --- |
| 1 | Chốt bảng ánh xạ 14 nhóm dữ liệu Bảng 1C ↔ 12 phân hệ API | Quyết định nghiệp vụ, không tự quyết trong mã (RÀNG BUỘC-09) | Không có bảng này thì không tính được chỉ số 1.3 |
| 2 | Hoàn thành FR-VAL cho **toàn bộ** phân hệ, không chỉ COSOGIAODUC | FR-VAL-01..03 | Phải biết thiếu trường nào **trước** 31/12 |
| 3 | Chạy FR-DQ-03 (báo cáo khoảng trống) và gửi từng phòng, ban | FR-DQ-02 | Làm sạch dữ liệu là việc của đơn vị, cần thời gian |
| 4 | Đồng bộ đủ 12 phân hệ, không chỉ 5 phân hệ ưu tiên | Bộ trích xuất từng phân hệ | Mọi nhóm trong Bảng 1C đều tính vào chỉ số |
| 5 | Chốt số liệu tài chính (hạn 31/3/2027) | Phòng Kế hoạch - Tài chính | Hạn khác với các nhóm còn lại |
| 6 | Ảnh chụp dữ liệu theo kỳ đánh giá 2026 | RÀNG BUỘC-10 | Sau 31/12 dữ liệu nguồn vẫn thay đổi, phải giữ được bản chốt |

---

## 10. Lịch sử thay đổi

| Phiên bản | Ngày | Nội dung | Người sửa |
| --- | --- | --- | --- |
| 1.1 | 12/10/2026 | Bổ sung [TT83] Chuẩn cơ sở giáo dục đại học: mục 1.5, nhóm FR-DQ, RÀNG BUỘC-09/10, NFR-CMP-05..07, mục 9 | Phòng CNTT |
| 1.0 | 12/10/2026 | Bản đầu, áp dụng cho Giai đoạn 1 | Phòng CNTT |

> Khi [ĐT] của Bộ ra phiên bản mới: rà lại mục 3 và mục 7, nâng phiên bản tài liệu này,
> ghi rõ yêu cầu nào thay đổi để nhóm biết phải sửa mã ở đâu.
