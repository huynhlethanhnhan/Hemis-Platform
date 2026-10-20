package vn.edu.hcmue.hemis.client;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestClient;

import tools.jackson.databind.JsonNode;

import vn.edu.hcmue.hemis.config.HemisProperties;
import vn.edu.hcmue.hemis.journal.CatalogHemis;
import vn.edu.hcmue.hemis.journal.CatalogHemisRepository;

/**
 * Goi API lay danh muc dung chung cua HEMIS.
 *
 * <p>Mot lan goi tra ve HON 175 danh sach danh muc trong mot doi tuong
 * {@code data} duy nhat (DM_DAN_TOC, DM_TINH, DM_XA_NEW, DM_NGANH...).
 * Phan hoi rat lon nen dat thoi gian cho doc dai (xem {@code hemis.http.read-timeout-seconds}).
 *
 * <p>Moi phan tu danh muc co cau truc chung: Id, Code, MA_&lt;TEN&gt;, TEN_&lt;TEN&gt;,
 * ISPUBLIC, IsDeleted, Created, CreatedBy, Modified, ModifiedBy.
 *
 * <p>Ten truong MA_/TEN_ phu thuoc ten danh muc (vi du DM_DAN_TOC → MA_DAN_TOC);
 * phai suy ra dong, khong gan cung.
 */
@Component
public class HemisCatalogClient {

    private static final Logger log = LoggerFactory.getLogger(HemisCatalogClient.class);

    private final RestClient gateway;
    private final HemisAuthClient auth;
    private final HemisProperties props;
    private final CatalogHemisRepository catalogRepo;

    public HemisCatalogClient(RestClient gatewayRestClient, HemisAuthClient auth, HemisProperties props,
                              CatalogHemisRepository catalogRepo) {
        this.gateway = gatewayRestClient;
        this.auth = auth;
        this.props = props;
        this.catalogRepo = catalogRepo;
    }

    /** Ket qua tai + luu danh muc. */
    public record StoreResult(HemisResponse response, int saved) {}

    /** Tai toan bo danh muc dung chung. */
    public HemisResponse fetchAll() {
        long t0 = System.currentTimeMillis();
        HemisResponse res = gateway.post()
                .uri(props.paths().catalog())
                .header(HttpHeaders.AUTHORIZATION, auth.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .body(Collections.emptyMap())
                .retrieve()
                .body(HemisResponse.class);

        if (res == null) {
            throw new HemisResponse.HemisApiException("API danh muc khong tra ve du lieu");
        }
        res.requireSuccess("Tai danh muc dung chung");

        int n = res.data() == null ? 0 : res.data().size();
        log.info("Da tai {} danh muc dung chung trong {} ms", n, System.currentTimeMillis() - t0);
        return res;
    }

    /**
     * Tai danh muc roi luu/cap nhat vao bang {@code catalog_hemis}.
     * Chay hai lan khong tao ban ghi trung (khoa dm_name + ma).
     */
    @Transactional
    public StoreResult fetchAndStore() {
        HemisResponse res = fetchAll();
        int saved = store(res);
        return new StoreResult(res, saved);
    }

    /**
     * Luu tung phan tu danh muc vao {@code catalog_hemis}.
     *
     * @return so ban ghi da insert/update
     */
    @Transactional
    public int store(HemisResponse res) {
        JsonNode data = res.data();
        if (data == null || !data.isObject() || data.isEmpty()) {
            log.warn("Khong co du lieu danh muc de luu");
            return 0;
        }

        Set<String> dmNames = data.propertyNames().stream()
                .filter(name -> data.get(name) != null && data.get(name).isArray())
                .collect(Collectors.toSet());

        Map<String, Map<String, CatalogHemis>> existing = indexExisting(dmNames);

        List<CatalogHemis> toSave = new ArrayList<>();
        int skipped = 0;

        for (Map.Entry<String, JsonNode> entry : data.properties()) {
            String dmName = entry.getKey();
            JsonNode items = entry.getValue();
            if (items == null || !items.isArray()) {
                continue;
            }

            String suffix = dmName.startsWith("DM_") ? dmName.substring(3) : dmName;
            String maField = "MA_" + suffix;
            String tenField = "TEN_" + suffix;
            Map<String, CatalogHemis> byMa = existing.computeIfAbsent(dmName, k -> new HashMap<>());

            for (JsonNode item : items) {
                String ma = textOrNull(item, maField);
                if (ma == null || ma.isBlank()) {
                    skipped++;
                    log.warn("Bo qua ban ghi {} thieu {}", dmName, maField);
                    continue;
                }

                CatalogHemis row = byMa.get(ma);
                if (row == null) {
                    row = new CatalogHemis();
                    row.setDmName(dmName);
                    row.setMa(ma);
                    byMa.put(ma, row);
                }

                row.setHemisId(textOrNull(item, "Id"));
                row.setCode(textOrNull(item, "Code"));
                row.setTen(textOrNull(item, tenField));
                row.setIsPublic(booleanOrNull(item, "ISPUBLIC"));
                row.setIsDeleted(item.path("IsDeleted").asBoolean(false));
                row.setModified(parseModified(textOrNull(item, "Modified")));
                row.setRawJson(item.toString());
                toSave.add(row);
            }
        }

        catalogRepo.saveAll(toSave);
        log.info("Da luu/cap nhat {} ban ghi catalog_hemis (bo qua {})", toSave.size(), skipped);
        return toSave.size();
    }

    private Map<String, Map<String, CatalogHemis>> indexExisting(Set<String> dmNames) {
        Map<String, Map<String, CatalogHemis>> index = new HashMap<>();
        if (dmNames.isEmpty()) {
            return index;
        }
        for (CatalogHemis row : catalogRepo.findByDmNameIn(dmNames)) {
            if (row.getMa() == null) {
                continue;
            }
            index.computeIfAbsent(row.getDmName(), k -> new HashMap<>())
                    .put(row.getMa(), row);
        }
        return index;
    }

    private static String textOrNull(JsonNode node, String field) {
        JsonNode v = node.get(field);
        if (v == null || v.isNull() || v.isMissingNode()) {
            return null;
        }
        String s = v.asString(null);
        return s == null || s.isBlank() ? null : s;
    }

    private static Boolean booleanOrNull(JsonNode node, String field) {
        JsonNode v = node.get(field);
        if (v == null || v.isNull() || v.isMissingNode()) {
            return null;
        }
        return v.asBoolean();
    }

    /** HEMIS thuong tra Modified khong co offset; coi la UTC. */
    private static OffsetDateTime parseModified(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return OffsetDateTime.parse(raw);
        } catch (DateTimeParseException ignored) {
            // fall through
        }
        try {
            return LocalDateTime.parse(raw).atOffset(ZoneOffset.UTC);
        } catch (DateTimeParseException e) {
            log.warn("Khong parse duoc Modified='{}': {}", raw, e.getMessage());
            return null;
        }
    }
}
