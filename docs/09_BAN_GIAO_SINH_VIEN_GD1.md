# 09. Kế hoạch bàn giao sinh viên thực hiện Giai đoạn 1

| | |
| --- | --- |
| **Thời gian** | 19/10/2026 – 11/11/2026 (03 tuần + 02 ngày nhập môn) |
| **Người bàn giao** | ThS. Mai Vân Phương Vũ – Phòng Công nghệ thông tin |
| **Người nhận** | 03 sinh viên (SV1, SV2, SV3) |
| **Trạng thái nền tảng** | `hemis-platform` đã dựng xong, build sạch, 11 kiểm thử đạt |

---

## 1. Nguyên tắc bàn giao

**Giao việc, không giao trách nhiệm pháp lý.** Sinh viên viết mã và kiểm thử trên môi trường
mô phỏng. Mọi việc chạm tới hệ thống của Bộ hoặc dữ liệu thật do Phòng Công nghệ thông tin
thực hiện.

### Việc KHÔNG bàn giao

| Việc | Lý do |
| --- | --- |
| Tài khoản kết nối HEMIS, `client_secret`, mật khẩu | Công văn của Bộ: không chia sẻ thông tin xác thực cho người không có trách nhiệm |
| Chứng thư số, USB token, mã PIN | Chữ ký số là chữ ký của người có thẩm quyền |
| Gửi dữ liệu thật lên môi trường của Bộ | Một IKS chỉ dùng được một lần, gửi sai không gỡ lại được |
| Dữ liệu cá nhân thật (CCCD, hồ sơ người học) | Nghị định 13/2023/NĐ-CP |
| Triển khai lên máy chủ | Quy trình vận hành |

Sinh viên làm việc với **dữ liệu giả** và **WireMock**. Khi cần dữ liệu thật để kiểm chứng,
Phòng Công nghệ thông tin chạy và cung cấp lại kết quả đã che thông tin cá nhân.

### Định nghĩa "xong"

Một nhiệm vụ xong khi đủ **bốn** điều kiện:

1. Mã chạy được trên máy của người khác sau khi `git pull` (không phải chỉ máy mình).
2. Có kiểm thử tự động cho tiêu chí chấp nhận ghi trong nhiệm vụ.
3. `./mvnw test` đạt toàn bộ.
4. Đã được ThS. Vũ rà soát và hợp nhất vào `main`.

> Không có mục 2 thì không tính là xong, kể cả khi demo chạy tốt.

---

## 2. Hai ngày nhập môn (19–20/10/2026)

Bắt buộc với cả ba sinh viên, làm **trước khi** nhận nhiệm vụ.

| Buổi | Nội dung | Kết quả phải đạt |
| --- | --- | --- |
| Sáng 19/10 | Đọc [00_LO_TRINH_DOC.md](00_LO_TRINH_DOC.md) Ngày 1: công văn của Bộ, Thông tư 83/2026, kế hoạch, [01_DAC_TA_API_HEMIS.md](01_DAC_TA_API_HEMIS.md) | Vẽ lại bằng tay luồng một đợt đồng bộ, không nhìn tài liệu |
| Chiều 19/10 | Dựng môi trường theo [05_MOI_TRUONG_PHAT_TRIEN.md](05_MOI_TRUONG_PHAT_TRIEN.md) | Chạy được `docker compose up -d` và ứng dụng; `./mvnw test` đạt |
| Sáng 20/10 | [02_KY_SO_XML_DSIG.md](02_KY_SO_XML_DSIG.md), [03_KIEN_TRUC_MA_NGUON.md](03_KIEN_TRUC_MA_NGUON.md), [10_THIET_KE_CSDL.md](10_THIET_KE_CSDL.md) | Trả lời được: vì sao không ký số trên Linux; vì sao không dùng khóa `SERIAL` làm định danh gửi Bộ |
| Chiều 20/10 | [04_QUY_UOC_LAP_TRINH.md](04_QUY_UOC_LAP_TRINH.md); gọi API `chuan-bi`; mở tệp XML sinh ra | Chỉ ra được `k1`, `k2`, `Id="data"`; chứng minh `k1 + k2` bằng tên thư mục IKS |
| Cuối ngày 20/10 | Họp giao nhiệm vụ | Mỗi người nhận gói nhiệm vụ và xác nhận hiểu tiêu chí chấp nhận |

