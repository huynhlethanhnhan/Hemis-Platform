package vn.edu.hcmue.hemis.staging;

import java.sql.Date;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import vn.edu.hcmue.hemis.config.HemisProperties;
import vn.edu.hcmue.hemis.packaging.XmlPackager;

/**
 * Phan he COSOGIAODUC (API db1) - phan he duoc chon lam thi diem cua Giai doan 1.
 * Doc truc tiep tu view hop dong hemis_src.v_co_so_giao_duc noi qua FDW toi HEMIS DWH.
 */
@Component
public class CoSoGiaoDucExtractor implements PhanHeExtractor {

    private final HemisProperties props;
    private final JdbcClient jdbcClient;

    public CoSoGiaoDucExtractor(HemisProperties props, JdbcClient jdbcClient) {
        this.props = props;
        this.jdbcClient = jdbcClient;
    }

    @Override
    public String ph() {
        return "COSOGIAODUC";
    }

    @Override
    public String api() {
        return "db1";
    }

    @Override
    public Result extract() {
        Map<String, Object> csgd = thongTinChung();

        // --- Ban JSON: ten truong UPPER_SNAKE theo dac ta ---
        Map<String, Object> jsonBody = new LinkedHashMap<>();
        jsonBody.put("_CO_SO_GIAO_DUC", csgd);

        // --- Ban XML: cung du lieu, ten the PascalCase ---
        Map<String, Object> xmlRecord = toPascalCase(csgd);
        List<XmlPackager.DanhSach> xmlLists = List.of(
                new XmlPackager.DanhSach("DanhSachCoSoGiaoDuc", "CoSoGiaoDuc", List.of(xmlRecord)));

        return new Result(xmlLists, jsonBody, 1);
    }

    /**
     * Thong tin chung cua co so giao duc tu view hemis_src.v_co_so_giao_duc.
     */
    private Map<String, Object> thongTinChung() {
        String maDonVi = (props.maDonVi() != null && !props.maDonVi().isBlank()) ? props.maDonVi() : "SPS";

        // 1. Dinh danh GUID on dinh tu entity_map hoac props.donViId
        UUID hemisId;
        try {
            if (props.donViId() != null && !props.donViId().isBlank()
                    && !props.donViId().equals("00000000-0000-0000-0000-000000000000")) {
                hemisId = UUID.fromString(props.donViId());
            } else {
                hemisId = getOrCreateEntityMap("COSOGIAODUC", maDonVi);
            }
        } catch (Exception e) {
            hemisId = UUID.fromString("00000000-0000-0000-0000-000000000001");
        }

        Map<String, Object> m = new LinkedHashMap<>();
        m.put("Id", hemisId.toString());

        // 2. Truy van tu view hop dong hemis_src.v_co_so_giao_duc
        try {
            String sql = """
                SELECT * FROM hemis_src.v_co_so_giao_duc
                WHERE business_key = ? OR "MA_DON_VI" = ?
                LIMIT 1
                """;

            Map<String, Object> row = jdbcClient.sql(sql)
                    .param(maDonVi)
                    .param(maDonVi)
                    .query()
                    .listOfRows()
                    .stream()
                    .findFirst()
                    .orElse(null);

            if (row != null) {
                row.forEach((k, v) -> {
                    if ("business_key".equalsIgnoreCase(k) || "delta_ts".equalsIgnoreCase(k) || "nguon_id".equalsIgnoreCase(k)) {
                        return;
                    }
                    if (v instanceof Date d) {
                        m.put(k, d.toLocalDate());
                    } else if (v != null) {
                        m.put(k, v);
                    }
                });
            }
        } catch (Exception ex) {
            // Fallback neu chua ket noi duoc FDW
            m.put("MA_DON_VI", maDonVi);
            m.put("TEN_DON_VI", props.tenDonVi());
        }

        // 3. Dam bao cac truong bat buoc co gia tri hop le
        m.putIfAbsent("MA_DON_VI", maDonVi);
        m.putIfAbsent("TEN_DON_VI", props.tenDonVi());
        m.putIfAbsent("Created", LocalDate.now());
        m.putIfAbsent("Modified", LocalDate.now());

        return m;
    }

    private UUID getOrCreateEntityMap(String entityType, String businessKey) {
        String query = """
            INSERT INTO hemis_sync.entity_map (entity_type, business_key, local_table, local_id)
            VALUES (?, ?, 'cosogiaoduc', ?)
            ON CONFLICT (entity_type, business_key) DO UPDATE
                SET business_key = EXCLUDED.business_key
            RETURNING hemis_id
            """;
        return jdbcClient.sql(query)
                .param(entityType)
                .param(businessKey)
                .param(businessKey)
                .query(UUID.class)
                .single();
    }

    /**
     * Doi ten truong UPPER_SNAKE sang PascalCase cho ban XML.
     * Vi du: MA_DON_VI -> MaDonVi, SO_QD_THANH_LAP -> SoQdThanhLap.
     */
    static Map<String, Object> toPascalCase(Map<String, Object> source) {
        Map<String, Object> out = new LinkedHashMap<>();
        source.forEach((k, v) -> out.put(pascal(k), v));
        return out;
    }

    static String pascal(String upperSnake) {
        if (upperSnake == null || upperSnake.isBlank()) {
            return upperSnake;
        }
        if (!upperSnake.contains("_") && !upperSnake.equals(upperSnake.toUpperCase())) {
            return upperSnake;
        }
        StringBuilder sb = new StringBuilder();
        for (String part : upperSnake.split("_")) {
            if (part.isEmpty()) {
                continue;
            }
            sb.append(Character.toUpperCase(part.charAt(0)))
              .append(part.substring(1).toLowerCase());
        }
        return sb.toString();
    }
}
