# 07. Nhật ký sự cố và bài học

HEMIS chỉ trả về `success: false` mà không nói rõ lý do. Vì vậy **kinh nghiệm xử lý lỗi là
tài sản quý nhất của nhóm**. Mỗi lần mất thời gian dò một lỗi, ghi lại vào đây để người sau
không mất lại chừng đó thời gian.

Ghi theo mẫu dưới, mới nhất ở trên cùng.

---

## Mẫu ghi

```
### [YYYY-MM-DD] Tiêu đề ngắn gọn

- **Hiện tượng**: thấy gì (thông báo lỗi nguyên văn, mã HTTP, trạng thái đợt)
- **Bối cảnh**: phân hệ nào, môi trường nào, IKS/IdKey bao nhiêu
- **Nguyên nhân**: tìm ra sau khi điều tra
- **Cách xử lý**: làm gì để hết lỗi
- **Phòng ngừa**: đã thêm kiểm thử/kiểm tra gì để không tái diễn
- **Mất bao lâu**: để biết lỗi nào đáng đầu tư phòng ngừa
```

---

## Các mục đã ghi

### [2026-10-12] Spring Boot 4 dùng Jackson 3, không phải Jackson 2

- **Hiện tượng**: biên dịch lỗi `package com.fasterxml.jackson.databind does not exist`
- **Bối cảnh**: khởi tạo dự án, Spring Boot 4.1.1
- **Nguyên nhân**: Spring Boot 4 chuyển sang Jackson 3, đổi gói từ `com.fasterxml.jackson.databind`
  sang `tools.jackson.databind`. Riêng annotation vẫn ở `com.fasterxml.jackson.annotation`.
  Jackson 3 cũng đổi `JsonNode.fieldNames()` thành `propertyNames()`.
- **Cách xử lý**: đổi import; `fieldNames()` → `propertyNames()` (trả về `Collection<String>`).
- **Phòng ngừa**: khi tra tài liệu trên mạng, chú ý phần lớn ví dụ viết cho Boot 3 + Jackson 2.
- **Mất bao lâu**: 15 phút

### [2026-10-12] Spring Initializr ghi phiên bản khác với Maven Central

- **Hiện tượng**: `Non-resolvable parent POM ... spring-boot-starter-parent:pom:4.1.1.RELEASE (absent)`
- **Nguyên nhân**: Initializr trả về `4.1.1.RELEASE` nhưng artifact trên Maven Central tên là `4.1.1`.
- **Cách xử lý**: sửa `<version>` trong `pom.xml` thành `4.1.1`.
- **Phòng ngừa**: sau khi sinh dự án mới, chạy `./mvnw -q test` ngay để phát hiện sớm.
- **Mất bao lâu**: 10 phút

---

## Những lỗi đã lường trước — chưa gặp

Ghi sẵn để khi gặp thì biết hướng, cập nhật lại khi đã xử lý thật.

| Hiện tượng dự kiến | Hướng kiểm tra đầu tiên |
| --- | --- |
| HEMIS trả `success: false`, `message` rỗng | Đối chiếu sáu quy tắc cấu trúc XML (`01_DAC_TA_API_HEMIS.md` mục 5) với tệp mẫu ký thủ công |
| "Dữ liệu đã tồn tại" | Tra `sync_batch` theo IKS; đợt trước có thể đã nộp db16 thành công. **Không sinh IKS mới** |
| `403 ERR_ACCESS_DENIED` | Đơn vị chưa được đăng ký đồng bộ, hoặc chưa gọi db16 trước dbN |
| `401` dù vừa lấy token | `DON_VI_ID` không thuộc quyền quản lý của tài khoản |
| Chữ ký xác minh không đạt | Tệp bị định dạng lại sau khi ký; hoặc tác nhân ký nhầm tệp của đợt khác |
| Ngày bị từ chối | Đặc tả ghi `yyyy-MM-dd` nhưng ví dụ dùng `dd/MM/yyyy` — thử đổi định dạng |
| Token hết hạn giữa đợt dài | `expires_in` thực tế có thể là 900 giây, không phải 900000 |
| Danh mục chưa ánh xạ được | Tra `catalog_map` các dòng `hemis_code IS NULL` |
