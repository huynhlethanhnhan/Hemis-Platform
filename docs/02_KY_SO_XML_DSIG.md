# 02. Ký số XML-DSig — vì sao khó và ta làm thế nào

Đây là phần nhiều rủi ro nhất của Giai đoạn 1. Đọc hết trước khi động vào mã trong gói `signing`.

---

## 1. Yêu cầu pháp lý

Công văn hướng dẫn của Bộ ghi: *"Cơ sở đào tạo thực hiện ký số dữ liệu trước khi đồng bộ qua API.
Người đứng đầu cơ sở đào tạo chịu trách nhiệm về tính đầy đủ, chính xác, thống nhất và kịp thời
của dữ liệu được đồng bộ."*

Nghĩa là: chữ ký số không phải thủ tục kỹ thuật, mà là chữ ký của **người có thẩm quyền**
lên dữ liệu. Không được tự động hóa theo kiểu bỏ qua khâu phê duyệt.

---

## 2. Chữ ký XML-DSig là gì

Khác với ký PDF (chữ ký đặt ở cuối tệp), XML-DSig nhúng chữ ký **vào trong chính tài liệu XML**.

Ba kiểu chính:

| Kiểu | Mô tả |
| --- | --- |
| Enveloped | Chữ ký nằm **bên trong** tài liệu được ký ← **HEMIS dùng kiểu này** |
| Enveloping | Tài liệu nằm bên trong thẻ chữ ký |
| Detached | Chữ ký và tài liệu tách rời |

Quy trình ký (đã chuẩn hóa theo W3C):

```
1. Chuẩn hóa (canonicalize) node được ký   — thuật toán exc-c14n
   → để khoảng trắng, thứ tự thuộc tính, namespace không làm đổi kết quả băm
2. Băm node đã chuẩn hóa                   — SHA-256  → DigestValue
3. Gom các DigestValue vào SignedInfo
4. Chuẩn hóa SignedInfo rồi ký bằng khóa riêng — RSA-SHA256 → SignatureValue
5. Đính kèm chứng thư công khai vào KeyInfo/X509Data
```

Thông số HEMIS yêu cầu:

| Thành phần | Giá trị |
| --- | --- |
| Canonicalization | `http://www.w3.org/2001/10/xml-exc-c14n#` |
| Signature method | `http://www.w3.org/2001/04/xmldsig-more#rsa-sha256` |
| Transform | `http://www.w3.org/2000/09/xmldsig#enveloped-signature` |
| Digest | `http://www.w3.org/2001/04/xmlenc#sha256` |
| Reference đầu tiên | `URI="#data"` → trỏ tới `DuLieuKySo Id="data"` |

**Hệ quả quan trọng**: sau khi ký, **không được sửa một ký tự nào** trong tệp — kể cả thêm
khoảng trắng hay định dạng lại cho đẹp. Mọi thay đổi làm chữ ký vô hiệu.

---

## 3. Vì sao không ký thẳng trên máy chủ Linux

Theo *Hướng dẫn sử dụng ký số* của Bộ, đường ký số chính thống là:

```
Người dùng  →  trình duyệt  →  plugin XmlSignerTriNam  →  USB token  →  chữ ký
                                (lắng nghe tại 127.0.0.1:64005)
```

Ba ràng buộc kỹ thuật:

1. **Plugin chỉ chạy trên Windows.** Bộ cài `XmlSignerTriNamSetup.exe`, tải tại
   `https://hemis-cms.moet.gov.vn/admin/assets/environments/XmlSignerTriNamSetup.exe`.
2. **Plugin chỉ lắng nghe ở `127.0.0.1`**, không nhận kết nối từ máy khác. Kiểm tra bằng
   `http://127.0.0.1:64005/check_usb`.
3. **USB token phải cắm vật lý** vào máy chạy plugin, kèm trình quản lý token của nhà cung cấp
   (VGCA Sign Service, FPT-CA Token Manager, VNPT, BKAV, MISA...).

Máy chủ ứng dụng chạy Linux, không có cổng USB, không cài được plugin → **không thể gọi trực tiếp**.

---

## 4. Giải pháp: tác nhân ký số theo cơ chế kéo

```
   VM-HEMIS-APP (Linux)                      VM-HEMIS-SIGN (Windows)
   ┌────────────────────┐                    ┌──────────────────────────┐
   │ hemis-platform     │                    │ Tác nhân ký số           │
   │                    │   (1) GET jobs     │                          │
   │ bảng sign_job      │◄───────────────────│  lặp mỗi 5 giây          │
   │                    │   (2) POST lease   │                          │
   │                    │◄───────────────────│  nhận XML chưa ký        │
   │                    │                    │          │               │
   │                    │                    │          ▼               │
   │                    │                    │  plugin 127.0.0.1:64005  │
   │                    │                    │          │               │
   │                    │                    │          ▼               │
   │                    │   (3) POST result  │   USB token + mã PIN     │
   │ xác minh lại chữ ký│◄───────────────────│   trả XML đã ký          │
   └────────────────────┘                    └──────────────────────────┘
```

Vì sao chọn cơ chế **kéo** (tác nhân chủ động gọi ra) thay vì **đẩy** (máy chủ gọi vào):

- Không phải mở cổng vào trạm ký số → giảm bề mặt tấn công.
- Trạm ký số có thể nằm sau NAT, hoặc tắt máy, mà cổng tích hợp vẫn chạy bình thường.
- Dễ cho nhiều trạm ký số cùng hoạt động sau này.

