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
@Table(name = "validation_rule")
@Getter
@Setter
public class ValidationRule {
	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;

	@Column(name = "ph", nullable = false, length = 50)
	private String ph;

	@Column(name = "entity", nullable = false, length = 100)
	private String entity;

	@Column(name = "field", nullable = false, length = 100)
	private String field;

	@Column(name = "required", nullable = false)
	private Boolean required = false;

	@Column(name = "max_length")
	private int maxLength;

	@Column(name = "data_type", length = 30)
	private String dataType;

	@Column(name = "catalog_name", length = 100)
	private String catalogName;

	@Column(name = "condition_expr", length = 500)
	private String conditionExpr;

	@Column(name = "note", length = 500)
	private String note;
}
