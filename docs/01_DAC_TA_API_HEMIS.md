# 01. Đặc tả API HEMIS — bản tóm tắt cho người lập trình

Tóm tắt từ *Tài liệu đặc tả kỹ thuật tích hợp dữ liệu qua API từ cơ sở đào tạo* (Cục Khoa học,
Công nghệ và Thông tin, 2026, 133 trang). Đây là bản rút gọn để làm việc hằng ngày — khi viết
mã cho một phân hệ cụ thể, **vẫn phải mở đặc tả gốc** để lấy danh sách trường chi tiết.

---

## 1. Toàn cảnh: 14 API

Máy chủ thử nghiệm: `https://hemis-test.moet.gov.vn/gwdev/...`
Máy chủ SSO: tên miền riêng do Bộ cấp.

| # | API | Đường dẫn | Dùng để làm gì |
| --- | --- | --- | --- |
| 1 | Token | `POST /connect/token` | Lấy mã truy cập, bắt buộc trước mọi lệnh gọi khác |
| 2 | Danh mục | `POST /danhmucbeta/v5/DM_BAC_LUONG/getDanhMucHemis` | Tải hơn 175 danh mục dùng chung trong **một** lần gọi |
| 3 | XML ký số | `POST /dongbodulieubeta/v5/co_so_giao_duc_input/db16/{DON_VI_ID}/{IKS}/{PH}` | Nộp tệp XML đã ký số của một phân hệ |
| 4 | Cơ sở giáo dục | `.../db1/{DON_VI_ID}/{IdKey}` | Thông tin chung, khen thưởng, khóa học, kiểm định... |
| 5 | Hội đồng, ban giám hiệu | `.../db2/...` | Ban giám hiệu, ban kiểm soát, hội đồng trường, cổ đông |
| 6 | Đội ngũ | `.../db3/...` | Hồ sơ cán bộ + 22 nhóm dữ liệu con |
| 7 | Ngành đào tạo | `.../db4/...` | Ngành, khối ngành, lĩnh vực, nhóm ngành |
| 8 | Chương trình đào tạo | `.../db5/...` | CTĐT, gia hạn, ngoại ngữ, kiểm định chương trình |
| 9 | Tuyển sinh | `.../db6/...` | Ngành tuyển sinh, thí sinh trúng tuyển |
| 10 | Người học | `.../db7/...` | Học viên, học tập, học bổng, khen thưởng, việc làm |
| 11 | Cơ sở vật chất | `.../db9/...` | Đất, tòa nhà, ký túc xá, phòng thí nghiệm, thiết bị |
| 12 | Nghiên cứu khoa học | `.../db10/...` | Nhiệm vụ KHCN, sáng chế, bài báo, giải thưởng |
| 13 | Tài chính, tài sản | `.../db11/...` | Thu chi, quỹ, tài sản, chi ngân sách |
| 14 | Hợp tác quốc tế | `.../db12/...` | Tổ chức, đoàn công tác, lưu học sinh, hội thảo |
| 15 | Hợp tác doanh nghiệp | `.../db13/...` | Tổ chức hợp tác doanh nghiệp |

Không có `db8`. Mã phân hệ (`PH`) dùng cho API số 3:
`COSOGIAODUC, CANBO, HOIDONG, NGANHDT, DAOTAO, TUYENSINH, HOCVIEN, VANBANG, NCKH, COSOVATCHAT, TAISAN, HTQT, HTDN`.

---

## 2. Lấy token

OAuth 2.0 — Resource Owner Password Credentials Grant.

```
POST /connect/token
Content-Type: application/x-www-form-urlencoded

grant_type=password
scope=password
client_id=password
client_secret=<do Bộ cấp>
username=<do Bộ cấp>
password=<do Bộ cấp>
```

Phản hồi:

```json
{ "access_token": "eyJ...", "expires_in": 900000, "token_type": "Bearer", "scope": "openid profile email" }
```

Các lệnh gọi sau đặt header `Authorization: Bearer <access_token>`.

