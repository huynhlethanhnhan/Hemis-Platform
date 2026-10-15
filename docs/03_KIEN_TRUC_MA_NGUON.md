# 03. Kiến trúc mã nguồn

---

## 1. Dự án này nằm ở đâu

```
He thong nguon  ──►  HEMIS-DWH (PostgreSQL, schema dwh)  ──►  hemis-platform  ──►  API HEMIS
   QLDT                     13 module, 99 bang nghiep vu        schema hemis_sync      Bo GDDT
   nhan su                  154 bang danh muc
   tai chinh
                                      ▲
                                      │
                       HEMIS-DWH-Backend (FastAPI)
                       nhap Excel, lam sach, phan tich
```

Hai backend **phân vai rõ**, không chồng lấn:

| | hemis-platform (Java) | HEMIS-DWH-Backend (FastAPI) |
| --- | --- | --- |
| Việc chính | Kết nối HEMIS, ký số, nhật ký; sau này là API nghiệp vụ và kho dữ liệu | Nhập Excel, làm sạch, đối chiếu, phân tích, học máy |
| Ghi dữ liệu nghiệp vụ | Có | **Không** — chỉ đọc và ghi vùng tạm của mình |
| Expose ra ngoài | `/api/v1/**` | Chỉ `/internal/**` trong mạng nội bộ |

---

## 2. Các gói mã nguồn

```
vn.edu.hcmue.hemis
├── config/       HemisProperties      toàn bộ cấu hình, ánh xạ từ application.yml
│                 RestClientConfig     hai RestClient: SSO và gateway
│
├── client/       HemisAuthClient      lấy và giữ access token, tự làm mới
│                 HemisCatalogClient   tải hơn 175 danh mục dùng chung
│                 HemisSyncClient      gọi db16 (multipart) và dbN (JSON), thử lại
│                 HemisResponse        khung phản hồi { success, message, data }
│
├── packaging/    Iks                  tách IKS thành k1/k2  ← ĐỌC KỸ
│                 XmlPackager          sinh tệp XML chưa ký   ← ĐỌC KỸ
│
├── signing/      SignJob              một việc trong hàng đợi ký số
│                 SignJobRepository
│                 SignAgentController  API nội bộ cho tác nhân trên trạm ký số
│                 XmlDsigVerifier      tự xác minh chữ ký + cấu trúc trước khi gửi
│
├── staging/      PhanHeExtractor      giao diện chung cho mọi phân hệ
│                 CoSoGiaoDucExtractor phân hệ COSOGIAODUC (db1) — thí điểm GĐ1
│
├── sync/         SyncOrchestrator     điều phối: chuanBi() và gui()
│
├── journal/      SyncBatch            một đợt đồng bộ
│                 ApiLog               nhật ký từng lần gọi API
│                 *Repository
│
└── api/          AdminController      API cho màn hình theo dõi
```

---

## 3. Luồng dữ liệu một đợt

```
AdminController.chuanBi("COSOGIAODUC")
   │
   ├─► SyncOrchestrator.chuanBi()
   │      ├─ sinh IKS (Guid) và IdKey (Guid)
   │      ├─ tạo SyncBatch, trạng thái KHOI_TAO
   │      ├─ PhanHeExtractor.extract()        ◄── đọc schema dwh, đổi mã danh mục
   │      ├─ [TODO] chạy bộ quy tắc kiểm tra
   │      ├─ XmlPackager.build()              ◄── sinh XML chưa ký, k1/k2
   │      ├─ ghi payload.xml và payload.json
   │      ├─ tạo SignJob (PENDING)
   │      └─ SyncBatch → CHO_KY_SO
   │
   │   ... tác nhân trên trạm ký số kéo việc, ký bằng USB token ...
   │
   ├─► SignAgentController.result()
   │      ├─ XmlDsigVerifier.verify()         ◄── chặn tệp sai trước khi gửi
   │      ├─ ghi payload.signed.xml
   │      └─ SyncBatch → DA_KY_SO
   │
   └─► SyncOrchestrator.gui()
          ├─ HemisSyncClient.uploadSignedXml()   db16  → DA_GUI_XML
          ├─ HemisSyncClient.syncJson()          dbN   → DA_GUI_JSON
          └─ ApiLog cho từng lần gọi
```

Trạng thái của `SyncBatch` (`journal/SyncBatch.Status`):

```
KHOI_TAO → DA_DONG_GOI → CHO_KY_SO → DA_KY_SO → DA_GUI_XML → DA_GUI_JSON → DA_DOI_SOAT
                ↓                                      ↓
          CHO_SUA_LOI                              THAT_BAI
```

