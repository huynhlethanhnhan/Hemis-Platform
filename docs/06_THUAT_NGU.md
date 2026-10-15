# 06. Thuật ngữ

Tra nhanh khi đọc tài liệu của Bộ hoặc mã nguồn.

---

## Thuật ngữ của HEMIS

| Thuật ngữ | Giải thích |
| --- | --- |
| **HEMIS** | Hệ thống cơ sở dữ liệu về giáo dục đại học của Bộ Giáo dục và Đào tạo (*Higher Education Management Information System*) |
| **Cục KHCN&TT** | Cục Khoa học, Công nghệ và Thông tin — đơn vị của Bộ quản lý kỹ thuật HEMIS, cấp tài khoản kết nối |
| **Vụ GDĐH** | Vụ Giáo dục Đại học — đầu mối về nghiệp vụ, nội dung dữ liệu |
| **DON_VI_ID** | Mã định danh (Guid 36 ký tự) của cơ sở giáo dục trên HEMIS, do Bộ cấp. Phải thuộc quyền quản lý của tài khoản gọi API |
| **MA_DON_VI** | Mã đơn vị dạng chuỗi ngắn trên HEMIS (khác `DON_VI_ID`) |
| **IKS** | Mã định danh phiên **ký số** (Guid 36 ký tự). Khóa duy nhất của một đợt; tách thành `k1` và `k2` nhúng trong tệp XML. Trùng IKS → lỗi "Dữ liệu đã tồn tại" |
| **IdKey** | Mã định danh phiên **đồng bộ**, do bên gọi tự sinh, dùng tra cứu nhật ký trên HEMIS. Khác IKS |
| **t_k** | Trường trong thân JSON, mang giá trị IKS đã xác thực ở bước db16 |
| **PH** | Mã phân hệ dữ liệu: `COSOGIAODUC`, `CANBO`, `HOIDONG`, `NGANHDT`, `DAOTAO`, `TUYENSINH`, `HOCVIEN`, `VANBANG`, `NCKH`, `COSOVATCHAT`, `TAISAN`, `HTQT`, `HTDN` |
| **dbN** | Mã API đồng bộ JSON theo phân hệ: `db1` (cơ sở giáo dục), `db3` (đội ngũ), `db7` (người học)... Không có `db8` |
| **db16** | API nộp tệp XML đã ký số |
| **Danh mục dùng chung** | Hơn 175 bảng danh mục chuẩn của HEMIS (dân tộc, tôn giáo, ngành, tỉnh/xã...). Mọi trường `*_ID` phải dùng mã của các danh mục này |
| **DM_TINH_NEW, DM_XA_NEW** | Danh mục tỉnh, xã theo địa giới hành chính mới (Quyết định 19/2025/QĐ-TTg). Các trường `TINH_THANH_NEW`, `XA_PHUONG_NEW` là **bắt buộc** |
| **MA_DINH_DANH_ND69** | Mã định danh theo Nghị định 69, trường bắt buộc của cơ sở giáo dục |
| **Bảng trung gian** | Nơi HEMIS nhận dữ liệu trước khi xử lý vào cơ sở dữ liệu chính. `success: true` nghĩa là **đã nhận**, chưa chắc đã xử lý xong |
| **Đối soát** | Kiểm tra lại dữ liệu đã lên HEMIS có khớp với nguồn không, làm sau mỗi đợt, trong 03 ngày làm việc |

---

## Thuật ngữ ký số

