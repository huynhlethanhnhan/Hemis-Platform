package vn.edu.hcmue.hemis.journal;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * Anh xa ma danh muc noi bo sang ma HEMIS. Khong co dong, hoac hemis_code rong,
 * la loi muc chan MISSING khi kiem tra CATALOG.
 */
@Entity
@Table(name = "catalog_map")
@Getter
@Setter
public class CatalogMap {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "dm_name", nullable = false, length = 100)
    private String dmName;

    @Column(name = "local_code", nullable = false, length = 100)
    private String localCode;

    @Column(name = "hemis_code", length = 100)
    private String hemisCode;

    @Column(length = 500)
    private String note;

    @Column(nullable = false, length = 20)
    private String strategy = "IDENTITY";

    @Column(name = "dwh_table", length = 100)
    private String dwhTable;
}
