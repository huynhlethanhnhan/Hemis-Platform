package vn.edu.hcmue.hemis.journal;

import java.time.OffsetDateTime;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "catalog_hemis")
@Getter
@Setter
public class CatalogHemis {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "dm_name", nullable = false, length = 100)
    private String dmName;

    @Column(name = "hemis_id", length = 36)
    private String hemisId;

    @Column(name = "code", length = 100)
    private String code;

    @Column(name = "ma", length = 100)
    private String ma;

    @Column(name = "ten", length = 500)
    private String ten;

    @Column(name = "is_public")
    private Boolean isPublic;

    @Column(name = "is_deleted", nullable = false)
    private Boolean isDeleted = false;

    /** Thoi diem Modified tu API HEMIS (dung de so sanh thay doi). */
    @Column(name = "modified")
    private OffsetDateTime modified;

    @Column(name = "fetched_at", nullable = false)
    private OffsetDateTime fetchedAt;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "raw_json", columnDefinition = "jsonb")
    private String rawJson;

    @PrePersist
    void onCreate() {
        OffsetDateTime now = OffsetDateTime.now();
        this.fetchedAt = now;
        if (this.isDeleted == null) {
            this.isDeleted = false;
        }
    }

    @PreUpdate
    void onUpdate() {
        this.fetchedAt = OffsetDateTime.now();
    }
}
