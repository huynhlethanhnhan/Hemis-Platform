# 00. Lộ trình đọc cho người mới vào nhóm

Tài liệu này dành cho người lần đầu tham gia dự án kết nối HEMIS. Mục tiêu: sau 2 ngày,
bạn hiểu đủ để nhận một việc cụ thể mà không phải hỏi lại từ đầu.

Đọc theo đúng thứ tự dưới đây. Đừng mở mã nguồn trước khi xong Ngày 1.

---

## Ngày 1 — Hiểu bài toán (khoảng 4 giờ)

| Thứ tự | Đọc gì                                                                                                                                                             | Ở đâu                                                        | Thời gian | Sau khi đọc phải trả lời được                                 |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------ | --------- | ------------------------------------------------------------- |
| 1      | Công văn hướng dẫn kết nối API của Bộ                                                                                                                              | `../BGDdT-KHNCTT CV huong dan ket noi API HEMIS-5768408.pdf` | 30 phút   | Bộ yêu cầu Trường làm gì, hạn nào, ai chịu trách nhiệm?       |
| 2      | **Thông tư 83/2026/TT-BGDĐT – Chuẩn cơ sở giáo dục đại học** (đọc Điều 5, Điều 6 Tiêu chí 1.3, Điều 8, Điều 13, Điều 14; Phụ lục II chỉ số 1.3; Phụ lục V Bảng 1C) | `../document guide/83_2026_TT-BGDDT.pdf`                     | 60 phút   | Vì sao chỉ số 1.3 phải đạt 100% và hạn thực sự là 31/12/2026? |
| 3      | Kế hoạch kết nối HEMIS của Trường                                                                                                                                  | `../plan/Ke_hoach_ket_noi_HEMIS.docx`                        | 45 phút   | Dự án chia mấy giai đoạn, ta đang ở đâu?                      |
| 4      | Phương án kỹ thuật Giai đoạn 1                                                                                                                                     | `../plan/PA_Ky_thuat_GD1_Ket_noi_API_HEMIS.docx`             | 45 phút   | Một tháng này phải xong những gì, tiêu chí nghiệm thu là gì?  |
| 5      | [01_DAC_TA_API_HEMIS.md](01_DAC_TA_API_HEMIS.md)                                                                                                                   | thư mục này                                                  | 60 phút   | 14 API của Bộ làm gì, một đợt đồng bộ đi qua mấy bước?        |
| 6      | [06_THUAT_NGU.md](06_THUAT_NGU.md)                                                                                                                                 | thư mục này                                                  | 20 phút   | IKS, IdKey, PH, DON_VI_ID, danh mục dùng chung là gì?         |

**Bài tập cuối ngày 1**: vẽ lại bằng tay luồng một đợt đồng bộ, từ dữ liệu trong kho đến khi
HEMIS trả về `success: true`. Không nhìn tài liệu.

---

## Ngày 2 — Hiểu cách làm (khoảng 4 giờ)

| Thứ tự | Đọc gì                                                     | Thời gian | Sau khi đọc phải trả lời được                            |
| ------ | ---------------------------------------------------------- | --------- | -------------------------------------------------------- |
| 7      | [02_KY_SO_XML_DSIG.md](02_KY_SO_XML_DSIG.md)               | 60 phút   | Vì sao không ký số thẳng trên máy chủ Linux được?        |
| 8      | [05_MOI_TRUONG_PHAT_TRIEN.md](05_MOI_TRUONG_PHAT_TRIEN.md) | 45 phút   | Chạy được dự án trên máy mình                            |
| 9      | [03_KIEN_TRUC_MA_NGUON.md](03_KIEN_TRUC_MA_NGUON.md)       | 45 phút   | Mỗi gói mã nguồn làm gì, sửa ở đâu khi thêm phân hệ mới? |
| 10     | [04_QUY_UOC_LAP_TRINH.md](04_QUY_UOC_LAP_TRINH.md)         | 30 phút   | Viết mã và commit theo quy ước nào?                      |

**Bài tập cuối ngày 2**: chạy `docker compose up -d`, chạy ứng dụng, gọi API `chuan-bi`,
mở tệp XML sinh ra và chỉ ra được: node `k1`, node `k2`, thuộc tính `Id="data"`,
và chứng minh `k1 + k2` bằng đúng IKS trong tên thư mục.

---

## Ngày 3 — Nhận việc

Đọc [08_SRS.md](08_SRS.md) — đặc tả yêu cầu phần mềm. Đây là tài liệu **tra cứu khi làm việc**,
không đọc một lượt từ đầu đến cuối. Cách dùng:

