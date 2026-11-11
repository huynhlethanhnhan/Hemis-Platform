package vn.edu.hcmue.hemis.staging;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.File;
import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

import vn.edu.hcmue.hemis.journal.SyncBatch;
import vn.edu.hcmue.hemis.sync.SyncOrchestrator;

@SpringBootTest
@TestPropertySource(properties = {
    "spring.datasource.url=jdbc:postgresql://localhost:5432/hemis",
    "spring.datasource.username=hemis",
    "spring.datasource.password=hemis",
    "spring.flyway.validate-on-migrate=false",
    "spring.flyway.baseline-on-migrate=true",
    "hemis.ma-don-vi=SPS",
    "hemis.ten-don-vi=TRƯỜNG ĐẠI HỌC SƯ PHẠM TP. HỒ CHÍ MINH",
    "hemis.signing.storage-dir=./target/test-packages"
})
class CoSoGiaoDucExtractorTest {

    @Autowired
    private CoSoGiaoDucExtractor extractor;

    @Autowired
    private SyncOrchestrator orchestrator;

    @Test
    @DisplayName("1. Trích xuất thông tin Cơ sở Giáo dục từ view hemis_src.v_co_so_giao_duc qua FDW")
    void testExtractCoSoGiaoDucFromFdw() {
        PhanHeExtractor.Result result = extractor.extract();

        assertThat(result.recordCount()).isEqualTo(1);
        assertThat(result.jsonBody()).containsKey("_CO_SO_GIAO_DUC");

        @SuppressWarnings("unchecked")
        Map<String, Object> csgd = (Map<String, Object>) result.jsonBody().get("_CO_SO_GIAO_DUC");

        assertThat(csgd.get("MA_DON_VI")).isEqualTo("SPS");
        assertThat(csgd.get("TEN_DON_VI")).isEqualTo("TRƯỜNG ĐẠI HỌC SƯ PHẠM TP. HỒ CHÍ MINH");
        assertThat(csgd.get("WEBSITE")).isEqualTo("hcmue.edu.vn");
        assertThat(csgd.get("SO_DIEN_THOAI")).isEqualTo("028-38352020");
        assertThat(csgd.get("TINH_THANH_NEW")).isEqualTo("79");
        assertThat(csgd.get("XA_PHUONG_NEW")).isNotNull();
        assertThat(csgd.get("MA_DINH_DANH_ND69")).isEqualTo("SPS");
        assertThat(csgd.get("Id")).isNotNull();

        assertThat(result.xmlLists()).isNotEmpty();
    }

    @Test
    @DisplayName("2. Kiểm thử toàn trình (End-to-End) lệnh chuan-bi COSOGIAODUC sinh XML/JSON hợp lệ")
    void testChuanBiCoSoGiaoDuc() {
        SyncBatch batch = orchestrator.chuanBi("COSOGIAODUC");

        assertThat(batch).isNotNull();
        assertThat(batch.getStatus())
                .as("Batch phải đạt trạng thái CHO_KY_SO (không có lỗi BLOCK nào theo cosogiaoduc.yml)")
                .isEqualTo(SyncBatch.Status.CHO_KY_SO);

        assertThat(batch.getRecordCount()).isEqualTo(1);
        assertThat(batch.getXmlPath()).isNotNull();
        assertThat(batch.getJsonPath()).isNotNull();

        File xmlFile = new File(batch.getXmlPath());
        File jsonFile = new File(batch.getJsonPath());

        assertThat(xmlFile).exists().isNotEmpty();
        assertThat(jsonFile).exists().isNotEmpty();

        System.out.println(">>> CHUAN BI COSOGIAODUC THANH CONG!");
        System.out.println("    Batch ID: " + batch.getId());
        System.out.println("    Status: " + batch.getStatus());
        System.out.println("    XML: " + xmlFile.getAbsolutePath());
        System.out.println("    JSON: " + jsonFile.getAbsolutePath());
    }
}
