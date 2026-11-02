# 12. Hướng dẫn API và giao diện quản trị theo dõi đồng bộ

|               |                                                                                                       |
| ------------- | ----------------------------------------------------------------------------------------------------- |
| **Người đọc** | Cán bộ kỹ thuật vận hành đợt đồng bộ; người làm màn hình theo dõi                                     |
| **Phạm vi**   | API quản trị của `hemis-platform` và màn hình theo dõi đợt, nhật ký, danh sách lỗi                    |
| **Mã nguồn**  | `api/AdminController.java`, `journal/SyncBatch.java`, `journal/SyncError.java`, `journal/ApiLog.java` |
| **Yêu cầu**   | FR-ADM-01, FR-ADM-02 trong [08_SRS.md](08_SRS.md)                                                     |

Cổng này **chưa có đăng nhập**. Chỉ mở trong mạng nội bộ, chặn ở reverse proxy. Không đưa phản hồi API ra ngoài mạng Trường: lệnh kiểm tra token trả về một đoạn đầu của access token.

Đường dẫn gốc khi chạy máy phát triển: `http://localhost:8080`.

---

## 1. Một đợt đi qua những trạng thái nào

Mỗi dòng trong bảng `sync_batch` là một đợt, một phân hệ, một mã phiên ký số (IKS). IKS sinh một lần. Gửi lại cùng IKS sẽ bị HEMIS từ chối. Muốn gửi lại thì tạo đợt mới.

```
KHOI_TAO → DA_DONG_GOI → CHO_KY_SO → DA_KY_SO → DA_GUI_XML → DA_GUI_JSON → DA_DOI_SOAT
               │              │            │            │
               │              │            │            └─ THAT_BAI   (db16 hoặc dbN lỗi)
               │              │            └─ THAT_BAI               (tác nhân báo ký lỗi)
               │              └─ (chờ người ký / tác nhân ký số)
               └─ CHO_SUA_LOI            (có lỗi BLOCK, chưa đóng gói)
```

| Trạng thái    | Ý nghĩa với người vận hành                               | Việc tiếp theo trên màn hình                                      |
| ------------- | -------------------------------------------------------- | ----------------------------------------------------------------- |
| `KHOI_TAO`    | Mới tạo, chưa xong bước chuẩn bị                         | Chờ, hoặc xem thông báo lỗi nếu lệnh chuẩn bị thất bại giữa chừng |
| `CHO_SUA_LOI` | Có lỗi mức chặn. Chưa sinh XML, chưa đưa vào hàng đợi ký | Mở danh sách lỗi, sửa dữ liệu nguồn, chuẩn bị đợt mới             |
| `CHO_KY_SO`   | XML và JSON đã ghi ra đĩa, đang chờ ký                   | Không bấm Gửi. Chờ trạm ký số, hoặc ký thủ công rồi nạp tệp đã ký |
| `DA_KY_SO`    | Chữ ký đã được tự xác minh                               | Bấm Gửi                                                           |
| `DA_GUI_XML`  | Đã nộp XML (db16), đang hoặc sắp gọi JSON                | Nếu kẹt ở đây: xem nhật ký, chưa gọi lại db16 với cùng IKS        |
| `DA_GUI_JSON` | HEMIS đã nhận cả hai bước                                | Đối soát trên cổng HEMIS trong 03 ngày làm việc                   |
| `DA_DOI_SOAT` | Đã ghi nhận đối soát xong                                | Không có lệnh đánh dấu trạng thái này trên API hiện tại           |
| `THAT_BAI`    | Ký số, db16 hoặc dbN thất bại                            | Đọc `message` và nhật ký. Sửa nguyên nhân rồi tạo đợt mới         |

Cảnh báo mức `WARN` không chặn đóng gói. Chỉ `BLOCK` đưa đợt về `CHO_SUA_LOI`.

---

## 2. API đang chạy