**Buổi họp giao nhiệm vụ** (60 phút): mỗi sinh viên tự đọc to tiêu chí chấp nhận của
nhiệm vụ đầu tiên và nói lại bằng lời của mình sẽ kiểm chứng thế nào. Nếu không nói được
thì nhiệm vụ chưa đủ rõ — sửa mô tả ngay tại chỗ.

---

## 3. Phân công

| | Vai trò | Tập trung vào | Nền tảng cần biết |
| --- | --- | --- | --- |
| **SV1** | Dữ liệu | Đọc kho dữ liệu cũ, định danh, danh mục, địa giới mới | SQL, PostgreSQL |
| **SV2** | Kiểm tra dữ liệu | Bộ quy tắc từ đặc tả, báo cáo khoảng trống | Java, đọc tài liệu kỹ |
| **SV3** | Ký số và giao diện | Tác nhân ký số trên Windows, màn hình theo dõi | C#/.NET hoặc Java; HTML/JS cơ bản |

Ba gói độc lập nhau, chạy song song được. Điểm giao duy nhất là `SyncOrchestrator`, do
ThS. Vũ giữ.

---

## 4. Gói nhiệm vụ SV1 — Dữ liệu (≈ 55 giờ)

### SV1-01 · Nhập thông tin chung của Trường · 4h · Tuần 1

| | |
| --- | --- |
| **Việc** | Điền đúng 01 dòng vào bảng `hemis_sync.co_so_giao_duc` |
| **Đầu vào** | Số liệu do Phòng Tổ chức – Hành chính cung cấp (ThS. Vũ xin) |
| **Đầu ra** | Script `db/seed/co_so_giao_duc.sql` (dùng giá trị mẫu, không phải số thật) |
| **Chấp nhận** | 1. Toàn bộ trường `NOT NULL` có giá trị.<br>2. `tinh_thanh_new`, `xa_phuong_new` dùng mã của `DM_TINH_NEW`, `DM_XA_NEW`, không phải mã cũ.<br>3. `SELECT * FROM hemis_src.v_co_so_giao_duc` trả về đúng 1 dòng, đủ cột. |
| **Liên quan** | FR-EXT-02 |

### SV1-02 · Hoàn thiện bộ trích xuất COSOGIAODUC · 10h · Tuần 1

| | |
| --- | --- |
| **Việc** | Sửa `CoSoGiaoDucExtractor` để đọc từ `hemis_src.v_co_so_giao_duc` thay vì đọc cấu hình |
| **Chấp nhận** | 1. Không còn giá trị nghiệp vụ nào lấy từ `application.yml`.<br>2. Thiếu bất kỳ trường bắt buộc nào → ném lỗi nêu rõ tên trường.<br>3. XML và JSON sinh ra từ **cùng một** đối tượng; có kiểm thử so khớp tên trường giữa hai bản.<br>4. Không có chuỗi `public.` nào trong mã Java. |
| **Liên quan** | FR-EXT-02, FR-EXT-05 |

### SV1-03 · Hiện thực `entity_map` · 8h · Tuần 1

| | |
| --- | --- |
| **Việc** | Lớp cấp GUID theo khóa nghiệp vụ; chưa có thì sinh mới và lưu |
| **Chấp nhận** | 1. Gọi hai lần với cùng khóa nghiệp vụ trả về cùng GUID.<br>2. Xóa và nạp lại dữ liệu nguồn **không** làm đổi GUID (có kiểm thử mô phỏng `reset_all.sql`).<br>3. Bản ghi thiếu khóa nghiệp vụ (CCCD rỗng) → báo lỗi, **không** sinh GUID.<br>4. Không có đường nào sinh GUID mà không qua lớp này. |
| **Liên quan** | FR-EXT-03 · đọc [10_THIET_KE_CSDL.md](10_THIET_KE_CSDL.md) mục 3 trước |

### SV1-04 · Danh mục địa giới mới · 12h · Tuần 2