> **Cảnh báo**: `expires_in = 900000` nếu tính bằng giây là hơn 10 ngày — rất khó có thật.
> Mã nguồn lấy `min(expires_in, hemis.token.max-lifetime-seconds)` và mặc định 900 giây.
> Xem `client/HemisAuthClient.java`.

---

## 3. Danh mục dùng chung

Một lần gọi trả về **hơn 175 danh sách** trong cùng đối tượng `data`. Phản hồi rất lớn,
đặt thời gian chờ đọc dài.

Mỗi phần tử danh mục có cấu trúc chung:

| Trường | Ý nghĩa |
| --- | --- |
| `Id` | Định danh Guid của bản ghi danh mục |
| `Code` | Mã nội bộ (nếu có) |
| `MA_<TÊN_DANH_MỤC>` | Mã của phần tử, ví dụ `MA_DAN_TOC` |
| `TEN_<TÊN_DANH_MỤC>` | Tên hiển thị, ví dụ `TEN_DAN_TOC` |
| `ISPUBLIC`, `IsDeleted` | Trạng thái công khai, đã xóa mềm |
| `Created`, `Modified` | Dùng để so sánh thay đổi giữa các lần tải |

Vài danh mục hay dùng: `DM_GIOI_TINH`, `DM_DAN_TOC`, `DM_QUOC_TICH`, `DM_TON_GIAO`,
`DM_TINH`, `DM_XA`, `DM_TINH_NEW`, `DM_XA_NEW` (địa giới theo Quyết định 19/2025/QĐ-TTg),
`DM_NGANH`, `DM_TRINH_DO_DAO_TAO`, `DM_LOAI_HINH_TRUONG`.

**Quy tắc**: mọi trường kết thúc bằng `_ID` trong dữ liệu gửi đi phải mang **mã danh mục của
HEMIS**, không phải mã nội bộ của Trường. Việc đổi mã làm ở bảng `catalog_map`.

---

## 4. Quy trình hai bước của một đợt đồng bộ

```
Bước 1  db16  →  nộp tệp XML đã ký số, khóa phiên là IKS
Bước 2  dbN   →  gửi thân JSON, trong đó  t_k = IKS  (đúng IKS vừa nộp)
```

Dữ liệu đi vào bảng trung gian của HEMIS và được ghi nhật ký theo `IdKey`.

### Tham số đường dẫn

| Tham số | Kiểu | Ý nghĩa |
| --- | --- | --- |
| `DON_VI_ID` | Guid 36 | Id cơ sở giáo dục do Bộ cấp. Phải thuộc quyền quản lý của tài khoản, nếu không trả 401 |
| `IKS` | Guid 36 | Mã phiên ký số, **khóa duy nhất**. IKS trùng → lỗi "Dữ liệu đã tồn tại" |
| `PH` | chuỗi | Mã phân hệ, xem bảng ở mục 1 |
| `IdKey` | Guid 36 | Mã phiên đồng bộ do bên gọi tự sinh, dùng tra cứu nhật ký |

### Phản hồi

```json
{ "success": true, "message": null, "data": ... }
```

> **Hệ quả quan trọng**: HEMIS **không trả lỗi theo từng bản ghi**. Chỉ có một cờ `success`
> cho cả đợt. Vì vậy:
> 1. Phải kiểm tra dữ liệu ở phía Trường **trước** khi gửi.
> 2. Phải đối soát lại trên giao diện HEMIS **sau** khi gửi.

---

## 5. Cấu trúc tệp XML — phần dễ sai nhất