---

## 4. Vì sao tách `chuanBi` và `gui` thành hai lệnh

Giữa hai bước có **hành động của con người**: lãnh đạo phê duyệt, cắm USB token, nhập mã PIN.
Nếu gộp thành một lệnh chạy thẳng thì:

- không dừng lại được khi phát hiện dữ liệu sai;
- không có điểm để lãnh đạo xác nhận trước khi dữ liệu rời khỏi Trường;
- thử lại sẽ ký lại từ đầu, tốn thao tác với USB token.

---

## 5. Thêm một phân hệ mới — các bước

Ví dụ thêm phân hệ Người học (`HOCVIEN`, API `db7`):

1. **Đọc đặc tả** chương 10, liệt kê 9 mảng dữ liệu và trường bắt buộc của từng mảng.
2. **Tạo lớp** `staging/HocVienExtractor.java` thực thi `PhanHeExtractor`:
   ```java
   @Override public String ph()  { return "HOCVIEN"; }
   @Override public String api() { return "db7"; }
   ```
3. **Truy vấn** schema `dwh`, lấy bản ghi thay đổi từ lần đồng bộ thành công gần nhất.
4. **Gắn GUID** qua bảng `entity_map` (sinh một lần, giữ cố định).
5. **Đổi mã danh mục** nội bộ sang mã HEMIS qua bảng `catalog_map`.
6. **Sinh song song** hai bản từ **cùng một** đối tượng:
   - JSON: `_THONG_TIN_HOC_VIEN`, `_HV_HOC_TAP_NGHIEN_CUU`, ...
   - XML: `DanhSachThongTinHocVien`, `DanhSachHvHocTapNghienCuu`, ...
7. **Nạp quy tắc kiểm tra** vào bảng `validation_rule`.
8. **Viết kiểm thử** cho bộ trích xuất, theo mẫu `XmlPackagerTest`.
9. **Chạy thử trên WireMock** trước, rồi mới chạy trên môi trường thử nghiệm của Bộ.

> Lỗi nguy hiểm nhất: viết hai đoạn mã độc lập cho XML và JSON. Hai bản sẽ lệch nhau
> và rất khó phát hiện. Luôn sinh từ **một** nguồn trong bộ nhớ.

---

## 6. Vì sao chọn những công nghệ này

| Lựa chọn | Lý do |
| --- | --- |
| Java 21 + Spring Boot | XML-DSig và PKCS#11 có sẵn trong JDK, không cần thư viện ngoài; hệ sinh thái tốt cho kho dữ liệu và tích hợp ở giai đoạn sau |
| PostgreSQL + Flyway | Giữ nguyên cơ sở dữ liệu hiện có; thay cách triển khai bằng `reset_all.sql` (xóa và tạo lại) bằng migration có kiểm soát |
| Schema `hemis_sync` riêng | Không đụng vào schema `dwh` đang chạy; triển khai và rollback độc lập |
| `RestClient` (không WebFlux) | Khối lượng gọi nhỏ, đồng bộ dễ đọc và dễ gỡ lỗi hơn bất đồng bộ |
| DOM thay vì JAXB | Cấu trúc XML của HEMIS không theo chuẩn thông thường (k1/k2, `Id="data"`), điều khiển trực tiếp bằng DOM rõ ràng hơn |
| WireMock | Cho phép viết và kiểm thử toàn bộ luồng trước khi Bộ cấp tài khoản |

---

## 7. Những chỗ cố ý chưa làm

| Hạng mục | Lý do | Khi nào làm |
| --- | --- | --- |
| Lưu danh mục vào bảng `catalog_hemis` | Cần thống nhất cách đọc tên trường `MA_<TÊN>` động | Tuần 2 |
| Bộ quy tắc kiểm tra dữ liệu | Phải trích từ bảng trường của đặc tả, khối lượng lớn | Tuần 3 |
| Nối `CoSoGiaoDucExtractor` với schema `dwh` | Chờ chốt danh sách trường bắt buộc | Tuần 2 |
| Xác thực người dùng (SSO) | Giai đoạn 1 chạy trong mạng nội bộ | Giai đoạn 3 |
| Spring Batch, chia lô lớn | Phân hệ thí điểm chỉ có 1 bản ghi | Khi làm CANBO, HOCVIEN |
| Resilience4j | Đã có cơ chế thử lại đơn giản trong `HemisSyncClient` | Khi tần suất gọi tăng |

Mỗi chỗ chưa làm đều có ghi chú `TODO` kèm tuần dự kiến ngay trong mã nguồn.
