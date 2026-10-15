package vn.edu.hcmue.hemis.signing;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * Mot viec ky so trong hang doi.
 *
 * <p>Vi plugin XmlSignerTriNam chi lang nghe tai {@code 127.0.0.1:64005} tren chinh may
 * cai dat, cong tich hop KHONG the goi truc tiep. Thay vao do, tac nhan ky so chay tren
 * tram ky so se KEO viec tu bang nay (qua API noi bo), ky bang USB token, roi tra ket qua ve.
 *
 * <p>Co che keo nay co hai loi diem: khong phai mo cong vao tram ky so, va tram ky so
 * co the nam sau NAT hoac tat may ma khong lam hong cong tich hop.
 */
@Entity
@Table(name = "sign_job")
@Getter
@Setter
public class SignJob {

    public enum Status {
        /** Dang cho tac nhan lay */
        PENDING,
        /** Da duoc mot tac nhan nhan, dang ky */
        LEASED,
        /** Da ky xong */
        SIGNED,
        /** Ky that bai */
        FAILED
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "batch_id", nullable = false)
    private Long batchId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Status status = Status.PENDING;

    @Column(name = "xml_path", nullable = false, length = 500)
    private String xmlPath;

    @Column(name = "signed_path", length = 500)
    private String signedPath;

    @Column(name = "leased_by", length = 100)
    private String leasedBy;

    @Column(name = "leased_at")
    private OffsetDateTime leasedAt;

    @Column(nullable = false)
    private int attempts;

    @Column(columnDefinition = "text")
    private String error;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @PrePersist
    void onCreate() {
        OffsetDateTime now = OffsetDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
    }

    @PreUpdate
    void onUpdate() {
        this.updatedAt = OffsetDateTime.now();
    }
}
