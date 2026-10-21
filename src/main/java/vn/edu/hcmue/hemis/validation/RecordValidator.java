package vn.edu.hcmue.hemis.validation;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.stereotype.Component;

import vn.edu.hcmue.hemis.journal.CatalogMap;
import vn.edu.hcmue.hemis.journal.CatalogMapRepository;
import vn.edu.hcmue.hemis.journal.ValidationRule;

/**
 * Ap dung quy tac tu bang {@code validation_rule} (nap tu YAML, FR-VAL-01)
 * len tung ban ghi. Khong nem ngoai le khi du lieu sai — tra ve danh sach vi pham.
 */
@Component
public class RecordValidator {

    public static final String SEVERITY_BLOCK = "BLOCK";
    public static final String SEVERITY_WARN = "WARN";

    public static final String REQUIRED = "REQUIRED";
    public static final String MAX_LENGTH = "MAX_LENGTH";
    public static final String DATA_TYPE = "DATA_TYPE";
    public static final String CATALOG = "CATALOG";
    public static final String MISSING = "MISSING";
    public static final String CONDITIONAL = "CONDITIONAL";
    public static final String FORMAT = "FORMAT";

    private static final Pattern CONDITION =
            Pattern.compile("^\\s*([A-Za-z0-9_]+)\\s*=\\s*'([^']*)'\\s*$");
    private static final Pattern EMAIL =
            Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    private static final Pattern CCCD = Pattern.compile("^\\d{12}$");
    private static final Pattern CMTND = Pattern.compile("^\\d{9}$");
    private static final Pattern GUID =
            Pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$");

    private final CatalogMapRepository catalogMaps;

    public RecordValidator(CatalogMapRepository catalogMaps) {
        this.catalogMaps = catalogMaps;
    }

    public List<Violation> validate(String localId, List<ValidationRule> rules, Map<String, Object> record) {
        List<Violation> violations = new ArrayList<>();
        for (ValidationRule rule : rules) {
            Object raw = record.get(rule.getField());
            String text = stringify(raw);
            boolean empty = isEmpty(raw);

            if (Boolean.TRUE.equals(rule.getRequired()) && empty) {
                violations.add(block(localId, rule, REQUIRED,
                        "Trường bắt buộc không được rỗng"));
            }

            if (rule.getConditionExpr() != null && !rule.getConditionExpr().isBlank()) {
                if (conditionMatches(rule.getConditionExpr(), record) && empty) {
                    violations.add(block(localId, rule, CONDITIONAL,
                            "Bắt buộc khi " + rule.getConditionExpr()));
                }
            }

            if (empty) {
                continue;
            }

            if (rule.getMaxLength() > 0 && text.length() > rule.getMaxLength()) {
                violations.add(block(localId, rule, MAX_LENGTH,
                        "Độ dài " + text.length() + " vượt quá " + rule.getMaxLength()));
            }

            if (rule.getDataType() != null && !rule.getDataType().isBlank()
                    && !matchesDataType(raw, rule.getDataType())) {
                violations.add(block(localId, rule, DATA_TYPE,
                        "Giá trị không đúng kiểu " + rule.getDataType()));
            }

            if (rule.getCatalogName() != null && !rule.getCatalogName().isBlank()
                    && !catalogMapped(rule.getCatalogName(), text)) {
                violations.add(block(localId, rule, MISSING,
                        "Mã '" + text + "' chưa ánh xạ trong catalog_map (" + rule.getCatalogName() + ")"));
            }

            formatWarning(localId, rule, text).ifPresent(violations::add);
        }
        return violations;
    }

    private boolean catalogMapped(String catalogName, String localCode) {
        Optional<CatalogMap> mapped = catalogMaps.findByDmNameAndLocalCode(catalogName, localCode);
        if (mapped.isEmpty()) {
            return false;
        }
        CatalogMap row = mapped.get();
        if ("MISSING".equalsIgnoreCase(row.getStrategy())) {
            return false;
        }
        return row.getHemisCode() != null && !row.getHemisCode().isBlank();
    }

