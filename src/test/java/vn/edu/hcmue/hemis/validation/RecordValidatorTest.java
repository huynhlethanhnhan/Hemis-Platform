package vn.edu.hcmue.hemis.validation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Consumer;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import vn.edu.hcmue.hemis.journal.CatalogMap;
import vn.edu.hcmue.hemis.journal.CatalogMapRepository;
import vn.edu.hcmue.hemis.journal.ValidationRule;

/**
 * FR-VAL-02: moi loai quy tac co it nhat mot ca dat va mot ca truot.
 * Quy tac duoc nap qua ValidationRule (FR-VAL-01), khong hard-code trong may kiem tra.
 */
class RecordValidatorTest {

    private CatalogMapRepository catalogMaps;
    private RecordValidator validator;

    @BeforeEach
    void setUp() {
        catalogMaps = mock(CatalogMapRepository.class);
        validator = new RecordValidator(catalogMaps);
    }

    @Test
    @DisplayName("REQUIRED đạt khi trường bắt buộc có giá trị")
    void requiredPass() {
        List<RecordValidator.Violation> violations = validator.validate(
                "csgd-1",
                List.of(rule("MA_DON_VI", r -> r.setRequired(true))),
                Map.of("MA_DON_VI", "HCMUE"));

        assertThat(violations).isEmpty();
    }