| | |
| --- | --- |
| **Việc** | Bổ sung `DM_TINH_NEW`, `DM_XA_NEW` và bảng ánh xạ địa giới cũ → mới theo Quyết định 19/2025/QĐ-TTg |
| **Đầu ra** | Migration `V4__dia_gioi_moi.sql` + bảng `hemis_sync.dia_gioi_map(ma_cu, ma_moi, loai, ghi_chu)` |
| **Chấp nhận** | 1. Dữ liệu danh mục lấy từ API danh mục của HEMIS, không gõ tay.<br>2. Ánh xạ được tối thiểu các tỉnh/xã có trong dữ liệu của Trường.<br>3. Ca không ánh xạ được **giữ lại** trong bảng với `ghi_chu`, không xóa, không sửa tay rồi bỏ dấu vết.<br>4. Cột `*_NEW` trong `hemis_src.v_can_bo`, `v_nguoi_hoc` trả giá trị thật thay vì `NULL`. |
| **Lưu ý** | Phần "ca không ánh xạ được" là tài sản — giữ nguyên để phân tích sau |

### SV1-05 · Lưu danh mục HEMIS · 10h · Tuần 2

| | |
| --- | --- |
| **Việc** | Lưu hơn 175 danh mục tải về vào `catalog_hemis` |
| **Khó ở chỗ** | Tên trường mã và tên **thay đổi theo từng danh mục** (`MA_DAN_TOC`, `MA_TINH`…) — phải suy ra động từ tên danh mục, không gắn cứng |
| **Chấp nhận** | 1. Chạy hai lần không tạo bản ghi trùng.<br>2. `IsDeleted = true` → đánh dấu xóa, không xóa vật lý.<br>3. Giữ bản ghi gốc trong `raw_json`.<br>4. Có kiểm thử với dữ liệu mẫu của WireMock. |
| **Liên quan** | FR-CAT-02 |

### SV1-06 · Đối chiếu danh mục · 8h · Tuần 3

| | |
| --- | --- |
| **Việc** | Sinh bảng `catalog_diff`: so danh mục của kho dữ liệu với danh mục HEMIS |
| **Chấp nhận** | 1. Phân loại đúng `CHI_CO_DWH`, `CHI_CO_HEMIS`, `LECH_TEN`, `TRUNG_KHOP`.<br>2. Có API trả về danh sách mã chưa ánh xạ được theo từng danh mục.<br>3. Chạy lại ghi đè kết quả cũ, không tích lũy rác. |
| **Liên quan** | FR-CAT-03 |

### SV1-07 · Kiểm thử · 3h · Tuần 3

Bổ sung kiểm thử còn thiếu cho SV1-02 đến SV1-06; bảo đảm `./mvnw test` đạt.

---

## 5. Gói nhiệm vụ SV2 — Kiểm tra dữ liệu (≈ 52 giờ)

> Đây là gói quan trọng nhất về chất lượng. HEMIS **không trả lỗi theo từng bản ghi** — chỉ
> một cờ `success` cho cả đợt. Bộ kiểm tra của ta là lớp phòng vệ duy nhất.

### SV2-01 · Trích quy tắc từ đặc tả · 10h · Tuần 1

| | |
| --- | --- |
| **Việc** | Đọc chương 4 của đặc tả (phân hệ Cơ sở giáo dục), lập tệp `rules/cosogiaoduc.yml` |
| **Mỗi trường ghi** | tên trường, bắt buộc, độ dài tối đa, kiểu dữ liệu, danh mục tham chiếu, điều kiện (nếu có) |
| **Chấp nhận** | 1. Đủ toàn bộ trường của mảng `_CO_SO_GIAO_DUC`, không bỏ sót.<br>2. Mỗi dòng ghi rõ số mục trong đặc tả để đối chiếu lại được.<br>3. Nạp được vào bảng `validation_rule` bằng một lệnh. |
| **Lưu ý** | Gặp chỗ đặc tả mâu thuẫn → **không tự quyết**, ghi vào mục "Điểm cần làm rõ" của [01_DAC_TA_API_HEMIS.md](01_DAC_TA_API_HEMIS.md) |

### SV2-02 · Bộ máy quy tắc · 16h · Tuần 1–2