    private boolean conditionMatches(String expression, Map<String, Object> record) {
        Matcher matcher = CONDITION.matcher(expression);
        if (!matcher.matches()) {
            return false;
        }
        return stringify(record.get(matcher.group(1))).equals(matcher.group(2));
    }

    private Optional<Violation> formatWarning(String localId, ValidationRule rule, String text) {
        String field = rule.getField();
        if (field != null && field.toUpperCase().contains("EMAIL") && !EMAIL.matcher(text).matches()) {
            return Optional.of(warn(localId, rule, FORMAT, "Email không đúng định dạng"));
        }
        if (field != null && field.toUpperCase().contains("CCCD") && !CCCD.matcher(text).matches()) {
            return Optional.of(warn(localId, rule, FORMAT, "Số căn cước phải gồm 12 chữ số"));
        }
        if (field != null && field.toUpperCase().contains("CMTND") && !CMTND.matcher(text).matches()) {
            return Optional.of(warn(localId, rule, FORMAT, "Số CMTND phải gồm 9 chữ số"));
        }
        if ("date".equalsIgnoreCase(rule.getDataType()) && !matchesDataType(text, "date")) {
            return Optional.of(warn(localId, rule, FORMAT, "Ngày không đúng định dạng ISO"));
        }
        return Optional.empty();
    }

    private static boolean matchesDataType(Object raw, String dataType) {
        String type = dataType.trim().toLowerCase();
        return switch (type) {
            case "string" -> true;
            case "int" -> isInt(raw);
            case "double" -> isDouble(raw);
            case "date" -> isDate(raw);
            case "bool" -> isBool(raw);
            case "guid" -> isGuid(raw);
            default -> false;
        };
    }

    private static boolean isInt(Object raw) {
        if (raw instanceof Byte || raw instanceof Short || raw instanceof Integer || raw instanceof Long) {
            return true;
        }
        String text = stringify(raw);
        return text.matches("-?\\d+");
    }

    private static boolean isDouble(Object raw) {
        if (raw instanceof Number) {
            return true;
        }
        try {
            Double.parseDouble(stringify(raw));
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    private static boolean isDate(Object raw) {
        if (raw instanceof LocalDate) {
            return true;
        }
        try {
            LocalDate.parse(stringify(raw));
            return true;
        } catch (DateTimeParseException e) {
            return false;
        }
    }

    private static boolean isBool(Object raw) {
        if (raw instanceof Boolean) {
            return true;
        }
        String text = stringify(raw).toLowerCase();
        return "true".equals(text) || "false".equals(text);
    }

    private static boolean isGuid(Object raw) {
        if (raw instanceof UUID) {
            return true;
        }
        String text = stringify(raw);
        if (!GUID.matcher(text).matches()) {
            return false;
        }
        try {
            UUID.fromString(text);
            return true;
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    private static boolean isEmpty(Object raw) {
        return raw == null || stringify(raw).isBlank();
    }

    private static String stringify(Object raw) {
        return raw == null ? "" : String.valueOf(raw).trim();
    }

    private static Violation block(String localId, ValidationRule rule, String code, String detail) {
        return new Violation(localId, rule.getField(), code, SEVERITY_BLOCK, message(localId, rule, code, detail));
    }

    private static Violation warn(String localId, ValidationRule rule, String code, String detail) {
        return new Violation(localId, rule.getField(), code, SEVERITY_WARN, message(localId, rule, code, detail));
    }

    private static String message(String localId, ValidationRule rule, String code, String detail) {
        return "Bản ghi " + localId + " trường " + rule.getField() + " vi phạm " + code + ": " + detail;
    }

    public record Violation(String localId, String field, String ruleCode, String severity, String message) {}
}