1. Đọc mục 1 (quy ước đánh mã) và mục 2 (tổng quan) — 20 phút.
2. Xem **mục 6 Ma trận truy vết** để biết việc mình nhận tương ứng yêu cầu nào, mã nguồn ở
   đâu, đã có kiểm thử chưa.
3. Mở đúng yêu cầu `FR-xxx` của việc mình làm, đọc phần **Tiêu chí chấp nhận** — đó chính là
   định nghĩa "làm xong".
4. Xem **mục 7 Điểm chưa rõ** trước khi viết mã, tránh làm theo phỏng đoán rồi phải sửa lại.

Quy ước: **một việc xong khi tiêu chí chấp nhận của yêu cầu đó được kiểm chứng bằng kiểm thử
tự động**, không phải khi mã chạy được trên máy mình.

---

## Đọc theo việc được giao

Khi đã qua 2 ngày trên, chỉ đọc phần liên quan đến việc của mình.

| Việc được giao                           | Đọc thêm                                                                                                               | Mã nguồn bắt đầu từ                          |
| ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| Thêm một phân hệ mới (CANBO, HOCVIEN...) | Đặc tả API của Bộ, chương tương ứng                                                                                    | `staging/CoSoGiaoDucExtractor.java`          |
| Nối dữ liệu từ kho HEMIS nội bộ          | [13_HUONG_DAN_KET_NOI_KHO_DU_LIEU.md](13_HUONG_DAN_KET_NOI_KHO_DU_LIEU.md), [10_THIET_KE_CSDL.md](10_THIET_KE_CSDL.md) | `db/setup/01_ket_noi_hemis_noi_bo.sql`       |
| Viết bộ quy tắc kiểm tra dữ liệu         | Bảng trường dữ liệu trong đặc tả                                                                                       | `V1__hemis_sync.sql`, bảng `validation_rule` |
| Làm tác nhân ký số trên Windows          | `02_KY_SO_XML_DSIG.md`, `../plan/HuongDanKySo_HEMIS.pdf`                                                               | `signing/SignAgentController.java`           |
| Ánh xạ danh mục                          | Chương 2 của đặc tả (175 danh mục)                                                                                     | `client/HemisCatalogClient.java`             |
| Màn hình theo dõi đồng bộ                | [12_HUONG_DAN_QUAN_TRI_DONG_BO.md](12_HUONG_DAN_QUAN_TRI_DONG_BO.md)                                                   | `api/AdminController.java`                   |
| Hạ tầng, mạng, sao lưu                   | Phương án kỹ thuật GĐ1, mục II                                                                                         | `docker-compose.yml`                         |

---

## Tài liệu gốc của Bộ — nơi lưu

| Tài liệu                                                     | Đường dẫn                                                                                       |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| **Thông tư 83/2026/TT-BGDĐT – Chuẩn cơ sở giáo dục đại học** | `../document guide/83_2026_TT-BGDDT.pdf`                                                        |
| Công văn hướng dẫn kết nối API                               | `../BGDdT-KHNCTT CV huong dan ket noi API HEMIS-5768408.pdf`                                    |
| Đặc tả kỹ thuật API (bản đầy đủ)                             | `../Hướng dẫn kết nối API-20261002T131918Z-1-001/Hướng dẫn kết nối API/APIKetNoiHemis_V2.0.pdf` |
| Hướng dẫn sử dụng ký số                                      | `../plan/HuongDanKySo_HEMIS.pdf`                                                                |
| Bộ cài plugin ký số                                          | `../plan/XmlSignerTriNamSetup.zip`                                                              |

**Lưu ý**: đặc tả của Bộ có thể được cập nhật. Trước khi viết mã cho một phân hệ, kiểm tra
lại bản mới nhất với đầu mối kỹ thuật, đừng tin bản đã tải về từ lâu.

---

## Nguyên tắc làm việc của nhóm

1. **Không đoán khi đặc tả không rõ.** Ghi câu hỏi vào mục "Điểm cần làm rõ" trong
   [01_DAC_TA_API_HEMIS.md](01_DAC_TA_API_HEMIS.md), đầu mối kỹ thuật sẽ hỏi Cục KHCN&TT.
2. **Không gửi dữ liệu thật lên môi trường thử nghiệm của Bộ khi chưa được đồng ý.**
3. **Không commit bí mật** (`.env`, chứng thư số, mã PIN, mật khẩu).
4. **Mỗi lỗi gặp phải đều ghi lại** vào `docs/07_NHAT_KY_SU_CO.md` — HEMIS chỉ trả về
   `success: false` nên kinh nghiệm xử lý lỗi là tài sản quý nhất của nhóm.