    @Test
    @DisplayName("REQUIRED trượt khi trường bắt buộc rỗng")
    void requiredFail() {
        List<RecordValidator.Violation> violations = validator.validate(
                "csgd-1",
                List.of(rule("MA_DON_VI", r -> r.setRequired(true))),
                Map.of("MA_DON_VI", "  "));

        assertThat(violations).singleElement().satisfies(v -> {
            assertThat(v.ruleCode()).isEqualTo(RecordValidator.REQUIRED);
            assertThat(v.severity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
            assertThat(v.field()).isEqualTo("MA_DON_VI");
            assertThat(v.localId()).isEqualTo("csgd-1");
            assertThat(v.message()).contains("csgd-1").contains("MA_DON_VI").contains("REQUIRED");
        });
    }

    @Test
    @DisplayName("MAX_LENGTH đạt khi độ dài không vượt đặc tả")
    void maxLengthPass() {
        List<RecordValidator.Violation> violations = validator.validate(
                "csgd-1",
                List.of(rule("MA_DON_VI", r -> r.setMaxLength(50))),
                Map.of("MA_DON_VI", "HCMUE"));

        assertThat(violations).isEmpty();
    }

    @Test
    @DisplayName("MAX_LENGTH trượt khi độ dài vượt đặc tả")
    void maxLengthFail() {
        List<RecordValidator.Violation> violations = validator.validate(
                "csgd-1",
                List.of(rule("MA_DON_VI", r -> r.setMaxLength(5))),
                Map.of("MA_DON_VI", "HCMUE-XX"));

        assertThat(violations).singleElement().satisfies(v -> {
            assertThat(v.ruleCode()).isEqualTo(RecordValidator.MAX_LENGTH);
            assertThat(v.severity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
        });
    }

    @Test
    @DisplayName("DATA_TYPE đạt với string, int, double, date, bool, guid hợp lệ")
    void dataTypePass() {
        List<ValidationRule> rules = List.of(
                typed("TEN", "string"),
                typed("SO_GV_GDTC", "int"),
                typed("DIEM", "double"),
                typed("NGAY_QD_THANH_LAP", "date"),
                typed("TU_CHU", "bool"),
                typed("Id", "guid"));
        Map<String, Object> record = new HashMap<>();
        record.put("TEN", "HCMUE");
        record.put("SO_GV_GDTC", 12);
        record.put("DIEM", "3.14");
        record.put("NGAY_QD_THANH_LAP", LocalDate.of(1976, 10, 27));
        record.put("TU_CHU", true);
        record.put("Id", UUID.fromString("11111111-2222-3333-4444-555555555555"));

        assertThat(validator.validate("csgd-1", rules, record)).isEmpty();
    }

    @Test
    @DisplayName("DATA_TYPE trượt khi giá trị sai kiểu")
    void dataTypeFail() {
        List<RecordValidator.Violation> violations = validator.validate(
                "csgd-1",
                List.of(typed("SO_GV_GDTC", "int")),
                Map.of("SO_GV_GDTC", "muoi-hai"));

        assertThat(violations).singleElement().satisfies(v -> {
            assertThat(v.ruleCode()).isEqualTo(RecordValidator.DATA_TYPE);
            assertThat(v.severity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
        });
    }

    @Test
    @DisplayName("CATALOG đạt khi mã có trong catalog_map và đã có hemis_code")
    void catalogPass() {
        CatalogMap mapped = new CatalogMap();
        mapped.setDmName("DM_LOAI_HINH_TRUONG");
        mapped.setLocalCode("01");
        mapped.setHemisCode("01");
        mapped.setStrategy("IDENTITY");
        when(catalogMaps.findByDmNameAndLocalCode("DM_LOAI_HINH_TRUONG", "01"))
                .thenReturn(Optional.of(mapped));

        List<RecordValidator.Violation> violations = validator.validate(
                "csgd-1",
                List.of(rule("LOAI_HINH_ID", r -> r.setCatalogName("DM_LOAI_HINH_TRUONG"))),
                Map.of("LOAI_HINH_ID", "01"));

        assertThat(violations).isEmpty();
    }

    @Test
    @DisplayName("CATALOG trượt với MISSING khi mã chưa ánh xạ hoặc hemis_code rỗng")
    void catalogFailMissing() {
        when(catalogMaps.findByDmNameAndLocalCode("DM_LOAI_HINH_TRUONG", "99"))
                .thenReturn(Optional.empty());
        CatalogMap unmapped = new CatalogMap();
        unmapped.setDmName("DM_LOAI_HINH_TRUONG");
        unmapped.setLocalCode("00");
        unmapped.setHemisCode(null);
        unmapped.setStrategy("MAPPED");
        when(catalogMaps.findByDmNameAndLocalCode("DM_LOAI_HINH_TRUONG", "00"))
                .thenReturn(Optional.of(unmapped));

        List<RecordValidator.Violation> absent = validator.validate(
                "csgd-1",
                List.of(rule("LOAI_HINH_ID", r -> r.setCatalogName("DM_LOAI_HINH_TRUONG"))),
                Map.of("LOAI_HINH_ID", "99"));
        List<RecordValidator.Violation> nullCode = validator.validate(
                "csgd-1",
                List.of(rule("LOAI_HINH_ID", r -> r.setCatalogName("DM_LOAI_HINH_TRUONG"))),
                Map.of("LOAI_HINH_ID", "00"));

        assertThat(absent).singleElement().satisfies(v -> {
            assertThat(v.ruleCode()).isEqualTo(RecordValidator.MISSING);
            assertThat(v.severity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
        });
        assertThat(nullCode).singleElement().extracting(RecordValidator.Violation::ruleCode)
                .isEqualTo(RecordValidator.MISSING);
    }

    @Test
    @DisplayName("CONDITIONAL đạt khi TRANG_THAI_ID = '04' và đã có SO_QD_TOT_NGHIEP")
    void conditionalPass() {
        List<RecordValidator.Violation> violations = validator.validate(
                "hv-1",
                List.of(rule("SO_QD_TOT_NGHIEP", r -> r.setConditionExpr("TRANG_THAI_ID = '04'"))),
                Map.of("TRANG_THAI_ID", "04", "SO_QD_TOT_NGHIEP", "QD-123"));

        assertThat(violations).isEmpty();
    }

    @Test
    @DisplayName("CONDITIONAL trượt khi TRANG_THAI_ID = '04' nhưng thiếu SO_QD_TOT_NGHIEP")
    void conditionalFail() {
        List<RecordValidator.Violation> violations = validator.validate(
                "hv-1",
                List.of(rule("SO_QD_TOT_NGHIEP", r -> r.setConditionExpr("TRANG_THAI_ID = '04'"))),
                Map.of("TRANG_THAI_ID", "04"));

        assertThat(violations).singleElement().satisfies(v -> {
            assertThat(v.ruleCode()).isEqualTo(RecordValidator.CONDITIONAL);
            assertThat(v.field()).isEqualTo("SO_QD_TOT_NGHIEP");
            assertThat(v.severity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
            assertThat(v.message()).contains("hv-1").contains("SO_QD_TOT_NGHIEP");
        });
    }

    @Test
    @DisplayName("CONDITIONAL không bắt buộc SO_QD_TOT_NGHIEP khi TRANG_THAI_ID khác '04'")
    void conditionalSkippedWhenPredicateFalse() {
        List<RecordValidator.Violation> violations = validator.validate(
                "hv-1",
                List.of(rule("SO_QD_TOT_NGHIEP", r -> r.setConditionExpr("TRANG_THAI_ID = '04'"))),
                Map.of("TRANG_THAI_ID", "01"));

        assertThat(violations).isEmpty();
    }

    @Test
    @DisplayName("FORMAT đạt với email và CCCD đúng định dạng")
    void formatPass() {
        List<RecordValidator.Violation> violations = validator.validate(
                "cb-1",
                List.of(rule("EMAIL"), rule("SO_CCCD")),
                Map.of("EMAIL", "lienhe@hcmue.edu.vn", "SO_CCCD", "079012345678"));

        assertThat(violations).isEmpty();
    }

    @Test
    @DisplayName("FORMAT trượt mức cảnh báo khi email hoặc CCCD sai định dạng")
    void formatFail() {
        List<RecordValidator.Violation> violations = validator.validate(
                "cb-1",
                List.of(rule("EMAIL"), rule("SO_CCCD")),
                Map.of("EMAIL", "khong-phai-email", "SO_CCCD", "123"));

        assertThat(violations).hasSize(2);
        assertThat(violations).allSatisfy(v -> {
            assertThat(v.ruleCode()).isEqualTo(RecordValidator.FORMAT);
            assertThat(v.severity()).isEqualTo(RecordValidator.SEVERITY_WARN);
        });
    }

    @Test
    @DisplayName("FR-VAL-01: thêm quy tắc YAML-shaped không cần sửa máy kiểm tra")
    void newRuleDoesNotRequireCodeChange() {
        ValidationRule extra = rule("MA_MOI", r -> {
            r.setRequired(true);
            r.setMaxLength(4);
            r.setDataType("string");
        });

        assertThat(validator.validate("x-1", List.of(extra), Map.of("MA_MOI", "ABCD"))).isEmpty();
        assertThat(validator.validate("x-1", List.of(extra), Map.of("MA_MOI", "ABCDE")))
                .extracting(RecordValidator.Violation::ruleCode)
                .contains(RecordValidator.MAX_LENGTH);
    }

    private static ValidationRule typed(String field, String dataType) {
        return rule(field, r -> r.setDataType(dataType));
    }

    private static ValidationRule rule(String field) {
        return rule(field, r -> {
        });
    }

    private static ValidationRule rule(String field, Consumer<ValidationRule> customizer) {
        ValidationRule rule = new ValidationRule();
        rule.setPh("COSOGIAODUC");
        rule.setEntity("_CO_SO_GIAO_DUC");
        rule.setField(field);
        rule.setRequired(false);
        customizer.accept(rule);
        return rule;
    }
}