Tất cả đường dẫn dưới đây đã có trong `AdminController`. Phản hồi đợt và nhật ký là JSON đúng tên trường Java (camelCase).

### 2.1 Kiểm tra token

```
GET /api/v1/hemis/kiem-tra-token
```

Gọi máy chủ SSO, lấy token (hoặc dùng token còn hạn trong bộ nhớ).

```json
{
  "ketNoi": "thanh cong",
  "doDaiToken": 860,
  "trichYeu": "eyJhbGciOiJSUzI1NiIs..."
}
```

Lỗi kết nối trả về lỗi HTTP của Spring, không phải JSON trên. Không dán `trichYeu` vào phiếu sự cố gửi ra ngoài.

### 2.2 Tải danh mục dùng chung

```
POST /api/v1/hemis/danh-muc/tai-ve
```

Không có thân yêu cầu. Tải danh mục từ HEMIS (hoặc WireMock) và ghi vào `catalog_hemis`.

```json
{
  "success": true,
  "soDanhMuc": 3,
  "soBanGhiLuu": 35,
  "tenDanhMucDauTien": ["DM_DAN_TOC", "DM_GIOI_TINH", "DM_TINH"]
}
```

`tenDanhMucDauTien` chỉ là 20 tên đầu, đã sắp xếp, để nhìn nhanh. Không phải toàn bộ danh mục.

### 2.3 Chuẩn bị một đợt

```
POST /api/v1/hemis/dot/{ph}/chuan-bi
```

`ph` là mã phân hệ. Hiện chỉ có `COSOGIAODUC`. Mã khác trả về HTTP 500 với thông báo `Chua co bo trich xuat cho phan he ...`.

Ví dụ:

```bash
curl -X POST http://localhost:8080/api/v1/hemis/dot/COSOGIAODUC/chuan-bi
```

Thành công, đưa vào hàng đợi ký (`status` = `CHO_KY_SO`):

```json
{
  "id": 12,
  "ph": "COSOGIAODUC",
  "api": "db1",
  "iks": "8f3c2a10-1111-4222-8333-444455556666",
  "idKey": "a1b2c3d4-5555-4666-8777-888899990000",
  "donViId": "00000000-0000-0000-0000-000000000000",
  "recordCount": 1,
  "status": "CHO_KY_SO",
  "xmlPath": "./data/hemis-packages/COSOGIAODUC/8f3c2a10-1111-4222-8333-444455556666/payload.xml",
  "signedXmlPath": null,
  "jsonPath": "./data/hemis-packages/COSOGIAODUC/8f3c2a10-1111-4222-8333-444455556666/payload.json",
  "payloadSha256": "ab12...",
  "signerSubject": null,
  "signedAt": null,
  "sentAt": null,
  "message": null,
  "createdAt": "2026-11-01T19:40:00+07:00",
  "updatedAt": "2026-11-01T19:40:01+07:00"
}
```

Có lỗi mức chặn thì HTTP vẫn 200, `status` = `CHO_SUA_LOI`, `message` dạng `Có 4 lỗi BLOCK; cần sửa dữ liệu nguồn trước khi đóng gói`. Khi đó `xmlPath` và `jsonPath` là null. Danh sách từng lỗi nằm ở bảng `sync_error`, chưa có lệnh HTTP để đọc (mục 4).

### 2.4 Gửi đợt đã ký

```
POST /api/v1/hemis/dot/{id}/gui
```

Chỉ chạy khi `status` là `DA_KY_SO`. Trạng thái khác trả về HTTP 500, thông báo nêu trạng thái hiện tại.

Thứ tự cố định: nộp XML đã ký (db16), thành công thì gọi JSON của phân hệ (`db1` với Cơ sở giáo dục) với `t_k` bằng IKS. Xong thì `status` = `DA_GUI_JSON`, `sentAt` có giờ, `message` = `Gui thanh cong`.