| | |
| --- | --- |
| **Việc** | Hiện thực 5 loại quy tắc: `REQUIRED`, `MAX_LENGTH`, `DATA_TYPE`, `CATALOG`, `CONDITIONAL` |
| **Chấp nhận** | 1. Mỗi loại có **01 ca đạt và 01 ca trượt** trong kiểm thử.<br>2. `CATALOG` tra `catalog_map`; mã chưa ánh xạ → lỗi `MISSING` mức chặn.<br>3. `CONDITIONAL` chạy đúng ví dụ của đặc tả: `SO_QD_TOT_NGHIEP` bắt buộc khi `TRANG_THAI_ID = '04'`.<br>4. Thêm quy tắc mới **không** phải biên dịch lại mã. |
| **Liên quan** | FR-VAL-01, FR-VAL-02 |

### SV2-03 · Báo cáo khoảng trống dữ liệu · 12h · Tuần 2

| | |
| --- | --- |
| **Việc** | Hoàn thiện hàm `hemis_sync.kiem_tra_khoang_trong` và API trả về kết quả |
| **Chấp nhận** | 1. Chạy được **bất kỳ lúc nào**, không cần tạo đợt đồng bộ.<br>2. Trả về theo từng trường: tổng bản ghi, số thiếu, tỷ lệ đạt.<br>3. Nhóm được theo đơn vị chịu trách nhiệm.<br>4. Xuất ra bảng để đính kèm văn bản gửi phòng, ban. |
| **Vì sao quan trọng** | Đây là công cụ chính để đạt 100% trước 31/12/2026 — xem [08_SRS.md](08_SRS.md) mục 1.5 |
| **Liên quan** | FR-DQ-02, FR-DQ-03 |

### SV2-04 · Nối vào luồng đồng bộ · 6h · Tuần 3

| | |
| --- | --- |
| **Việc** | Gọi bộ kiểm tra trong `SyncOrchestrator.chuanBi()` |
| **Chấp nhận** | 1. Còn lỗi mức `BLOCK` → đợt chuyển `CHO_SUA_LOI`, **không** đóng gói, **không** vào hàng đợi ký số.<br>2. Chỉ có `WARN` → vẫn tiếp tục, ghi cảnh báo.<br>3. Mỗi lỗi ghi một dòng `sync_error` có `local_id`, `field`, `rule_code`. |
| **Lưu ý** | Sửa `SyncOrchestrator` phải báo ThS. Vũ trước — đây là điểm giao chung |

### SV2-05 · Kiểm thử · 8h · Tuần 3

Bộ kiểm thử đầy đủ cho 5 loại quy tắc và luồng chặn đợt.

---

## 6. Gói nhiệm vụ SV3 — Ký số và giao diện (≈ 56 giờ)

### SV3-01 · Dựng trạm ký số · 6h · Tuần 1

| | |
| --- | --- |
| **Việc** | Cài trình quản lý USB token và plugin `XmlSignerTriNamSetup.exe` trên máy Windows thử nghiệm |
| **Chấp nhận** | 1. `http://127.0.0.1:64005/check_usb` trả về thông tin chứng thư.<br>2. Ghi lại **từng bước cài đặt kèm ảnh màn hình** vào [02_KY_SO_XML_DSIG.md](02_KY_SO_XML_DSIG.md) mục 7. |
| **Lưu ý** | Dùng USB token thử nghiệm do ThS. Vũ cung cấp, **không** dùng chứng thư của Trường |

### SV3-02 · Tác nhân ký số · 20h · Tuần 1–2

| | |
| --- | --- |
| **Việc** | Chương trình kéo việc từ cổng tích hợp, gọi plugin, trả tệp đã ký |
| **Luồng** | `GET /internal/sign/jobs` → `POST .../lease` → gọi `127.0.0.1:64005` → `POST .../result` |
| **Chấp nhận** | 1. Lặp mỗi 5 giây, không chiếm CPU.<br>2. Mất kết nối tới cổng tích hợp → thử lại, **không** làm hỏng việc đang giữ.<br>3. Plugin trả lỗi → gọi `result` kèm `error`, không treo.<br>4. **Không** ghi mã PIN ra tệp hay nhật ký.<br>5. Tệp ký xong qua được `XmlDsigVerifier` (đã có sẵn, không sửa). |
| **Liên quan** | FR-SGN-03 · đọc [02_KY_SO_XML_DSIG.md](02_KY_SO_XML_DSIG.md) mục 4 trước |

