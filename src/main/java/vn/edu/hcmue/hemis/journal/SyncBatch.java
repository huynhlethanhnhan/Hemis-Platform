package vn.edu.hcmue.hemis.journal;

import java.time.OffsetDateTime;
import java.util.UUID;

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
 * Mot dot dong bo mot phan he len HEMIS.
 *
 * <p>Day la ban ghi trung tam de tra cuu khi doi soat: giu IKS (ma phien ky so),
 * IdKey (ma phien dong bo), duong dan cac tep da gui va trang thai.
 */
@Entity
@Table(name = "sync_batch")
@Getter
@Setter
public class SyncBatch {

    public enum Status {
        /** Moi tao, chua trich xuat */
        KHOI_TAO,
        /** Da trich xuat va dong goi XML/JSON */
        DA_DONG_GOI,
        /** Co loi muc chan, cho don vi xu ly du lieu nguon */
        CHO_SUA_LOI,
        /** Dang cho ky so */
        CHO_KY_SO,
        /** Da ky so va tu xac minh dat */
        DA_KY_SO,
        /** Da nop tep XML (db16) thanh cong */
        DA_GUI_XML,
        /** Da goi API JSON (dbN) thanh cong - hoan tat gui */
        DA_GUI_JSON,
        /** Da doi soat tren HEMIS */
        DA_DOI_SOAT,
        /** That bai */
        THAT_BAI
    }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Phan he: COSOGIAODUC, CANBO, HOCVIEN... */
    @Column(nullable = false, length = 50)
    private String ph;

    /** Ma API JSON tuong ung: db1, db3, db7... */
    @Column(nullable = false, length = 10)
    private String api;

    /** Ma phien ky so - duy nhat, khong sinh lai khi thu lai */
    @Column(nullable = false, unique = true)
    private UUID iks;

    /** Ma phien dong bo - dung tra cuu nhat ky tren HEMIS */
    @Column(name = "id_key", nullable = false)
    private UUID idKey;

    @Column(name = "don_vi_id", nullable = false)
    private UUID donViId;

    @Column(name = "record_count", nullable = false)
    private int recordCount;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private Status status = Status.KHOI_TAO;

    @Column(name = "xml_path", length = 500)
    private String xmlPath;

    @Column(name = "signed_xml_path", length = 500)
    private String signedXmlPath;

    @Column(name = "json_path", length = 500)
    private String jsonPath;

    @Column(name = "payload_sha256", length = 64)
    private String payloadSha256;

    @Column(name = "signer_subject", length = 500)
    private String signerSubject;

    @Column(name = "signed_at")
    private OffsetDateTime signedAt;

    @Column(name = "sent_at")
    private OffsetDateTime sentAt;

    @Column(columnDefinition = "text")
    private String message;

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
