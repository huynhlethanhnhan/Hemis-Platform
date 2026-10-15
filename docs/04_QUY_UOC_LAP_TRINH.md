# 04. Quy ước lập trình và làm việc

Quy ước ngắn, đủ dùng cho một nhóm nhỏ. Mục đích là để người khác đọc lại mã sau 6 tháng
vẫn hiểu, không phải để làm khó nhau.

---

## 1. Ngôn ngữ dùng trong mã nguồn

| Chỗ nào | Dùng gì | Ví dụ |
| --- | --- | --- |
| Tên lớp, phương thức, biến | Tiếng Việt **không dấu**, hoặc tiếng Anh nếu là thuật ngữ kỹ thuật | `chuanBi()`, `XmlPackager`, `donViId` |
| Chú thích, Javadoc | Tiếng Việt **không dấu** | `// Sinh IKS truoc khi dong goi` |
| Tên bảng, cột cơ sở dữ liệu | `snake_case` không dấu | `sync_batch`, `signed_xml_path` |
| Tài liệu trong `docs/` | Tiếng Việt **có dấu** | tệp này |
| Thông báo cho người dùng cuối | Tiếng Việt **có dấu** | `"Đợt đồng bộ đã gửi thành công"` |

Lý do không dùng dấu trong mã nguồn: tránh lỗi mã hóa khi chạy trên Linux, trong Docker,
trong nhật ký và khi xem qua SSH.

Giữ **nguyên văn** tên trường của Bộ, kể cả khi thấy sai chính tả hoặc không nhất quán
(`_KHCH_SACH_XUAT_BAN`, `CMTND` lẫn `CCCD`). Không "sửa cho đẹp".

---

## 2. Quy ước đặt tên theo đặc tả

| Nơi | Kiểu | Ví dụ |
| --- | --- | --- |
| Trường trong JSON gửi HEMIS | `UPPER_SNAKE`, có tiền tố `_` cho mảng | `_CO_SO_GIAO_DUC`, `MA_DON_VI` |
| Thẻ trong XML gửi HEMIS | `PascalCase` | `DanhSachCoSoGiaoDuc`, `MaDonVi` |
| Mã phân hệ (`PH`) | `UPPERCASE` liền | `COSOGIAODUC`, `HOCVIEN` |
| Mã API | `dbN` chữ thường | `db1`, `db16` |

Hàm đổi `UPPER_SNAKE` → `PascalCase`: `CoSoGiaoDucExtractor.pascal()`.

---

## 3. Cấu trúc một lớp trích xuất phân hệ

```java
@Component
public class XxxExtractor implements PhanHeExtractor {

    @Override public String ph()  { return "XXX"; }   // ma phan he cho db16
    @Override public String api() { return "dbN"; }   // ma API JSON

    @Override
    public Result extract() {
        // 1. doc du lieu tu schema dwh
        // 2. gan GUID qua entity_map
        // 3. doi ma danh muc qua catalog_map
        // 4. sinh JSON (_UPPER_SNAKE) va XML (PascalCase) tu CUNG mot nguon
        return new Result(xmlLists, jsonBody, soBanGhi);
    }
}
```

Đăng ký tự động qua `@Component`; `SyncOrchestrator` nhận toàn bộ danh sách qua constructor,
không phải sửa chỗ nào khác.

---

## 4. Xử lý lỗi

- Lỗi do HEMIS trả về (`success: false`) → ném `HemisResponse.HemisApiException`.
- Lỗi dữ liệu của Trường → **không ném ngoại lệ**, ghi vào bảng `sync_error` để đơn vị
  quản lý dữ liệu xử lý, rồi đặt đợt về trạng thái `CHO_SUA_LOI`.
- Không nuốt ngoại lệ (`catch` rồi bỏ qua). Nếu buộc phải bỏ qua, ghi `log.warn` kèm lý do.
- Thông báo lỗi phải nói **làm gì tiếp theo**, không chỉ nói cái gì sai:
  ```java
  // Khong tot
  throw new IllegalStateException("IKS khong hop le");

  // Tot
  throw new IllegalStateException(
      "k1 + k2 trong tep khong khop IKS cua dot " + batchId
      + ". Kiem tra tac nhan ky so co ky nham tep cua dot khac khong.");
  ```