### SV3-03 · Chạy như dịch vụ nền · 6h · Tuần 2

| | |
| --- | --- |
| **Chấp nhận** | 1. Chạy như Windows Service, tự khởi động cùng máy.<br>2. Khởi động lại máy → tự chạy lại, nhận tiếp việc đang chờ.<br>3. Có hướng dẫn cài đặt để người khác làm theo được. |

### SV3-04 · Màn hình theo dõi đợt đồng bộ · 16h · Tuần 2–3

| | |
| --- | --- |
| **Việc** | Một trang hiển thị danh sách đợt: phân hệ, trạng thái, số bản ghi, thời điểm; bấm vào xem chi tiết và nhật ký |
| **Chấp nhận** | 1. Dùng API `/api/v1/hemis/dot` đã có, **không** truy vấn thẳng cơ sở dữ liệu.<br>2. Hiển thị đúng 9 trạng thái của đợt.<br>3. Nút tạo đợt mới và nút gửi, có hỏi xác nhận trước khi gửi.<br>4. Chạy được trên trình duyệt ở máy khác trong mạng nội bộ. |
| **Gợi ý** | Giai đoạn 1 chỉ cần HTML + JS thuần hoặc một trang Thymeleaf; **không** dựng dự án frontend riêng |

### SV3-05 · Màn hình danh sách lỗi · 8h · Tuần 3

| | |
| --- | --- |
| **Chấp nhận** | 1. Lọc theo đợt, theo đơn vị chịu trách nhiệm, theo mức lỗi.<br>2. Xuất được ra Excel hoặc CSV để gửi phòng, ban.<br>3. Hiển thị rõ: bản ghi nào, trường nào, vi phạm quy tắc gì. |
| **Phụ thuộc** | SV2-03 xong trước |

---

## 7. Lịch theo tuần

| Tuần | SV1 | SV2 | SV3 | Mốc chung |
| --- | --- | --- | --- | --- |
| **Nhập môn**<br>19–20/10 | Đọc tài liệu, dựng môi trường | Đọc tài liệu, dựng môi trường | Đọc tài liệu, dựng môi trường | Họp giao nhiệm vụ chiều 20/10 |
| **Tuần 1**<br>21–27/10 | SV1-01, SV1-02, SV1-03 | SV2-01, SV2-02 (phần đầu) | SV3-01, SV3-02 (phần đầu) | Hợp nhất lần 1 — thứ Hai 27/10 |
| **Tuần 2**<br>28/10–03/11 | SV1-04, SV1-05 | SV2-02 (xong), SV2-03 | SV3-02 (xong), SV3-03, SV3-04 | Hợp nhất lần 2 — thứ Hai 03/11 |
| **Tuần 3**<br>04–10/11 | SV1-06, SV1-07 | SV2-04, SV2-05 | SV3-04 (xong), SV3-05 | Đóng băng mã 10/11 |
| **Nghiệm thu**<br>11/11 | — | — | — | Chạy thử toàn luồng, bàn giao |

**Nhịp làm việc**

- **Hằng ngày** (15 phút, trực tuyến): hôm qua làm gì, hôm nay làm gì, đang vướng gì.
- **Thứ Hai hằng tuần** (60 phút): rà soát mã và hợp nhất vào `main`.
- **Quy tắc 30 phút**: vướng quá 30 phút mà không tiến triển thì hỏi ngay, không ngồi mò.
  Hỏi không mất điểm; giấu mới mất thời gian của cả nhóm.

---

## 8. Quy trình làm việc với mã nguồn

```bash
git checkout -b feat/sv1-entity-map     # một nhiệm vụ, một nhánh
# ... viết mã và kiểm thử ...
./mvnw test                              # phải đạt trước khi đẩy
git push -u origin feat/sv1-entity-map
# mở pull request, gắn mã nhiệm vụ (SV1-03) vào tiêu đề
```

Quy ước commit và những điều không được làm: [04_QUY_UOC_LAP_TRINH.md](04_QUY_UOC_LAP_TRINH.md).

