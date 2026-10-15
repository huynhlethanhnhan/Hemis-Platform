# 05. Dựng môi trường phát triển

Mục tiêu: sau 30 phút, máy bạn chạy được dự án và gọi được API mô phỏng.

---

## 1. Cần cài gì

| Phần mềm | Phiên bản | Ghi chú |
| --- | --- | --- |
| JDK | 21 (LTS) | Temurin/Adoptium hoặc bản của Oracle |
| Docker Desktop | mới nhất | Chạy PostgreSQL và WireMock |
| Git | mới nhất | |
| IntelliJ IDEA Community hoặc VS Code | | Không bắt buộc |

**Không cần cài Maven** — dự án có sẵn `mvnw` (Maven Wrapper), tự tải Maven đúng phiên bản.

Kiểm tra:

```bash
java -version      # phải là 21.x
docker --version
git --version
```

---

## 2. Lấy mã nguồn và chạy

```bash
cd D:/Data/Project/HEMIS/hemis-platform

# 1. Bật PostgreSQL và WireMock
docker compose up -d
docker compose ps        # cả hai phải ở trạng thái running/healthy

# 2. Tạo cấu hình riêng
cp .env.example .env     # Windows: copy .env.example .env

# 3. Chạy
./mvnw spring-boot:run   # Windows: mvnw.cmd spring-boot:run
```

Lần chạy đầu tải thư viện, mất vài phút. Khi thấy dòng
`Started HemisPlatformApplication in ... seconds` là xong.

Kiểm tra nhanh:

```bash
curl http://localhost:8080/actuator/health
# {"status":"UP"}
```

---

## 3. Thử toàn bộ luồng với API mô phỏng

WireMock ở cổng 8089 đóng vai API của Bộ. Cấu hình mặc định trong `.env.example` đã trỏ sang đó,
nên chạy được ngay cả khi **chưa có tài khoản của Bộ**.

```bash
# 1. Lấy token
curl -X POST http://localhost:8080/api/v1/hemis/kiem-tra-token

# 2. Tải danh mục dùng chung
curl -X POST http://localhost:8080/api/v1/hemis/danh-muc/tai-ve

# 3. Chuẩn bị một đợt đồng bộ
curl -X POST http://localhost:8080/api/v1/hemis/dot/COSOGIAODUC/chuan-bi
```

Lệnh 3 trả về một `SyncBatch` ở trạng thái `CHO_KY_SO`. Mở tệp vừa sinh:

```bash
ls data/hemis-packages/COSOGIAODUC/
cat data/hemis-packages/COSOGIAODUC/<IKS>/payload.xml
```

Tự kiểm tra: `k1` có phải node đầu tiên? `k2` có phải node cuối cùng?
Ghép `k1 + k2` có ra đúng tên thư mục `<IKS>` không?

---

## 4. Giả lập bước ký số (khi chưa có USB token)

Trong lúc chờ chứng thư số, có thể giả lập tác nhân ký số để chạy hết luồng:

```bash
TOKEN=$(grep HEMIS_AGENT_TOKEN .env | cut -d= -f2)

# 1. Xem việc đang chờ ký
curl -H "X-Agent-Token: $TOKEN" http://localhost:8080/internal/sign/jobs

# 2. Nhận việc (thay <id>)
curl -X POST -H "X-Agent-Token: $TOKEN" \
  http://localhost:8080/internal/sign/jobs/<id>/lease
```

Trả kết quả ký thì cần một tệp XML **đã ký thật**. Khi `hemis.signing.verify-before-send`
đang bật (mặc định), tệp giả sẽ bị từ chối — đúng như thiết kế. Để chạy thử hết luồng,
tạm đặt trong `.env`:

```
HEMIS_SIGNING_VERIFY_BEFORE_SEND=false
```

> Chỉ làm trên máy cá nhân. **Không bao giờ tắt kiểm tra này trên máy chủ.**

---

## 5. Kiểm thử

```bash
./mvnw test                                   # test đơn vị, không cần Docker
./mvnw test -Dtest=XmlPackagerTest            # một lớp
```

Test `HemisPlatformApplicationTests` đang bị `@Disabled` vì cần Docker. Khi Docker đã chạy,
bỏ dòng `@Disabled` để kiểm tra Flyway tạo schema đúng.

---

## 6. Xem cơ sở dữ liệu

```bash
docker exec -it hemis-postgres psql -U hemis -d hemis

\dn                                  -- liệt kê schema, phải thấy hemis_sync
\dt hemis_sync.*                     -- liệt kê bảng
select id, ph, iks, status from hemis_sync.sync_batch order by id desc limit 10;
select * from hemis_sync.api_log order by id desc limit 10;
```

---

## 7. Chuyển sang môi trường thử nghiệm thật của Bộ

Khi đã được cấp tài khoản, sửa `.env`:

```
HEMIS_SSO_URL=https://<ten-mien-sso-do-Bo-cap>
HEMIS_GATEWAY_URL=https://hemis-test.moet.gov.vn/gwdev
HEMIS_CLIENT_SECRET=<do Bộ cấp>
HEMIS_USERNAME=<do Bộ cấp>
HEMIS_PASSWORD=<do Bộ cấp>
HEMIS_DON_VI_ID=<Guid do Bộ cấp>
HEMIS_MA_DON_VI=<mã đơn vị trên HEMIS>
```

Kiểm tra mạng ra Internet trước:

```bash
curl -I https://hemis-test.moet.gov.vn/
curl -I https://hemis-cms.moet.gov.vn/
```

Nếu không thông, liên hệ bộ phận mạng mở luồng ra hai tên miền này
(xem Phương án kỹ thuật GĐ1, mục II.5).

---

## 8. Sự cố hay gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| `Non-resolvable parent POM` | Máy chặn Maven Central. Kiểm tra proxy, hoặc cấu hình `~/.m2/settings.xml` |
| `Connection refused: localhost:5432` | `docker compose up -d` chưa chạy, hoặc PostgreSQL khác đang chiếm cổng 5432 |
| `FlywayValidateException` | Đã sửa tệp migration cũ. Trong môi trường phát triển: `docker compose down -v` rồi dựng lại |
| Ứng dụng khởi động rồi tắt ngay | Xem dòng `Caused by` đầu tiên trong nhật ký, thường là sai cấu hình `.env` |
| WireMock không phản hồi | `docker compose logs wiremock`; kiểm tra tệp trong `wiremock/mappings/` đúng JSON |
| Tiếng Việt hiển thị sai trong console Windows | `chcp 65001` trước khi chạy |

---

## 9. Thư mục dữ liệu sinh ra

```
data/hemis-packages/<PH>/<IKS>/
  ├── payload.xml           XML chưa ký
  ├── payload.signed.xml    XML đã ký  ← lưu 05 năm, chỉ đọc
  └── payload.json          thân JSON gửi dbN
```

Thư mục `data/` đã nằm trong `.gitignore`. Trên máy chủ, thư mục này phải được sao lưu
và đặt quyền chỉ đọc sau khi ghi.