Một trong hai bước lỗi: `status` = `THAT_BAI`, `message` bắt đầu bằng `db16 that bai:` hoặc `db1 that bai:`, và HTTP 500. Không gửi lại chính đợt đó. Tạo đợt mới sau khi xử lý nguyên nhân. Nếu db16 đã thành công mà db1 lỗi, IKS đó đã được HEMIS ghi nhận — việc gửi lại phải hỏi Cục KHCN&TT, không tự sinh IKS mới cho cùng một tệp đã nộp.

### 2.5 Danh sách đợt

```
GET /api/v1/hemis/dot?ph=COSOGIAODUC&limit=20
```

| Tham số | Mặc định      | Ý nghĩa                                         |
| ------- | ------------- | ----------------------------------------------- |
| `ph`    | `COSOGIAODUC` | Lọc một phân hệ. Không có tham số "mọi phân hệ" |
| `limit` | `20`          | Số đợt mới nhất                                 |

Trả về mảng đối tượng đợt, mới nhất trước. Màn danh sách dùng lệnh này.

### 2.6 Chi tiết một đợt

```
GET /api/v1/hemis/dot/{id}
```

Cùng một đối tượng đợt như mục 2.3. Không tìm thấy thì HTTP 500 (ngoại lệ của `orElseThrow()`, chưa có 404 riêng).

### 2.7 Nhật ký gọi API của một đợt

```
GET /api/v1/hemis/dot/{id}/nhat-ky
```

Mảng các lần gọi, cũ nhất trước. Mỗi phần tử:

| Trường         | Ý nghĩa                                                                       |
| -------------- | ----------------------------------------------------------------------------- |
| `id`           | Khóa nhật ký                                                                  |
| `batchId`      | Đợt                                                                           |
| `direction`    | Luôn `OUT` với các lệnh hiện tại                                              |
| `method`       | `POST`                                                                        |
| `url`          | `db16/COSOGIAODUC` hoặc `db1` — đây là tên bước, không phải URL đầy đủ của Bộ |
| `httpStatus`   | Thường null. Mã HTTP của Bộ chưa được ghi vào cột này                         |
| `success`      | `true` khi HEMIS trả `success: true`                                          |
| `requestBytes` | Kích thước XML ở bước db16; bước JSON hiện ghi 0                              |
| `durationMs`   | Thời gian gọi, mili giây                                                      |
| `responseBody` | Chuỗi ngắn `success=..., message=...`, cắt ở 2000 ký tự                       |
| `error`        | Thông báo khi gọi thất bại; null khi thành công                               |
| `createdAt`    | Giờ ghi                                                                       |

Đợt `CHO_SUA_LOI` hoặc `CHO_KY_SO` có thể có nhật ký rỗng: chưa gọi HEMIS. Lỗi kiểm tra dữ liệu không nằm ở đây. Chúng nằm ở danh sách lỗi.

---

## 3. Giao diện quản trị

Giai đoạn 1 đủ hai trang. Đặt trong cổng Next.js hiện có (`apps/portal`), một mục **Theo dõi đồng bộ HEMIS**. Chưa gắn SSO. Trang chỉ gọi API mục 2 và mục 4, không gọi `/internal/sign/**` (đường dẫn đó dành cho tác nhân ký số).

Máy người dùng không nói chuyện trực tiếp với HEMIS. Mọi nút đều đi qua `hemis-platform`.

### 3.1 Trang danh sách đợt

Mở trang là gọi `GET /api/v1/hemis/dot?ph=...&limit=20`.

Phần đầu trang:

- Ô chọn phân hệ. Hiện một giá trị `COSOGIAODUC` (Cơ sở giáo dục). Đổi phân hệ thì gọi lại danh sách.
- Nút **Làm mới**.
- Nút **Chuẩn bị đợt**. Gọi `POST /api/v1/hemis/dot/{ph}/chuan-bi`, rồi mở trang chi tiết của `id` vừa trả về.
- Nút **Tải danh mục** gọi `POST /api/v1/hemis/danh-muc/tai-ve` và hiện `soDanhMuc`, `soBanGhiLuu`. Để ở cuối trang hoặc menu phụ, không đặt cạnh nút Gửi.