**Rà soát mã** do ThS. Vũ thực hiện, kiểm ba điểm: (1) đủ kiểm thử cho tiêu chí chấp nhận;
(2) không có bí mật trong mã; (3) không truy vấn thẳng `public.` của kho dữ liệu.

Mỗi lỗi mất thời gian xử lý đều ghi vào [07_NHAT_KY_SU_CO.md](07_NHAT_KY_SU_CO.md).

---

## 9. Phần ThS. Vũ giữ lại

| Việc | Khi nào |
| --- | --- |
| Xin tài khoản kết nối, làm việc với Cục KHCN&TT | Liên tục |
| Gọi API thật, gửi db16 và db1 trên môi trường thử nghiệm | Tuần 3 |
| Quản lý chứng thư số, mã PIN | Liên tục |
| Sửa `SyncOrchestrator` và `HemisSyncClient` | Liên tục |
| Rà soát mã, hợp nhất `main` | Thứ Hai hằng tuần |
| Triển khai máy chủ, sao lưu, giám sát | Tuần 3 |
| Xin số liệu thật từ các phòng, ban | Tuần 1 |
| Nghiệm thu Giai đoạn 1 | 11/11 |

---

## 10. Rủi ro

| Rủi ro | Dấu hiệu sớm | Biện pháp |
| --- | --- | --- |
| Sinh viên vướng lịch thi, giảm giờ làm | Vắng họp hằng ngày 2 buổi liên tiếp | Hỏi lịch thi **ngay buổi giao nhiệm vụ**; bố trí nhiệm vụ nặng tránh tuần thi |
| Một sinh viên nghỉ giữa chừng | — | Ba gói độc lập; ưu tiên cứu SV2 (kiểm tra dữ liệu) vì liên quan trực tiếp mốc 31/12 |
| Chưa có tài khoản của Bộ đến hết tuần 3 | Chưa có phản hồi sau 23/10 | Toàn bộ nhiệm vụ của sinh viên chạy trên WireMock, không phụ thuộc |
| USB token không hoạt động trên máy ảo | `check_usb` không trả kết quả | Chuyển sang máy vật lý; SV3 làm SV3-04 trước, SV3-02 sau |
| Chất lượng mã không đạt, dồn vào tuần cuối | Hợp nhất lần 1 (27/10) bị trả lại nhiều | Rà soát mã từ tuần 1, không để đến cuối |
| Số liệu thật của Trường chưa xin được | Chưa có sau 27/10 | SV1-01 dùng giá trị mẫu; thay số thật ở khâu nghiệm thu |

---

## 11. Danh mục kiểm tra nghiệm thu ngày 11/11/2026

| TT | Nội dung | Người kiểm | Đạt |
| --- | --- | --- | --- |
| 1 | `./mvnw test` đạt toàn bộ, không có kiểm thử bị tắt ngoài kiểm thử cần Docker | ThS. Vũ | ☐ |
| 2 | Chạy `chuan-bi` sinh được tệp XML đúng cấu trúc từ dữ liệu trong kho dữ liệu | SV1 | ☐ |
| 3 | Bộ kiểm tra chặn được đợt khi thiếu trường bắt buộc | SV2 | ☐ |
| 4 | Báo cáo khoảng trống chạy được và xuất ra bảng | SV2 | ☐ |
| 5 | Tác nhân ký số ký được tệp thật, qua được tự xác minh | SV3 | ☐ |
| 6 | Màn hình theo dõi hiển thị đúng trạng thái đợt và danh sách lỗi | SV3 | ☐ |
| 7 | Gửi thành công db16 và db1 trên môi trường thử nghiệm của Bộ | ThS. Vũ | ☐ |
| 8 | Không có bí mật nào trong kho mã nguồn | ThS. Vũ | ☐ |
| 9 | Tài liệu đã cập nhật: hướng dẫn cài trạm ký số, nhật ký sự cố | Cả nhóm | ☐ |
| 10 | Mỗi sinh viên trình bày 10 phút phần mình làm và chạy thử trực tiếp | Cả nhóm | ☐ |

Mục 10 không phải thủ tục: sinh viên giải thích được phần mình viết là bằng chứng rõ nhất
rằng Phòng Công nghệ thông tin tiếp nhận và bảo trì được sau khi các em rời dự án.