```xml
<?xml version="1.0" encoding="utf-8"?>
<Data xmlns:xsd="http://www.w3.org/2001/XMLSchema"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <DuLieuKySo Id="data">
    <k1>020eccc5-8e1f-4b57</k1>          <!-- 18 ký tự ĐẦU của IKS, con ĐẦU TIÊN -->
    <MaDonVi>...</MaDonVi>
    <TenDonVi>...</TenDonVi>
    <DanhSachCanboHoso>
      <CanboHoso>
        <Id>020eccc5-8e1f-4b57-b305-32f45d60e5ab</Id>
        <Cccd>030091xxxxxx</Cccd>
        <HoDem>Vũ Công</HoDem>
        <TenGoi>Tùng</TenGoi>
        <!-- ... -->
      </CanboHoso>
    </DanhSachCanboHoso>
    <k2>-b305-32f45d60e5ab</k2>          <!-- 18 ký tự CUỐI của IKS, con CUỐI CÙNG -->
  </DuLieuKySo>
  <KySo Id="{guid}">                      <!-- NGANG HÀNG với DuLieuKySo -->
    <Signature xmlns="http://www.w3.org/2000/09/xmldsig#" Id="sigid-{guid}">
      <SignedInfo>
        <CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
        <SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
        <Reference URI="#data">           <!-- trỏ tới DuLieuKySo qua Id="data" -->
          <Transforms>
            <Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
          </Transforms>
          <DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
          <DigestValue>...</DigestValue>
        </Reference>
        <Reference URI="#signobject-{guid}">...</Reference>
      </SignedInfo>
      <SignatureValue>...</SignatureValue>
      <KeyInfo>
        <X509Data>
          <X509SubjectName>...</X509SubjectName>   <!-- PHẢI đứng TRƯỚC -->
          <X509Certificate>...</X509Certificate>   <!-- PHẢI đứng SAU -->
        </X509Data>
      </KeyInfo>
      <Object Id="signobject-{guid}">
        <SignatureProperties xmlns="">
          <SignatureProperty Target="#sigid-{guid}">
            <SigningTime xmlns="http://example.org/#signatureProperties">2026-07-17T09:32:02</SigningTime>
          </SignatureProperty>
        </SignatureProperties>
      </Object>
    </Signature>
  </KySo>
</Data>
```

### Sáu quy tắc bắt buộc

1. `Id="data"` trên `DuLieuKySo` — chữ ký tham chiếu qua `URI="#data"` (enveloped signature).
2. `k1` con **đầu tiên**, `k2` con **cuối cùng**; `k1 + k2` = đúng chuỗi IKS 36 ký tự.
3. Một tệp **có thể chứa nhiều thẻ** `DanhSachXXX`; chỉ xuất danh sách thực sự có dữ liệu.
4. Tên thẻ `DanhSachXXX` và tên trường viết **PascalCase** (`NganhId`, `SoQdMoNganh`),
   khác với tên trường trong JSON là **UPPER_SNAKE** (`NGANH_ID`, `SO_QD_MO_NGANH`).
5. `KySo` là con của `Data`, **ngang hàng** với `DuLieuKySo`.
6. `SigningTime` định dạng `yyyy-MM-ddTHH:mm:ss`, giờ Việt Nam (UTC+7).

Các quy tắc 1, 2, 5 đã được kiểm thử tự động trong `XmlPackagerTest.java` và kiểm tra lại
lúc chạy trong `XmlDsigVerifier.java`.

### Ví dụ thẻ DanhSachXXX theo phân hệ

| PH | Thẻ danh sách |
| --- | --- |
| `NGANHDT` | `DanhSachNdtNganhDaoTao`, `DanhSachNdtHinhThucDaoTao` |
| `DAOTAO` | `DanhSachChuongTrinhDaoTao`, `DanhSachDtNamApDung` |
| `HOCVIEN` | `DanhSachThongTinHocVien`, `DanhSachHvHocTapNghienCuu`, `DanhSachHvHocBong` |
| `CANBO` | `DanhSachCanboHoso`, `DanhSachCanboHosoHopdong`, `DanhSachCanboHosoNganhgd` |

---

## 6. Thân JSON của API dbN

```json
{
  "t_k": "020eccc5-8e1f-4b57-b305-32f45d60e5ab",
  "DomainConnect": "hemis-dwh.hcmue.edu.vn",
  "_CO_SO_GIAO_DUC": { "Id": "...", "MA_DON_VI": "...", "...": "..." },
  "_CSGD_KHEN_THUONG": [ { "...": "..." } ]
}
```