---

## 5. Nhật ký (logging)

| Mức | Dùng khi |
| --- | --- |
| `INFO` | Mốc nghiệp vụ: lấy token, chuẩn bị đợt, ký xong, gửi xong |
| `WARN` | Thử lại, token hết hạn, danh mục chưa ánh xạ được |
| `ERROR` | Đợt thất bại, chữ ký không hợp lệ |
| `DEBUG` | Chi tiết kỹ thuật, tắt ở môi trường chạy thật |

**Tuyệt đối không ghi vào nhật ký**: số căn cước công dân, mật khẩu, mã PIN, `client_secret`,
nội dung access token, họ tên đầy đủ kèm thông tin cá nhân khác.

Luôn kèm `IKS` hoặc `batchId` trong thông điệp để truy vết được:

```java
log.info("Da chuan bi dot {} phan he {} - {} ban ghi, IKS={}", id, ph, soBanGhi, iks);
```

---

## 6. Kiểm thử

| Loại | Công cụ | Viết cho cái gì |
| --- | --- | --- |
| Đơn vị | JUnit 5 + AssertJ | Tách IKS, sinh XML, đổi tên trường, quy tắc kiểm tra |
| Tích hợp | Testcontainers (PostgreSQL) | Flyway, repository, luồng đầy đủ |
| Mô phỏng HEMIS | WireMock | Gọi API khi chưa có tài khoản của Bộ |

Bắt buộc: **mọi quy tắc trong đặc tả đều phải có một kiểm thử**. Vì HEMIS chỉ trả về
`success: false`, kiểm thử của ta là lớp phòng vệ duy nhất.

Chạy trước mỗi lần gửi thật:

```bash
./mvnw test
```

---

## 7. Nhánh và commit

```
main                    luôn chạy được, là bản đã kiểm thử
  └── feat/hocvien-db7   một việc, một nhánh
      fix/xml-k2-order
      docs/huong-dan-ky-so
```

Thông điệp commit tiếng Việt không dấu, dòng đầu dưới 72 ký tự:

```
feat(hocvien): them bo trich xuat phan he nguoi hoc db7

- 9 mang du lieu theo dac ta chuong 10
- anh xa danh muc trang thai hoc, loai hinh dao tao
- kiem thu cho 12 truong bat buoc
```

Tiền tố: `feat` (tính năng), `fix` (sửa lỗi), `docs` (tài liệu), `test` (kiểm thử),
`chore` (việc vặt), `refactor` (sắp xếp lại mã).

---

## 8. Những điều không được làm

1. **Không commit bí mật**: `.env`, chứng thư số, khóa riêng, mã PIN, mật khẩu, token.
2. **Không gắn cứng địa chỉ máy chủ của Bộ** trong mã — luôn đọc từ cấu hình.
3. **Không sinh IKS mới** khi thử lại một đợt đã nộp db16 thành công.
4. **Không sửa tệp XML sau khi ký**, kể cả định dạng lại cho đẹp.
5. **Không gửi dữ liệu thật** lên môi trường thử nghiệm khi chưa được đồng ý.
6. **Không tự đoán** khi đặc tả không rõ — ghi vào mục "Điểm cần làm rõ" của
   [01_DAC_TA_API_HEMIS.md](01_DAC_TA_API_HEMIS.md).
7. **Không viết hai đoạn mã độc lập** cho XML và JSON của cùng một phân hệ.

---

## 9. Trước khi gửi dữ liệu thật — danh mục kiểm tra

- [ ] `./mvnw test` đạt toàn bộ
- [ ] Đã chạy thử trên WireMock thành công
- [ ] Đã kiểm tra dữ liệu, không còn lỗi mức chặn
- [ ] Đã đối chiếu tệp XML với tệp mẫu ký thủ công trên cổng HEMIS
- [ ] Đã có phê duyệt của lãnh đạo cho đợt gửi
- [ ] Đã ghi lại `IKS` và `IdKey` để đối soát