Bảng, mỗi dòng một đợt, bấm dòng để vào chi tiết:

| Cột        | Trường        | Cách hiện                        |
| ---------- | ------------- | -------------------------------- |
| Mã đợt     | `id`          | Số                               |
| Phân hệ    | `ph`          | Chữ                              |
| Trạng thái | `status`      | Nhãn tiếng Việt ở bảng dưới      |
| Số bản ghi | `recordCount` | Số                               |
| Tạo lúc    | `createdAt`   | `dd/MM/yyyy HH:mm`, giờ Việt Nam |
| Gửi lúc    | `sentAt`      | Trống nếu chưa gửi               |
| Thông báo  | `message`     | Một dòng, cắt nếu dài            |

Nhãn trạng thái:

| `status`      | Nhãn            | Màu gợi ý  |
| ------------- | --------------- | ---------- |
| `KHOI_TAO`    | Khởi tạo        | trung tính |
| `DA_DONG_GOI` | Đã đóng gói     | trung tính |
| `CHO_SUA_LOI` | Chờ sửa dữ liệu | đỏ         |
| `CHO_KY_SO`   | Chờ ký số       | vàng       |
| `DA_KY_SO`    | Đã ký số        | xanh dương |
| `DA_GUI_XML`  | Đã nộp XML      | xanh dương |
| `DA_GUI_JSON` | Đã gửi          | xanh lá    |
| `DA_DOI_SOAT` | Đã đối soát     | xanh lá    |
| `THAT_BAI`    | Thất bại        | đỏ         |

Trạng thái rỗng: chưa có đợt thì hiện "Chưa có đợt đồng bộ cho phân hệ này" và vẫn để nút Chuẩn bị đợt.

### 3.2 Trang chi tiết một đợt

Gọi song song khi mở trang:

1. `GET /api/v1/hemis/dot/{id}`
2. `GET /api/v1/hemis/dot/{id}/nhat-ky`
3. `GET /api/v1/hemis/dot/{id}/loi` — hợp đồng ở mục 4, mã chưa có

Phần đầu: mã đợt, nhãn trạng thái, `message`.

Khối phiên, chỉ đọc, có nút sao chép:

| Nhãn                    | Trường          |
| ----------------------- | --------------- |
| IKS (phiên ký số)       | `iks`           |
| IdKey (phiên đồng bộ)   | `idKey`         |
| Mã đơn vị               | `donViId`       |
| API JSON                | `api`           |
| SHA-256 tệp XML chưa ký | `payloadSha256` |
| Người ký                | `signerSubject` |
| Ký lúc                  | `signedAt`      |

Nút hành động, chỉ một nút chính tùy trạng thái:

| Trạng thái    | Nút               | Gọi                                                             |
| ------------- | ----------------- | --------------------------------------------------------------- |
| `CHO_SUA_LOI` | không có nút Gửi  | Hiện dòng: sửa dữ liệu theo danh sách lỗi, rồi chuẩn bị đợt mới |
| `CHO_KY_SO`   | không có nút Gửi  | Hiện dòng: đợt đang chờ trạm ký số                              |
| `DA_KY_SO`    | **Gửi lên HEMIS** | `POST /api/v1/hemis/dot/{id}/gui`, xong thì tải lại chi tiết    |
| `DA_GUI_JSON` | không gửi lại     | Hiện dòng: đối soát trên cổng HEMIS trong 03 ngày làm việc      |
| `THAT_BAI`    | không gửi lại     | Hiện `message`; người vận hành tạo đợt mới từ trang danh sách   |

Khối tệp, khi `xmlPath` khác null:

| Tệp         | Đường dẫn trên máy chủ | Lệnh tải (mục 4, chưa có mã) |
| ----------- | ---------------------- | ---------------------------- |
| XML chưa ký | `xmlPath`              | `GET .../tep/xml`            |
| JSON        | `jsonPath`             | `GET .../tep/json`           |
| XML đã ký   | `signedXmlPath`        | `GET .../tep/signed`         |

Chưa có lệnh tải thì hiện đường dẫn chữ, không bịa liên kết.

Khối **Nhật ký gọi HEMIS**: bảng từ mục 2.7. Cột: thời điểm, bước (`url`), kết quả (`success`), thời gian (`durationMs`), lỗi (`error`), trích phản hồi (`responseBody`). Nhật ký rỗng thì ghi "Đợt chưa gọi HEMIS".

Khối **Danh sách lỗi**: bảng từ mục 4. Đặt phía trên nhật ký khi `status` là `CHO_SUA_LOI`, vì đó là việc phải làm trước.

### 3.3 Danh sách lỗi trên trang chi tiết

Mỗi dòng là một vi phạm của một trường trên một bản ghi. Không gộp nhiều trường vào một dòng.

| Cột          | Trường      | Cách hiện                                                           |
| ------------ | ----------- | ------------------------------------------------------------------- |
| Mức          | `severity`  | `BLOCK` → "Chặn", `WARN` → "Cảnh báo"                               |
| Mảng dữ liệu | `entity`    | Giữ nguyên tên của Bộ, ví dụ `_CO_SO_GIAO_DUC`                      |
| Bản ghi      | `localId`   | Mã bản ghi nội bộ hoặc GUID. Trống thì để trống, không ghi "null"   |
| Trường       | `field`     | Tên trường JSON, ví dụ `WEBSITE`                                    |
| Quy tắc      | `ruleCode`  | Nhãn ở bảng dưới                                                    |
| Mô tả        | `message`   | Nguyên văn                                                          |
| Đơn vị       | `ownerUnit` | Trống nếu chưa gán. Cột này có trong bảng, mã hiện chưa ghi giá trị |
| Đã xử lý     | `resolved`  | "Chưa" / "Rồi". Chưa có lệnh đánh dấu đã xử lý                      |

| `ruleCode`    | Nhãn                                 |
| ------------- | ------------------------------------ |
| `REQUIRED`    | Thiếu trường bắt buộc                |
| `CONDITIONAL` | Thiếu trường bắt buộc theo điều kiện |
| `MAX_LENGTH`  | Vượt độ dài                          |
| `DATA_TYPE`   | Sai kiểu                             |
| `FORMAT`      | Sai định dạng                        |
| `CATALOG`     | Mã danh mục chưa ánh xạ              |
| `MISSING`     | Thiếu dữ liệu theo quy tắc           |

Bộ lọc trên bảng: Tất cả / Chỉ lỗi chặn / Chỉ cảnh báo. Lọc trên dữ liệu đã tải, không cần gọi lại API.

Không có dòng lỗi thì hiện "Không có lỗi kiểm tra". Đợt thất bại vì HEMIS từ chối vẫn có thể không có dòng ở đây: nguyên nhân nằm ở nhật ký và `message`, không nằm ở `sync_error`.

### 3.4 Việc màn hình không làm

- Không nhập mã PIN, không gọi plugin ký số. Ký số là việc của trạm ký và tác nhân.
- Không sửa dữ liệu nguồn. Người quản lý dữ liệu sửa ở phân hệ nghiệp vụ, rồi cán bộ kỹ thuật chuẩn bị đợt mới.
- Không nút "gửi lại" trên một đợt `THAT_BAI` hoặc `DA_GUI_XML`.
- Không hiện `client_secret`, mật khẩu, mã PIN, số căn cước.

---

## 4. Hợp đồng API còn thiếu để giao diện đủ