| Trường | Bắt buộc | Ghi chú |
| --- | --- | --- |
| `t_k` | Có | Mã phiên ký số (IKS) đã xác thực ở db16. Không hợp lệ → từ chối truy cập |
| `DomainConnect` | Không | Định danh hệ thống nguồn, HEMIS ghi vào nhật ký |
| `_XXX` | Tùy phân hệ | Đối tượng hoặc mảng dữ liệu nghiệp vụ |

Các trường `CONFIG_VALUE`, `CONFIG_KEY`, `UserName`, `Created`, `DON_VI_ID` (trong thân),
`CERTPEM` là trường dùng chung của mô hình, API **không xử lý**, có thể bỏ qua.

---

## 7. Mã lỗi

| Mã | Ý nghĩa | Xử lý |
| --- | --- | --- |
| `401 Unauthorized` | Token hết hạn, hoặc `DON_VI_ID` không thuộc quyền quản lý của tài khoản | Lấy token mới rồi thử lại một lần. Vẫn lỗi → kiểm tra `DON_VI_ID` |
| `403 ERR_ACCESS_DENIED` | Đơn vị chưa được đăng ký đồng bộ, hoặc `t_k` không hợp lệ | Liên hệ Cục KHCN&TT; kiểm tra đã gọi db16 trước chưa |
| "Dữ liệu đã tồn tại" | IKS đã dùng rồi | **Không sinh IKS mới** — kiểm tra đợt trước đã nộp thành công chưa |
| `success: false` | Lỗi nghiệp vụ, mô tả trong `message` | Đọc `message`, đối chiếu đặc tả trường |

---

## 8. Điểm cần làm rõ với Cục Khoa học, Công nghệ và Thông tin

Những điểm dưới đây đặc tả chưa nói rõ. **Không được tự đoán và viết mã theo phỏng đoán** —
ghi nhận ở đây, đầu mối kỹ thuật tổng hợp gửi Bộ.

| # | Vấn đề | Ảnh hưởng | Cách xử lý tạm thời trong mã nguồn |
| --- | --- | --- | --- |
| 1 | Có bắt buộc gọi db16 **trước** dbN với cùng IKS không? HEMIS có đối chiếu nội dung hai bản không? | Quyết định thiết kế bộ đóng gói | Luôn gọi db16 trước; sinh XML và JSON từ **cùng một** đối tượng để hai bản không lệch |
| 2 | Định dạng ngày chính thức: bảng trường ghi `yyyy-MM-dd` nhưng ví dụ XML lại ghi `28/09/1991` | Sai là bị từ chối hàng loạt | Dùng `yyyy-MM-dd`; đổi được qua hằng số trong `XmlPackager` |
| 3 | `expires_in = 900000` là giây hay mili giây? | Token hết hạn giữa chừng | Lấy `min(expires_in, 900)` giây |
| 4 | "Tệp XML được mã hóa dưới dạng chuỗi JSON string (escape chuẩn JSON)" nghĩa là gì? | Gửi sai định dạng tệp | Mặc định gửi XML nguyên bản; bật bằng `hemis.upload.json-string-encoded` |
| 5 | Có API tra cứu kết quả xử lý theo `IdKey` và lỗi theo từng bản ghi không? | Không tự động đối soát được | Đối soát thủ công trên giao diện HEMIS |
| 6 | Khi nào `gwdev/...beta` chuyển sang môi trường chính thức? | Phải đổi địa chỉ | Địa chỉ đặt trong cấu hình, không gắn cứng trong mã |
| 7 | `_CO_CAU_TO_CHUC` ghi "đang vô hiệu hóa trong code" — khi nào có hiệu lực? | Dữ liệu cơ cấu tổ chức chưa gửi được | Chưa làm |
| 8 | API db3 (đội ngũ) ghi "hiện KHÔNG xác thực `t_k`" — có đổi không? | Quy trình hai bước có thể khác với db3 | Vẫn gọi db16 trước cho thống nhất |

Khi một điểm được Bộ trả lời, cập nhật bảng này và ghi rõ ngày trả lời.
