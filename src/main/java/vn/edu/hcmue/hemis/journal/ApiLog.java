package vn.edu.hcmue.hemis.journal;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * Nhat ky tung lan goi API cua Bo - bat buoc theo Cong van huong dan ket noi
 * ("co che ghi nhan nhat ky ket noi, theo doi trang thai dong bo va luu thong tin loi").
 *
 * <p>KHONG ghi so CCCD, ho ten day du hay bat ky du lieu ca nhan nao vao bang nay.
 * Truong {@code responseBody} phai duoc cat ngan va che truoc khi luu.
 */
@Entity
@Table(name = "api_log")
@Getter
@Setter
public class ApiLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "batch_id")
    private Long batchId;

    @Column(nullable = false, length = 10)
    private String direction = "OUT";

    @Column(nullable = false, length = 10)
    private String method;

    @Column(nullable = false, length = 1000)
    private String url;

    @Column(name = "http_status")
    private Integer httpStatus;

    private Boolean success;

    @Column(name = "request_bytes")
    private Long requestBytes;

    @Column(name = "duration_ms")
    private Long durationMs;

    @Column(name = "response_body", columnDefinition = "text")
    private String responseBody;

    @Column(columnDefinition = "text")
    private String error;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    void onCreate() {
        this.createdAt = OffsetDateTime.now();
    }

    /** Cat ngan phan hoi truoc khi luu de nhat ky khong phinh to. */
    public void setResponseBodyTruncated(String body, int max) {
        if (body == null) {
            this.responseBody = null;
        } else {
            this.responseBody = body.length() <= max ? body : body.substring(0, max) + "...(cat)";
        }
    }
}
