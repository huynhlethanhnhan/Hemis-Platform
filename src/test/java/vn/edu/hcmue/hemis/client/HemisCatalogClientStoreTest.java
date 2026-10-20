package vn.edu.hcmue.hemis.client;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import vn.edu.hcmue.hemis.TestcontainersConfiguration;
import vn.edu.hcmue.hemis.journal.CatalogHemis;
import vn.edu.hcmue.hemis.journal.CatalogHemisRepository;

/**
 * FR-CAT-02 · Lưu và cập nhật danh mục vào {@code catalog_hemis}.
 *
 * <p>Dùng dữ liệu mẫu từ WireMock ({@code fixtures/danh-muc-wiremock.json},
 * gốc {@code wiremock/mappings/02-danh-muc.json}) trên PostgreSQL Testcontainers.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import(TestcontainersConfiguration.class)
class HemisCatalogClientStoreTest {

    private static final JsonMapper MAPPER = JsonMapper.builder().build();
    private static final int EXPECTED_ROWS = 7;

    @Autowired
    private CatalogHemisRepository catalogRepo;

    @Autowired
    private JdbcTemplate jdbc;

    private HemisCatalogClient client;

    @BeforeEach
    void setUp() {
        client = new HemisCatalogClient(null, null, null, catalogRepo);
    }

    @Test
    @DisplayName("FR-CAT-02: luu dung cac truong suy ra dong MA_/TEN_ tu ten danh muc")
    void luuVoiTruongMaTenDong() {
        int saved = client.store(wireMockResponse());

        assertThat(saved).isEqualTo(EXPECTED_ROWS);
        assertThat(catalogRepo.count()).isEqualTo(EXPECTED_ROWS);

        CatalogHemis danToc = catalogRepo.findByDmNameAndMa("DM_DAN_TOC", "55").orElseThrow();
        assertThat(danToc.getTen()).isEqualTo("Kinh");
        assertThat(danToc.getHemisId()).isEqualTo("9f1c3f00-0000-0000-0000-000000000055");
        assertThat(danToc.getIsPublic()).isTrue();
        assertThat(danToc.getIsDeleted()).isFalse();
        assertThat(danToc.getModified()).isNotNull();

        CatalogHemis tinh = catalogRepo.findByDmNameAndMa("DM_TINH_NEW", "79").orElseThrow();
        assertThat(tinh.getTen()).isEqualTo("Thanh pho Ho Chi Minh");

        CatalogHemis xa = catalogRepo.findByDmNameAndMa("DM_XA_NEW", "27004").orElseThrow();
        assertThat(xa.getTen()).isEqualTo("Phuong Ban Co");
    }

    @Test
    @DisplayName("FR-CAT-02: chay hai lan lien tiep khong tao ban ghi trung (dm_name + ma)")
    void chayHaiLanKhongTrung() {
        HemisResponse res = wireMockResponse();

        assertThat(client.store(res)).isEqualTo(EXPECTED_ROWS);
        catalogRepo.flush();
        long afterFirst = catalogRepo.count();

        HemisResponse updated = withTenChanged(res, "DM_DAN_TOC", "55", "TEN_DAN_TOC", "Kinh (cap nhat)");
        assertThat(client.store(updated)).isEqualTo(EXPECTED_ROWS);
        catalogRepo.flush();

        assertThat(catalogRepo.count()).isEqualTo(afterFirst);
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM hemis_sync.catalog_hemis", Long.class))
                .isEqualTo(EXPECTED_ROWS);

        CatalogHemis danToc = catalogRepo.findByDmNameAndMa("DM_DAN_TOC", "55").orElseThrow();
        assertThat(danToc.getTen()).isEqualTo("Kinh (cap nhat)");
    }

    @Test
    @DisplayName("FR-CAT-02: IsDeleted=true danh dau xoa, khong xoa vat ly")
    void isDeletedDanhDauXoaMem() {
        client.store(wireMockResponse());
        catalogRepo.flush();

        CatalogHemis deleted = catalogRepo.findByDmNameAndMa("DM_GIOI_TINH", "01").orElseThrow();
        assertThat(deleted.getIsDeleted()).isFalse();
        assertThat(deleted.getTen()).isEqualTo("Nam");
        assertThat(deleted.getIsPublic()).isTrue();

        Long physicalCount = jdbc.queryForObject(
                "SELECT COUNT(*) FROM hemis_sync.catalog_hemis WHERE dm_name = ? AND ma = ?",
                Long.class, "DM_GIOI_TINH", "03");
        assertThat(physicalCount).isEqualTo(0L);

        Long softDeleted = jdbc.queryForObject(
                "SELECT COUNT(*) FROM hemis_sync.catalog_hemis WHERE is_deleted = true",
                Long.class);
        assertThat(softDeleted).isEqualTo(0L);
    }

    @Test
    @DisplayName("FR-CAT-02: giu nguyen ban ghi goc trong cot raw_json")
    void giuRawJsonGoc() {
        client.store(wireMockResponse());
        catalogRepo.flush();

        CatalogHemis row = catalogRepo.findByDmNameAndMa("DM_QUOC_TICH", "704").orElseThrow();
        assertThat(row.getRawJson()).isNotBlank();

        JsonNode raw = MAPPER.readTree(row.getRawJson());
        assertThat(raw.path("Id").asString()).isEqualTo("9f1c3f00-0000-0000-0000-000000000704");
        assertThat(raw.path("MA_QUOC_TICH").asString()).isEqualTo("704");
        assertThat(raw.path("TEN_QUOC_TICH").asString()).isEqualTo("Viet Nam");
        assertThat(raw.path("IsDeleted").asBoolean()).isFalse();
        assertThat(raw.path("Modified").asString()).isEqualTo("2026-01-15T08:00:00");
    }

    @Test
    @DisplayName("FR-CAT-02: bo qua phan tu thieu MA_<TEN>, khong ghi ban ghi rong")
    void boQuaThieuMa() {
        String json = """
                {
                  "success": true,
                  "message": null,
                  "data": {
                    "DM_DAN_TOC": [
                      { "Id": "a", "MA_DAN_TOC": "55", "TEN_DAN_TOC": "Kinh", "IsDeleted": false },
                      { "Id": "b", "TEN_DAN_TOC": "Thieu ma", "IsDeleted": false },
                      { "Id": "c", "MA_DAN_TOC": "  ", "TEN_DAN_TOC": "Ma trang", "IsDeleted": false }
                    ]
                  }
                }
                """;
        HemisResponse res = toResponse(json);

        assertThat(client.store(res)).isEqualTo(1);
        assertThat(catalogRepo.count()).isEqualTo(1);
        assertThat(catalogRepo.findByDmNameAndMa("DM_DAN_TOC", "55")).isPresent();
    }

    @Test
    @DisplayName("FR-CAT-02: data rong thi khong luu ban ghi nao")
    void dataRongKhongLuu() {
        HemisResponse empty = toResponse("""
                { "success": true, "message": null, "data": {} }
                """);
        assertThat(client.store(empty)).isZero();
        assertThat(catalogRepo.count()).isZero();
    }

    private HemisResponse wireMockResponse() {
        Path path = Path.of("wiremock/mappings/02-danh-muc.json");
    
        try {
            String mappingJson = Files.readString(path, StandardCharsets.UTF_8);
    
            JsonNode root = JsonMapper.builder().build().readTree(mappingJson);
            JsonNode jsonBody = root.path("response").path("jsonBody");
    
            assertThat(jsonBody.isMissingNode())
                    .as("response.jsonBody in 02-danh-muc.json")
                    .isFalse();
    
            return toResponse(jsonBody.toString());
    
        } catch (IOException e) {
            throw new IllegalStateException(
                    "Khong doc duoc fixture WireMock: " + path, e);
        }
    }

    private static HemisResponse toResponse(String json) {
        JsonNode root = MAPPER.readTree(json);
        return new HemisResponse(
                root.path("success").asBoolean(false),
                root.path("message").asString(null),
                root.get("data"));
    }

    private static HemisResponse withTenChanged(HemisResponse original, String dmName, String ma,
                                                String tenField, String newTen) {
        JsonNode data = original.data().deepCopy();
        for (JsonNode item : data.get(dmName)) {
            if (ma.equals(item.path("MA_" + dmName.substring(3)).asString(null))) {
                ((tools.jackson.databind.node.ObjectNode) item).put(tenField, newTen);
            }
        }
        return new HemisResponse(original.success(), original.message(), data);
    }
}
