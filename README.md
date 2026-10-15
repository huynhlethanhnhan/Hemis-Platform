# hemis-platform

Cổng tích hợp dữ liệu HEMIS — Trường Đại học Sư phạm Thành phố Hồ Chí Minh, Phòng Công nghệ thông tin.

Phần mềm này đẩy dữ liệu của Trường lên Hệ thống cơ sở dữ liệu về giáo dục đại học (HEMIS)
của Bộ Giáo dục và Đào tạo qua API, theo _Tài liệu đặc tả kỹ thuật tích hợp dữ liệu qua API
từ cơ sở đào tạo_ và _Hướng dẫn sử dụng ký số_ của Cục Khoa học, Công nghệ và Thông tin.

> **Người mới vào nhóm**: đọc [docs/00_LO_TRINH_DOC.md](docs/00_LO_TRINH_DOC.md) trước, đừng đọc mã nguồn ngay.

---

## 1. Chạy thử trong 10 phút

Cần: **JDK 21**, **Docker Desktop**, **Git**. Không cần cài Maven (dùng `mvnw` kèm theo).

```bash
# 1. Bật PostgreSQL và WireMock (mô phỏng API của Bộ)
docker compose up -d

# 2. Tạo file cấu hình riêng
cp .env.example .env

# 3. Chạy ứng dụng
./mvnw spring-boot:run        # Windows: mvnw.cmd spring-boot:run
```

Kiểm tra:

```bash
# Lấy token (qua WireMock)
curl -X POST http://localhost:8080/api/v1/hemis/kiem-tra-token

# Tải danh mục dùng chung
curl -X POST http://localhost:8080/api/v1/hemis/danh-muc/tai-ve

# Chuẩn bị một đợt đồng bộ phân hệ Cơ sở giáo dục
curl -X POST http://localhost:8080/api/v1/hemis/dot/COSOGIAODUC/chuan-bi
```

Lệnh thứ ba sinh ra tệp XML chưa ký trong `./data/hemis-packages/COSOGIAODUC/<IKS>/payload.xml`.
Mở tệp đó ra xem — đây là thứ sẽ được ký số và gửi lên Bộ.

Chạy kiểm thử:

```bash
./mvnw test
```

---

## 2. Vai trò của dự án trong tổng thể

```
He thong nguon (QLDT, nhan su, tai chinh)
        v
HEMIS-DWH (PostgreSQL, schema dwh)          <- da co, 13 module
        v
hemis-platform  (DU AN NAY)                 <- schema hemis_sync
        v
API HEMIS cua Bo GDDT
```

`hemis-platform` **không thay thế** HEMIS-DWH-Backend (FastAPI) hiện có. FastAPI tiếp tục làm
dịch vụ dữ liệu (nhập liệu Excel, làm sạch, đối chiếu, phân tích). Dự án này chịu trách nhiệm
phần kết nối với Bộ và sẽ dần nhận thêm phần API nghiệp vụ ở các giai đoạn sau.

---

## 3. Cấu trúc thư mục

```
hemis-platform/
├── docs/                                  Tài liệu cho nhóm (đọc trước)
├── wiremock/mappings/                     Mô phỏng API của Bộ khi chưa có tài khoản
├── docker-compose.yml                     PostgreSQL + WireMock
├── src/main/resources/
│   ├── application.yml                    Cấu hình (KHÔNG chứa bí mật)
│   └── db/migration/V1__hemis_sync.sql    Schema hemis_sync
└── src/main/java/vn/edu/hcmue/hemis/
    ├── config/      HemisProperties, RestClientConfig
    ├── client/      HemisAuthClient, HemisCatalogClient, HemisSyncClient
    ├── packaging/   Iks, XmlPackager            <- phần dễ sai nhất, đọc kỹ
    ├── signing/     SignJob, SignAgentController, XmlDsigVerifier
    ├── staging/     PhanHeExtractor + bộ trích xuất từng phân hệ
    ├── sync/        SyncOrchestrator            <- điều phối một đợt đồng bộ
    ├── journal/     SyncBatch, ApiLog           <- nhật ký, bắt buộc theo công văn
    └── api/         AdminController
```