| Thuật ngữ | Giải thích |
| --- | --- |
| **XML-DSig** | Chuẩn chữ ký số cho tài liệu XML của W3C |
| **Enveloped signature** | Kiểu chữ ký nằm bên trong chính tài liệu được ký — HEMIS dùng kiểu này |
| **Canonicalization (c14n)** | Chuẩn hóa XML trước khi băm, để khoảng trắng và thứ tự thuộc tính không làm đổi kết quả. HEMIS dùng `exc-c14n` |
| **DigestValue** | Giá trị băm SHA-256 của phần dữ liệu đã chuẩn hóa |
| **SignatureValue** | Chữ ký RSA-SHA256 trên khối `SignedInfo` |
| **X509Certificate** | Chứng thư số công khai, nhúng dạng base64 trong `KeyInfo/X509Data` |
| **X509SubjectName** | Tên chủ thể chứng thư. Phải đứng **trước** `X509Certificate` |
| **SigningTime** | Thời điểm ký, định dạng `yyyy-MM-ddTHH:mm:ss`, giờ Việt Nam (UTC+7) |
| **USB token** | Thiết bị phần cứng chứa khóa riêng của chứng thư số |
| **XmlSignerTriNam** | Plugin ký số do Bộ cung cấp, chạy trên Windows, lắng nghe tại `127.0.0.1:64005` |
| **VGCA** | Ban Cơ yếu Chính phủ — nhà cung cấp chứng thư số cho cơ quan nhà nước |
| **SmartCA / MySign** | Dịch vụ ký số từ xa của VNPT và Viettel, ký qua API, không cần USB token |
| **PKCS#11** | Chuẩn giao tiếp với thiết bị mật mã (USB token, HSM) |
| **HSM** | Thiết bị bảo mật phần cứng chuyên dụng để lưu khóa và ký số |

---

## Thuật ngữ của dự án này

| Thuật ngữ | Giải thích |
| --- | --- |
| **hemis-platform** | Dự án này — cổng tích hợp dữ liệu HEMIS, viết bằng Java Spring Boot |
| **HEMIS-DWH** | Kho dữ liệu hiện có của Trường (PostgreSQL, 13 module, schema `dwh`) |
| **data-service** | Backend FastAPI hiện có, đảm nhiệm nhập liệu Excel, làm sạch, phân tích |
| **schema hemis_sync** | Vùng làm việc riêng của cổng tích hợp, tách khỏi schema nghiệp vụ `dwh` |
| **Đợt đồng bộ (sync_batch)** | Một lần gửi dữ liệu một phân hệ lên HEMIS |
| **entity_map** | Bảng ánh xạ khóa nội bộ sang GUID gửi cho HEMIS. GUID sinh một lần, giữ cố định |
| **catalog_map** | Bảng ánh xạ mã danh mục nội bộ sang mã danh mục HEMIS |
| **Trạm ký số** | Máy Windows cắm USB token, chạy plugin và tác nhân ký số |
| **Tác nhân ký số (sign agent)** | Chương trình trên trạm ký số, kéo việc từ cổng tích hợp, ký rồi trả kết quả |
| **Bộ trích xuất (extractor)** | Lớp đọc dữ liệu một phân hệ từ kho dữ liệu và chuyển sang mô hình HEMIS |
| **WireMock** | Công cụ mô phỏng API của Bộ, dùng để phát triển khi chưa có tài khoản |

---

## Thuật ngữ kỹ thuật chung

| Thuật ngữ | Giải thích |
| --- | --- |
| **GUID / UUID** | Chuỗi định danh 36 ký tự, ví dụ `020eccc5-8e1f-4b57-b305-32f45d60e5ab` |
| **OAuth 2.0 Password Grant** | Cách lấy token bằng tên đăng nhập và mật khẩu |
| **Bearer token** | Mã truy cập đặt trong header `Authorization: Bearer <token>` |
| **multipart/form-data** | Định dạng gửi tệp đính kèm qua HTTP, dùng cho API db16 |
| **Flyway** | Công cụ quản lý thay đổi cơ sở dữ liệu theo phiên bản (thay cho chạy lại script tạo bảng) |
| **Testcontainers** | Thư viện chạy PostgreSQL thật trong Docker khi kiểm thử |
| **Idempotent** | Gọi nhiều lần cho kết quả như gọi một lần. IKS là cơ chế bảo đảm điều này |
| **PascalCase** | `DanhSachCanboHoso` — dùng cho thẻ XML |
| **UPPER_SNAKE** | `_CO_SO_GIAO_DUC` — dùng cho trường JSON |
| **snake_case** | `sync_batch` — dùng cho tên bảng, cột |