Hai lệnh này đã được chốt trong FR-ADM-01 mức Should. Mã chưa có. Giao diện mục 3 gọi đúng đường dẫn và dạng JSON dưới đây. Khi bổ sung mã, không đổi tên trường.

### 4.1 Danh sách lỗi của một đợt

```
GET /api/v1/hemis/dot/{id}/loi
```

Đợt không tồn tại: HTTP 404, thân `{"message": "Không tìm thấy đợt"}`.

Đợt tồn tại, kể cả khi không có lỗi: HTTP 200 và mảng, có thể rỗng.

```json
[
  {
    "id": 3,
    "batchId": 12,
    "entity": "_CO_SO_GIAO_DUC",
    "localId": "00000000-0000-0000-0000-000000000000",
    "field": "WEBSITE",
    "ruleCode": "REQUIRED",
    "severity": "BLOCK",
    "message": "Trường bắt buộc không được rỗng",
    "ownerUnit": null,
    "resolved": false
  }
]
```

Nguồn: bảng `sync_error`, lọc `batch_id`, sắp `severity` (BLOCK trước WARN) rồi `entity`, `field`.

Cho đến khi lệnh này có, người vận hành đọc lỗi bằng SQL:

```sql
SELECT severity, entity, local_id, field, rule_code, message
FROM hemis_sync.sync_error
WHERE batch_id = 12
ORDER BY severity, entity, field;
```

### 4.2 Tải tệp của một đợt

```
GET /api/v1/hemis/dot/{id}/tep/{loai}
```

`loai` chỉ nhận `xml`, `json`, `signed`. Giá trị khác: HTTP 400.

| `loai`   | Tệp             | Khi chưa có đường dẫn |
| -------- | --------------- | --------------------- |
| `xml`    | `xmlPath`       | HTTP 404              |
| `json`   | `jsonPath`      | HTTP 404              |
| `signed` | `signedXmlPath` | HTTP 404              |

Phản hồi là nội dung tệp, `Content-Type: application/xml` hoặc `application/json`, `Content-Disposition: attachment`. Không trả về đường dẫn đĩa. Không trả về tệp của đợt khác.

---

## 5. Trình tự vận hành một đợt Cơ sở giáo dục

1. `GET /api/v1/hemis/kiem-tra-token` — phải ra `ketNoi = thanh cong`.
2. `POST /api/v1/hemis/danh-muc/tai-ve` — khi danh mục trên HEMIS đổi, hoặc lần đầu trong ngày gửi.
3. `POST /api/v1/hemis/dot/COSOGIAODUC/chuan-bi`.
4. Nếu `CHO_SUA_LOI`: đọc danh sách lỗi, sửa dữ liệu, quay lại bước 3. Đợt cũ để nguyên.
5. Nếu `CHO_KY_SO`: chờ tác nhân ký số. Xong thì chi tiết đợt chuyển `DA_KY_SO`.
6. `POST /api/v1/hemis/dot/{id}/gui`.
7. `DA_GUI_JSON`: mở nhật ký, lưu lại IKS và IdKey để đối soát trên cổng HEMIS trong 03 ngày làm việc.

Kiểm tra nhanh bằng curl, đúng phương thức đang có trong mã (`kiem-tra-token` là GET):

```bash
curl http://localhost:8080/api/v1/hemis/kiem-tra-token
curl -X POST http://localhost:8080/api/v1/hemis/danh-muc/tai-ve
curl -X POST http://localhost:8080/api/v1/hemis/dot/COSOGIAODUC/chuan-bi
curl http://localhost:8080/api/v1/hemis/dot?ph=COSOGIAODUC
curl http://localhost:8080/api/v1/hemis/dot/12
curl http://localhost:8080/api/v1/hemis/dot/12/nhat-ky
```

Thay `12` bằng `id` của đợt vừa chuẩn bị. Lệnh gửi chỉ gọi sau khi đợt đã `DA_KY_SO`.