---

## 4. Một đợt đồng bộ đi qua những bước nào

```
chuan-bi                                    gui
   │                                         │
   ├─ sinh IKS + IdKey                       ├─ db16: nộp XML đã ký
   ├─ trích xuất dữ liệu                     └─ dbN : gửi JSON (t_k = IKS)
   ├─ kiểm tra quy tắc                            │
   ├─ đóng gói XML + JSON                         └─ ghi nhật ký
   └─ đưa vào hàng đợi ký số
          │
          └─ tác nhân trên trạm ký số ký bằng USB token
             (plugin XmlSignerTriNam tại 127.0.0.1:64005)
```

Hai lệnh `chuan-bi` và `gui` **cố ý tách rời** vì ở giữa có hành động của con người:
lãnh đạo phê duyệt, cắm USB token, nhập mã PIN.

---

## 5. Quy tắc bắt buộc, sai là bị HEMIS từ chối

1. `DuLieuKySo` phải có `Id="data"` — chữ ký tham chiếu node này qua `URI="#data"`.
2. `k1` là node con **đầu tiên**, `k2` là node con **cuối cùng** của `DuLieuKySo`;
   `k1 + k2` ghép lại phải ra đúng chuỗi IKS.
3. Thẻ `KySo` nằm **ngang hàng** với `DuLieuKySo`, không lồng bên trong.
4. Trong `X509Data`, `X509SubjectName` đứng **trước** `X509Certificate`.
5. Tên thẻ XML viết **PascalCase**; tên trường JSON viết **UPPER_SNAKE**. Hai bản khác nhau.
6. Mọi trường `*_ID` dùng **mã danh mục HEMIS**, không dùng mã nội bộ.
7. Một `IKS` chỉ dùng **một lần**. Gửi lại cùng IKS sẽ bị từ chối "Dữ liệu đã tồn tại" —
   đó là cơ chế chống gửi trùng, không được sinh IKS mới khi thử lại một đợt đã nộp db16.

Các quy tắc 1–4 đã có kiểm thử tự động trong `src/test/.../XmlPackagerTest.java`.
Chạy `./mvnw test` trước mỗi lần gửi thật.

---

## 6. An toàn thông tin

- Không commit `.env`, chứng thư số, khóa riêng, mã PIN.
- Không ghi số căn cước công dân vào nhật ký (`api_log`).
- Đường dẫn `/internal/**` chỉ mở trong mạng nội bộ, chặn ở reverse proxy.
- Tệp XML đã ký lưu chỉ đọc, giữ tối thiểu 05 năm.

---

## 7. Tình trạng hiện tại

| Thành phần                        | Trạng thái                                            |
| --------------------------------- | ----------------------------------------------------- |
| Lấy token, tự làm mới             | Xong                                                  |
| Tải danh mục dùng chung           | Xong (chưa lưu vào bảng `catalog_hemis`)              |
| Sinh XML đúng cấu trúc k1/k2      | Xong, có kiểm thử                                     |
| Tự xác minh chữ ký XML-DSig       | Xong                                                  |
| Hàng đợi ký số + API cho tác nhân | Xong                                                  |
| Gửi db16 và dbN, ghi nhật ký      | Xong                                                  |
| Trích xuất COSOGIAODUC            | Khung, đọc từ cấu hình — **cần nối với schema `dwh`** |
| Bộ quy tắc kiểm tra dữ liệu       | **Chưa làm**                                          |
| Tác nhân ký số trên Windows       | **Chưa làm** — xem `docs/02_KY_SO_XML_DSIG.md`        |
| Màn hình theo dõi                 | Mới có API, chưa có giao diện                         |

Kế hoạch chi tiết: `../plan/PA_Ky_thuat_GD1_Ket_noi_API_HEMIS.docx`