API nội bộ cho tác nhân (xem `signing/SignAgentController.java`):

| Lệnh | Đường dẫn | Ý nghĩa |
| --- | --- | --- |
| Lấy danh sách việc | `GET /internal/sign/jobs` | Trả về tối đa 10 việc đang `PENDING` |
| Nhận việc | `POST /internal/sign/jobs/{id}/lease` | Chuyển sang `LEASED`, trả về nội dung XML chưa ký |
| Trả kết quả | `POST /internal/sign/jobs/{id}/result` | Nhận XML đã ký hoặc báo lỗi |

Tất cả đều yêu cầu header `X-Agent-Token` khớp `hemis.signing.agent-token`.

> **Đường dẫn `/internal/**` phải bị chặn ở reverse proxy**, chỉ cho phép trong mạng nội bộ.

---

## 5. Tự xác minh lại trước khi gửi

Khi tác nhân trả tệp đã ký, `XmlDsigVerifier` kiểm tra lại **trước khi** chấp nhận:

| Kiểm tra | Bắt lỗi gì |
| --- | --- |
| `DuLieuKySo` có `Id="data"` | Chữ ký không tham chiếu được node dữ liệu |
| `k1` đầu, `k2` cuối | Sai thứ tự node — lỗi thường gặp khi tự ghép XML |
| `k1 + k2` khớp IKS của đợt | Ký nhầm tệp của đợt khác |
| `KySo` không nằm trong `DuLieuKySo` | Lồng sai cấp |
| `X509SubjectName` trước `X509Certificate` | Sai thứ tự trong `X509Data` |
| Chữ ký hợp lệ về mặt mật mã | Tệp bị sửa sau khi ký |

Đây là bước rẻ tiền nhưng chặn được phần lớn lỗi. Không có nó, chỉ biết sai khi HEMIS trả về
`success: false` mà không nói lý do.

Bật/tắt bằng `hemis.signing.verify-before-send` (mặc định bật, **không nên tắt**).

---

## 6. Ba phương án ký số

| Phương án | Mô tả | Sẵn sàng | Dùng khi nào |
| --- | --- | --- | --- |
| **PA1 — Thủ công** | Đăng nhập `hemis-cms.moet.gov.vn` → Công cụ kết nối → Ký số dữ liệu → tải tệp XML đã ký | Ngay khi có tài khoản | Dự phòng; dùng tuần 2 để lấy **tệp mẫu chuẩn** đối chiếu với tệp mình sinh ra |
| **PA2 — USB token + tác nhân** | Như mục 4 | 1–2 tuần tự phát triển | **Chính thức Giai đoạn 1** |
| **PA3 — Ký số từ xa** | VNPT SmartCA, Viettel MySign qua API; không cần thiết bị | 4–8 tuần (hợp đồng) | Mục tiêu Giai đoạn 2, cho phép ký theo lịch tự động |

### Việc nên làm sớm nhất

Tuần 2 của kế hoạch: **ký thủ công một tệp trên cổng HEMIS rồi tải về**. Tệp đó là chuẩn vàng —
so từng node với tệp mình sinh ra. Làm việc này sớm tiết kiệm được nhiều ngày dò lỗi.

---

## 7. Cài đặt trạm ký số

```
1. Cài trình quản lý USB token của nhà cung cấp chứng thư
   - Ban Cơ yếu Chính phủ: https://dichvucong.ca.gov.vn/page/taitainguyen/PM
     + TokenManager (thiết bị VGCA Sign Service cũ)
     + Driver USB Token Bit4ID (thiết bị mới)
     + Bộ công cụ tích hợp chữ ký số theo Nghị định 30/2020/NĐ-CP
   - FPT-CA: cài installer do nhà phát hành token cung cấp
2. Cắm USB token, mở trình quản lý, đăng nhập bằng mã PIN
3. Cài plugin XmlSignerTriNamSetup.exe
4. Kiểm tra: mở http://127.0.0.1:64005/check_usb
   → phải thấy thông tin chứng thư số
5. Cài tác nhân ký số của Trường, chạy như Windows Service, tự khởi động cùng máy
```

Lưu ý vận hành:

- Trạm ký số **bật 24/7**, đặt trong phòng có kiểm soát ra vào.
- Bật BitLocker; không cài phần mềm ngoài danh mục.
- Mã PIN do người được ủy quyền giữ, không ghi vào tệp cấu hình.
- Nếu máy ảo không nhận USB token: cấu hình USB passthrough trên hypervisor
  (Proxmox: `qm set <vmid> -usb0 host=<vendor>:<product>`), hoặc dùng máy vật lý,
  hoặc thiết bị USB-over-IP.

---

## 8. Lỗi thường gặp

| Hiện tượng | Nguyên nhân hay gặp |
| --- | --- |
| `check_usb` không trả về gì | Chưa mở trình quản lý token, hoặc chưa nhập mã PIN |
| Chữ ký xác minh không đạt ngay sau khi ký | Tệp bị định dạng lại (pretty-print) sau khi ký |
| HEMIS trả `success: false` không rõ lý do | Sai một trong sáu quy tắc cấu trúc ở `01_DAC_TA_API_HEMIS.md` mục 5 |
| "Dữ liệu đã tồn tại" | IKS đã dùng. Kiểm tra bảng `sync_batch`, **không sinh IKS mới** |
| Chữ ký hợp lệ nhưng HEMIS vẫn từ chối | Chứng thư hết hạn, hoặc chủ thể chứng thư không phải đơn vị được phép ký |
