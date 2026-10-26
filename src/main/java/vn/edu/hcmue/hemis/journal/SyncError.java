package vn.edu.hcmue.hemis.journal;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "sync_error")
@Getter
@Setter
public class SyncError {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "batch_id")
    private Long batchId;

    @Column(length = 100)
    private String entity;

    @Column(name = "local_id", length = 100)
    private String localId;

    @Column(length = 100)
    private String field;

    @Column(name = "rule_code", length = 50)
    private String ruleCode;

    @Column(nullable = false, length = 20)
    private String severity;

    @Column(nullable = false, columnDefinition = "text")
    private String message;

    @Column(name = "owner_unit", length = 100)
    private String ownerUnit;

    @Column(nullable = false)
    private boolean resolved = false;
}
