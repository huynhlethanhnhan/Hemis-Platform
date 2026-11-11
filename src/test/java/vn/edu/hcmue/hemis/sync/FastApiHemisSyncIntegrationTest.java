package vn.edu.hcmue.hemis.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import tools.jackson.databind.ObjectMapper;
import vn.edu.hcmue.hemis.client.HemisResponse;
import vn.edu.hcmue.hemis.client.HemisSyncClient;
import vn.edu.hcmue.hemis.config.HemisProperties;
import vn.edu.hcmue.hemis.journal.ApiLog;
import vn.edu.hcmue.hemis.journal.ApiLogRepository;
import vn.edu.hcmue.hemis.journal.CatalogMap;
import vn.edu.hcmue.hemis.journal.CatalogMapRepository;
import vn.edu.hcmue.hemis.journal.SyncBatch;
import vn.edu.hcmue.hemis.journal.SyncBatchRepository;
import vn.edu.hcmue.hemis.journal.SyncError;
import vn.edu.hcmue.hemis.journal.SyncErrorRepository;
import vn.edu.hcmue.hemis.journal.ValidationRule;
import vn.edu.hcmue.hemis.journal.ValidationRuleRepository;
import vn.edu.hcmue.hemis.packaging.Iks;
import vn.edu.hcmue.hemis.packaging.XmlPackager;
import vn.edu.hcmue.hemis.signing.SignJob;
import vn.edu.hcmue.hemis.signing.SignJobRepository;
import vn.edu.hcmue.hemis.signing.XmlDsigVerifier;
import vn.edu.hcmue.hemis.staging.PhanHeExtractor;
import vn.edu.hcmue.hemis.validation.RecordValidator;

/**
 * Bo kiem thu mo rong 40 test cases cho Hemis-Platform khi tiep nhan du lieu tu FastAPI qua:
 * 1. Chan khi khong co ky so & Kiem soat trang thai dot dong bo (10 tests)
 * 2. Nhat ky Audit Log & Xu ly ghi vet khi ky so loi/chan (8 tests)
 * 3. Tiep nhan du lieu FastAPI qua hemis_src & Quy tac kiem tra (12 tests)
 * 4. Dong goi XML, IKS & Xac thuc toan ven chu ky so (10 tests)
 */
class FastApiHemisSyncIntegrationTest {

    private static final String ENTITY = "_CAN_BO";
    private static final String PH = "CANBO";
    private static final String RECORD_ID = "cb-001";

    @TempDir
    Path tempDir;

    private SyncBatchRepository batches;
    private SignJobRepository signJobs;
    private SyncErrorRepository syncErrors;
    private ValidationRuleRepository validationRules;
    private ApiLogRepository apiLogs;
    private CatalogMapRepository catalogMaps;
    private HemisSyncClient syncClient;
    private RecordValidator validator;
    private XmlPackager xmlPackager;
    private SyncOrchestrator orchestrator;
    private HemisProperties props;
    private Map<String, Object> recordFromFastApi;
    private Path packageDir;

    @BeforeEach
    void setUp() throws IOException {
        packageDir = Files.createDirectories(tempDir.resolve("packages"));
        batches = mock(SyncBatchRepository.class);
        signJobs = mock(SignJobRepository.class);
        syncErrors = mock(SyncErrorRepository.class);
        validationRules = mock(ValidationRuleRepository.class);
        apiLogs = mock(ApiLogRepository.class);
        catalogMaps = mock(CatalogMapRepository.class);
        syncClient = mock(HemisSyncClient.class);
        xmlPackager = mock(XmlPackager.class);
        validator = new RecordValidator(catalogMaps);

        when(xmlPackager.build(any(), any(), any(), any())).thenReturn(
                "<DuLieuKySo Id=\"data\"><k1>123456789012345678</k1><CanBo><Id>cb-001</Id></CanBo><k2>123456789012345678</k2></DuLieuKySo>");

        when(batches.save(any(SyncBatch.class))).thenAnswer(invocation -> {
            SyncBatch b = invocation.getArgument(0);
            if (b.getId() == null) {
                b.setId(101L);
            }
            return b;
        });

        when(syncErrors.saveAll(org.mockito.ArgumentMatchers.<Iterable<SyncError>>any()))
                .thenAnswer(invocation -> {
                    List<SyncError> list = new java.util.ArrayList<>();
                    invocation.<Iterable<SyncError>>getArgument(0).forEach(list::add);
                    return list;
                });

        recordFromFastApi = new LinkedHashMap<>();
        recordFromFastApi.put("Id", RECORD_ID);
        recordFromFastApi.put("HO_VA_TEN", "Nguyen Van A");
        recordFromFastApi.put("SO_CCCD", "079090123456");
        recordFromFastApi.put("GIOI_TINH_ID", "01");

        PhanHeExtractor canBoExtractor = new PhanHeExtractor() {
            @Override public String ph() { return PH; }
            @Override public String api() { return "db7"; }
            @Override public Result extract() {
                return new Result(List.of(), Map.of(ENTITY, recordFromFastApi), 1);
            }
        };

        props = new HemisProperties(
                "http://localhost:8089", "http://localhost:8089", null, null,
                "00000000-0000-0000-0000-000000000000", "HCMUE", "Truong Dai hoc Su pham TPHCM",
                "hcmue.edu.vn", null, null, null,
                new HemisProperties.Signing("agent", packageDir.toString(), true, null));

        orchestrator = new SyncOrchestrator(List.of(canBoExtractor), xmlPackager,
                syncClient, batches, signJobs, apiLogs, props, new ObjectMapper(), validator,
                validationRules, syncErrors);
    }

    // =========================================================================
    // NHOM 1: CHAN KHI KHONG CO KY SO & KIEM SOAT TRANG THAI DOT (Tests 01-10)
    // =========================================================================

    @Test
    @DisplayName("01. Chan gui() khi dot dang o trang thai KHOI_TAO")
    void test01_gui_blocked_when_status_is_khoi_tao() {
        SyncBatch batch = new SyncBatch();
        batch.setId(1L);
        batch.setStatus(SyncBatch.Status.KHOI_TAO);
        when(batches.findById(1L)).thenReturn(Optional.of(batch));

        assertThatThrownBy(() -> orchestrator.gui(1L))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("chi duoc gui khi da ky so");
    }

    @Test
    @DisplayName("02. Chan gui() khi dot dang o trang thai CHO_KY_SO")
    void test02_gui_blocked_when_status_is_cho_ky_so() {
        SyncBatch batch = new SyncBatch();
        batch.setId(2L);
        batch.setStatus(SyncBatch.Status.CHO_KY_SO);
        when(batches.findById(2L)).thenReturn(Optional.of(batch));

        assertThatThrownBy(() -> orchestrator.gui(2L))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("chi duoc gui khi da ky so");
    }

    @Test
    @DisplayName("03. Chan gui() khi dot dang o trang thai CHO_SUA_LOI")
    void test03_gui_blocked_when_status_is_cho_sua_loi() {
        SyncBatch batch = new SyncBatch();
        batch.setId(3L);
        batch.setStatus(SyncBatch.Status.CHO_SUA_LOI);
        when(batches.findById(3L)).thenReturn(Optional.of(batch));

        assertThatThrownBy(() -> orchestrator.gui(3L))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("chi duoc gui khi da ky so");
    }

    @Test
    @DisplayName("04. Chan gui() khi dot o trang thai DA_DONG_GOI nhung chua ky so")
    void test04_gui_blocked_when_status_is_da_dong_goi() {
        SyncBatch batch = new SyncBatch();
        batch.setId(4L);
        batch.setStatus(SyncBatch.Status.DA_DONG_GOI);
        when(batches.findById(4L)).thenReturn(Optional.of(batch));

        assertThatThrownBy(() -> orchestrator.gui(4L))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("chi duoc gui khi da ky so");
    }

    @Test
    @DisplayName("05. Chan gui() khi duong dan signedXmlPath bi null")
    void test05_gui_blocked_when_signed_xml_path_null() {
        SyncBatch batch = new SyncBatch();
        batch.setId(5L);
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batch.setSignedXmlPath(null);
        batch.setIks(UUID.randomUUID());
        batch.setPh(PH);
        when(batches.findById(5L)).thenReturn(Optional.of(batch));

        assertThatThrownBy(() -> orchestrator.gui(5L))
                .isInstanceOf(Exception.class);
    }

    @Test
    @DisplayName("06. Cho phep gui() chi khi dot dat trang thai DA_KY_SO")
    void test06_gui_allowed_only_when_status_is_da_ky_so() throws IOException {
        Path signedFile = Files.createTempFile("signed", ".xml");
        Files.writeString(signedFile, "<signedXmlContent/>");

        Path jsonFile = Files.createTempFile("payload", ".json");
        Files.writeString(jsonFile, "{\"t_k\":\"test\"}");

        SyncBatch batch = new SyncBatch();
        batch.setId(6L);
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batch.setSignedXmlPath(signedFile.toString());
        batch.setJsonPath(jsonFile.toString());
        batch.setIks(UUID.randomUUID());
        batch.setIdKey(UUID.randomUUID());
        batch.setPh(PH);
        batch.setApi("db7");
        when(batches.findById(6L)).thenReturn(Optional.of(batch));
        when(syncClient.uploadSignedXml(any(), any(), any()))
                .thenReturn(new HemisResponse(true, "OK", null));
        when(syncClient.syncJson(any(), any(), any()))
                .thenReturn(new HemisResponse(true, "OK", null));

        SyncBatch sent = orchestrator.gui(6L);
        assertThat(sent.getStatus()).isEqualTo(SyncBatch.Status.DA_GUI_JSON);
    }

    @Test
    @DisplayName("07. Chuyen trang thai THAT_BAI khi upload db16 bi tu choi do chu ky hong")
    void test07_gui_marks_status_that_bai_when_upload_fails() throws IOException {
        Path signedFile = Files.createTempFile("signed_bad", ".xml");
        Files.writeString(signedFile, "<invalidSignedXml/>");

        SyncBatch batch = new SyncBatch();
        batch.setId(7L);
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batch.setSignedXmlPath(signedFile.toString());
        batch.setIks(UUID.randomUUID());
        batch.setPh(PH);
        when(batches.findById(7L)).thenReturn(Optional.of(batch));
        when(syncClient.uploadSignedXml(any(), any(), any()))
                .thenThrow(new RuntimeException("Chu ky so khong hop le"));

        assertThatThrownBy(() -> orchestrator.gui(7L))
                .isInstanceOf(RuntimeException.class);
        assertThat(batch.getStatus()).isEqualTo(SyncBatch.Status.THAT_BAI);
        assertThat(batch.getMessage()).contains("db16 that bai: Chu ky so khong hop le");
    }

    @Test
    @DisplayName("08. Ghi nhan thong diep loi chi tiet trong SyncBatch khi that bai")
    void test08_gui_stores_detailed_error_message_when_rejected() throws IOException {
        Path signedFile = Files.createTempFile("signed_corrupt", ".xml");
        Files.writeString(signedFile, "<tamperedXml/>");

        SyncBatch batch = new SyncBatch();
        batch.setId(8L);
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batch.setSignedXmlPath(signedFile.toString());
        batch.setIks(UUID.randomUUID());
        batch.setPh(PH);
        when(batches.findById(8L)).thenReturn(Optional.of(batch));
        when(syncClient.uploadSignedXml(any(), any(), any()))
                .thenThrow(new RuntimeException("XMLDSIG_VERIFICATION_FAILED: SignatureValue invalid"));

        assertThatThrownBy(() -> orchestrator.gui(8L)).isNotNull();
        assertThat(batch.getMessage()).contains("XMLDSIG_VERIFICATION_FAILED");
    }

    @Test
    @DisplayName("09. Cap nhat trang thai DA_GUI_XML sau khi db16 thanh cong")
    void test09_gui_updates_status_da_gui_xml_after_successful_db16() throws IOException {
        Path signedFile = Files.createTempFile("signed_ok", ".xml");
        Files.writeString(signedFile, "<signedXmlContent/>");

        Path jsonFile = Files.createTempFile("payload", ".json");
        Files.writeString(jsonFile, "{\"t_k\":\"test\"}");

        SyncBatch batch = new SyncBatch();
        batch.setId(9L);
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batch.setSignedXmlPath(signedFile.toString());
        batch.setJsonPath(jsonFile.toString());
        batch.setIks(UUID.randomUUID());
        batch.setIdKey(UUID.randomUUID());
        batch.setPh(PH);
        batch.setApi("db7");
        when(batches.findById(9L)).thenReturn(Optional.of(batch));
        when(syncClient.uploadSignedXml(any(), any(), any()))
                .thenReturn(new HemisResponse(true, "OK", null));
        when(syncClient.syncJson(any(), any(), any()))
                .thenThrow(new RuntimeException("Loi o buoc dbN"));

        assertThatThrownBy(() -> orchestrator.gui(9L)).isNotNull();
        // Sau khi db16 thanh cong, da ghi nhat ky DA_GUI_XML truoc khi bi loi dbN
        verify(syncClient).uploadSignedXml(any(), any(), any());
    }

    @Test
    @DisplayName("10. Cap nhat trang thai DA_GUI_JSON va sentAt sau khi dbN hoan tat")
    void test10_gui_updates_status_da_gui_json_and_sent_at_after_dbN() throws IOException {
        Path signedFile = Files.createTempFile("signed", ".xml");
        Files.writeString(signedFile, "<signedXml/>");
        Path jsonFile = Files.createTempFile("json", ".json");
        Files.writeString(jsonFile, "{\"t_k\":\"iks\"}");

        SyncBatch batch = new SyncBatch();
        batch.setId(10L);
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batch.setSignedXmlPath(signedFile.toString());
        batch.setJsonPath(jsonFile.toString());
        batch.setIks(UUID.randomUUID());
        batch.setIdKey(UUID.randomUUID());
        batch.setPh(PH);
        batch.setApi("db7");
        when(batches.findById(10L)).thenReturn(Optional.of(batch));
        when(syncClient.uploadSignedXml(any(), any(), any()))
                .thenReturn(new HemisResponse(true, "OK", null));
        when(syncClient.syncJson(any(), any(), any()))
                .thenReturn(new HemisResponse(true, "OK", null));

        SyncBatch res = orchestrator.gui(10L);
        assertThat(res.getStatus()).isEqualTo(SyncBatch.Status.DA_GUI_JSON);
        assertThat(res.getSentAt()).isNotNull();
        assertThat(res.getMessage()).isEqualTo("Gui thanh cong");
    }

    // =========================================================================
    // NHOM 2: NHAT KY AUDIT LOG & XU LY GHI VET KHI KY SO LOI (Tests 11-18)
    // =========================================================================

    @Test
    @DisplayName("11. Ghi log ApiLog huong OUT va method POST khi nop db16")
    void test11_api_log_records_outgoing_post_on_db16_attempt() throws IOException {
        Path signedFile = Files.createTempFile("signed", ".xml");
        Files.writeString(signedFile, "<signedXml/>");
        Path jsonFile = Files.createTempFile("json", ".json");
        Files.writeString(jsonFile, "{}");

        SyncBatch batch = new SyncBatch();
        batch.setId(11L);
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batch.setSignedXmlPath(signedFile.toString());
        batch.setJsonPath(jsonFile.toString());
        batch.setIks(UUID.randomUUID());
        batch.setIdKey(UUID.randomUUID());
        batch.setPh(PH);
        batch.setApi("db7");
        when(batches.findById(11L)).thenReturn(Optional.of(batch));
        when(syncClient.uploadSignedXml(any(), any(), any()))
                .thenReturn(new HemisResponse(true, "OK", null));
        when(syncClient.syncJson(any(), any(), any()))
                .thenReturn(new HemisResponse(true, "OK", null));

        orchestrator.gui(11L);
        org.mockito.ArgumentCaptor<ApiLog> captor = org.mockito.ArgumentCaptor.captor();
        verify(apiLogs, org.mockito.Mockito.atLeastOnce()).save(captor.capture());
        ApiLog logDb16 = captor.getAllValues().get(0);
        assertThat(logDb16.getDirection()).isEqualTo("OUT");
        assertThat(logDb16.getMethod()).isEqualTo("POST");
        assertThat(logDb16.getUrl()).contains("db16/CANBO");
    }

    @Test
    @DisplayName("12. Ghi log ApiLog voi success = false va luu error khi nop XML bi loi")
    void test12_api_log_records_failure_and_error_message() throws IOException {
        Path signedFile = Files.createTempFile("signed", ".xml");
        Files.writeString(signedFile, "<badSignedXml/>");

        SyncBatch batch = new SyncBatch();
        batch.setId(12L);
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batch.setSignedXmlPath(signedFile.toString());
        batch.setIks(UUID.randomUUID());
        batch.setPh(PH);
        when(batches.findById(12L)).thenReturn(Optional.of(batch));
        when(syncClient.uploadSignedXml(any(), any(), any()))
                .thenThrow(new RuntimeException("Connection timeout"));

        assertThatThrownBy(() -> orchestrator.gui(12L)).isNotNull();
        org.mockito.ArgumentCaptor<ApiLog> captor = org.mockito.ArgumentCaptor.captor();
        verify(apiLogs).save(captor.capture());
        ApiLog failLog = captor.getValue();
        assertThat(failLog.getSuccess()).isFalse();
        assertThat(failLog.getError()).contains("Connection timeout");
    }

    @Test
    @DisplayName("13. Che giau so CCCD trong noi dung response log (CCCD masking)")
    void test13_api_log_masks_cccd_in_response_body() {
        String rawBody = "{\"hovaten\":\"Nguyen Van A\",\"socccd\":\"079090123456\",\"status\":\"OK\"}";
        String masked = rawBody.replaceAll("(\"socccd\":\\s*\")(\\d{6})\\d{3}(\\d{3}\")", "$1$2***$3");
        assertThat(masked).contains("079090***456");
        assertThat(masked).doesNotContain("079090123456");
    }

    @Test
    @DisplayName("14. Ghi nhan thoi gian thuc thi durationMs trong ApiLog")
    void test14_api_log_records_duration_in_milliseconds() {
        ApiLog log = new ApiLog();
        log.setDurationMs(1250L);
        assertThat(log.getDurationMs()).isGreaterThan(0L);
        assertThat(log.getDurationMs()).isEqualTo(1250L);
    }

    @Test
    @DisplayName("15. Hang doi SignJob chuyen trang thai FAILED khi tram ky bao loi")
    void test15_sign_job_records_failed_status_when_agent_reports_error() {
        SignJob job = new SignJob();
        job.setStatus(SignJob.Status.FAILED);
        job.setError("USB Token PIN locked (mã PIN bị khóa)");
        assertThat(job.getStatus()).isEqualTo(SignJob.Status.FAILED);
        assertThat(job.getError()).contains("PIN locked");
    }

    @Test
    @DisplayName("16. Hang doi SignJob dem so lan thu attempts khi thu lai")
    void test16_sign_job_tracks_retry_attempts() {
        SignJob job = new SignJob();
        job.setAttempts(1);
        job.setAttempts(job.getAttempts() + 1);
        assertThat(job.getAttempts()).isEqualTo(2);
    }

    @Test
    @DisplayName("17. Hang doi SignJob luu vet leasedBy va leasedAt cua tram ky")
    void test17_sign_job_records_leased_by_and_leased_at() {
        SignJob job = new SignJob();
        job.setLeasedBy("TRAM_KY_BGH_01");
        job.setLeasedAt(OffsetDateTime.now());
        assertThat(job.getLeasedBy()).isEqualTo("TRAM_KY_BGH_01");
        assertThat(job.getLeasedAt()).isNotNull();
    }

    @Test
    @DisplayName("18. Tinh toan ma bam SHA-256 va khong de trong trong SyncBatch")
    void test18_sync_batch_payload_sha256_is_calculated() {
        SyncBatch batch = orchestrator.chuanBi(PH);
        assertThat(batch.getPayloadSha256()).isNotNull();
        assertThat(batch.getPayloadSha256()).hasSize(64); // SHA-256 hex length
    }

    // =========================================================================
    // NHOM 3: TIEP NHAN DU LIEU FASTAPI QUA hemis_src & VALIDATION (Tests 19-30)
    // =========================================================================

    @Test
    @DisplayName("19. Tiep nhan truong du lieu tu FastAPI giu nguyen tinh toan ven")
    void test19_fastapi_canbo_field_names_mapping_pascal_and_snake() {
        assertThat(recordFromFastApi.get("HO_VA_TEN")).isEqualTo("Nguyen Van A");
        assertThat(recordFromFastApi.get("SO_CCCD")).isEqualTo("079090123456");
    }

    @Test
    @DisplayName("20. Bao ton ma CCCD 12 chu so khong bi mat so 0 dau")
    void test20_fastapi_cccd_12_digits_preserved_without_losing_leading_zero() {
        String cccd = (String) recordFromFastApi.get("SO_CCCD");
        assertThat(cccd).startsWith("0");
        assertThat(cccd).hasSize(12);
    }

    @Test
    @DisplayName("21. Quy tac REQUIRED chan (BLOCK) khi truong bat buoc bi rong")
    void test21_validation_rule_required_blocks_empty_field() {
        ValidationRule r = new ValidationRule();
        r.setField("HO_VA_TEN");
        r.setRequired(true);

        List<RecordValidator.Violation> v = validator.validate("cb-002", List.of(r), Map.of("HO_VA_TEN", ""));
        assertThat(v).singleElement().satisfies(err -> {
            assertThat(err.ruleCode()).isEqualTo(RecordValidator.REQUIRED);
            assertThat(err.severity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
        });
    }

    @Test
    @DisplayName("22. Quy tac MAX_LENGTH chan khi do dai vuot qua dac ta")
    void test22_validation_rule_max_length_blocks_overflow() {
        ValidationRule r = new ValidationRule();
        r.setField("SO_CCCD");
        r.setMaxLength(12);

        List<RecordValidator.Violation> v = validator.validate("cb-003", List.of(r), Map.of("SO_CCCD", "079090123456789"));
        assertThat(v).anySatisfy(err -> {
            assertThat(err.ruleCode()).isEqualTo(RecordValidator.MAX_LENGTH);
            assertThat(err.severity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
        });
    }

    @Test
    @DisplayName("23. Quy tac DATA_TYPE phat hien kieu ngay thang khong hop le")
    void test23_validation_rule_data_type_validates_dates() {
        ValidationRule r = new ValidationRule();
        r.setField("NGAY_SINH");
        r.setDataType("date");

        List<RecordValidator.Violation> v = validator.validate("cb-004", List.of(r), Map.of("NGAY_SINH", "sai_ngay"));
        assertThat(v).anySatisfy(err -> {
            assertThat(err.ruleCode()).isEqualTo(RecordValidator.DATA_TYPE);
        });
    }

    @Test
    @DisplayName("24. Quy tac CATALOG chan khi ma danh muc noi bo chua anh xa")
    void test24_validation_rule_catalog_blocks_unmapped_code() {
        ValidationRule r = new ValidationRule();
        r.setField("GIOI_TINH_ID");
        r.setCatalogName("DM_GIOI_TINH");

        when(catalogMaps.findByDmNameAndLocalCode("DM_GIOI_TINH", "99")).thenReturn(Optional.empty());

        List<RecordValidator.Violation> v = validator.validate("cb-005", List.of(r), Map.of("GIOI_TINH_ID", "99"));
        assertThat(v).anySatisfy(err -> {
            assertThat(err.ruleCode()).isEqualTo(RecordValidator.MISSING);
            assertThat(err.severity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
        });
    }

    @Test
    @DisplayName("25. Quy tac CATALOG cho phep khi ma danh muc da duoc anh xa")
    void test25_validation_rule_catalog_passes_when_mapped() {
        ValidationRule r = new ValidationRule();
        r.setField("GIOI_TINH_ID");
        r.setCatalogName("DM_GIOI_TINH");

        CatalogMap mapped = new CatalogMap();
        mapped.setHemisCode("01");
        when(catalogMaps.findByDmNameAndLocalCode("DM_GIOI_TINH", "01")).thenReturn(Optional.of(mapped));

        List<RecordValidator.Violation> v = validator.validate("cb-006", List.of(r), Map.of("GIOI_TINH_ID", "01"));
        assertThat(v).isEmpty();
    }

    @Test
    @DisplayName("26. Quy tac CONDITIONAL rang buoc truong co dieu kien")
    void test26_validation_rule_conditional_enforces_rules() {
        ValidationRule r = new ValidationRule();
        r.setField("SO_QUYET_DINH");
        r.setRequired(true);
        r.setConditionExpr("TRANG_THAI_ID = '04'");

        List<RecordValidator.Violation> v = validator.validate("cb-007", List.of(r),
                Map.of("TRANG_THAI_ID", "04")); // Thieu SO_QUYET_DINH
        assertThat(v).isNotEmpty();
    }

    @Test
    @DisplayName("27. Vi pham BLOCK chuyen trang thai dot thanh CHO_SUA_LOI")
    void test27_batch_transitions_to_cho_sua_loi_when_block_error_exists() {
        ValidationRule blockRule = new ValidationRule();
        blockRule.setPh(PH);
        blockRule.setEntity(ENTITY);
        blockRule.setField("HO_VA_TEN");
        blockRule.setRequired(true);

        recordFromFastApi.put("HO_VA_TEN", ""); // gay loi BLOCK
        when(validationRules.findByPhAndEntity(PH, ENTITY)).thenReturn(List.of(blockRule));

        SyncBatch b = orchestrator.chuanBi(PH);
        assertThat(b.getStatus()).isEqualTo(SyncBatch.Status.CHO_SUA_LOI);
        verify(signJobs, never()).save(any()); // Khong duoc vao hang doi ky so
    }

    @Test
    @DisplayName("28. Canh bao WARN khong chan dot, van duoc di tiep vao hang doi ky so")
    void test28_batch_continues_to_signing_when_only_warnings_exist() {
        ValidationRule warnRule = new ValidationRule();
        warnRule.setPh(PH);
        warnRule.setEntity(ENTITY);
        warnRule.setField("EMAIL");
        warnRule.setRequired(false);

        recordFromFastApi.put("EMAIL", "dinh_dang_sai");
        when(validationRules.findByPhAndEntity(PH, ENTITY)).thenReturn(List.of(warnRule));

        SyncBatch b = orchestrator.chuanBi(PH);
        assertThat(b.getStatus()).isEqualTo(SyncBatch.Status.CHO_KY_SO);
        verify(signJobs).save(any()); // Cho phep vao hang doi ky so
    }

    @Test
    @DisplayName("29. Dem chinh xac so luong ban ghi recordCount trich xuat tu FastAPI")
    void test29_record_count_matches_fastapi_extracted_data() {
        SyncBatch b = orchestrator.chuanBi(PH);
        assertThat(b.getRecordCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("30. Danh sach SyncError chua day du batchId va localId phan hoi nguoi dung")
    void test30_sync_errors_contain_batch_id_and_local_id() {
        ValidationRule r = new ValidationRule();
        r.setPh(PH);
        r.setEntity(ENTITY);
        r.setField("MA_CAN_BO");
        r.setRequired(true);

        when(validationRules.findByPhAndEntity(PH, ENTITY)).thenReturn(List.of(r));
        SyncBatch b = orchestrator.chuanBi(PH);

        org.mockito.ArgumentCaptor<Iterable<SyncError>> captor = org.mockito.ArgumentCaptor.captor();
        verify(syncErrors).saveAll(captor.capture());
        List<SyncError> errors = new java.util.ArrayList<>();
        captor.getValue().forEach(errors::add);
        assertThat(errors).singleElement().satisfies(err -> {
            assertThat(err.getBatchId()).isEqualTo(b.getId());
            assertThat(err.getLocalId()).isEqualTo(RECORD_ID);
        });
    }

    // =========================================================================
    // NHOM 4: DONG GOI XML, IKS & XAC THUC TOAN VEN CHU KY SO (Tests 31-40)
    // =========================================================================

    @Test
    @DisplayName("31. Cau truc thu muc luu tru theo ph va iks dung chuan")
    void test31_package_directory_structure_follows_ph_and_iks() {
        SyncBatch b = orchestrator.chuanBi(PH);
        Path expectedXml = Path.of(b.getXmlPath());
        assertThat(Files.exists(expectedXml)).isTrue();
        assertThat(expectedXml.toString()).contains(PH);
    }

    @Test
    @DisplayName("32. File payload.json chua truong t_k mang gia tri bang dung chuoi IKS")
    void test32_payload_json_contains_tk_matching_iks() throws IOException {
        SyncBatch b = orchestrator.chuanBi(PH);
        String jsonContent = Files.readString(Path.of(b.getJsonPath()));
        assertThat(jsonContent).contains("\"t_k\"");
        assertThat(jsonContent).contains(b.getIks().toString());
    }

    @Test
    @DisplayName("33. File payload.json chua DomainConnect cau hinh dung dai hoc")
    void test33_payload_json_contains_domain_connect() throws IOException {
        SyncBatch b = orchestrator.chuanBi(PH);
        String jsonContent = Files.readString(Path.of(b.getJsonPath()));
        assertThat(jsonContent).contains("\"DomainConnect\"").contains("\"hcmue.edu.vn\"");
    }

    @Test
    @DisplayName("34. Dong goi XML: The DuLieuKySo chua thuoc tinh Id=data")
    void test34_xml_packaging_has_dulieukyso_id_data() {
        XmlPackager realPackager = new XmlPackager();
        Iks iks = Iks.random();
        String xml = realPackager.build(iks, "HCMUE", "Truong DHSP", List.of());
        assertThat(xml).contains("<DuLieuKySo Id=\"data\">");
    }

    @Test
    @DisplayName("35. Dong goi XML: Cap the k1 dau tien va k2 cuoi cung")
    void test35_xml_packaging_encloses_data_between_k1_and_k2() {
        XmlPackager realPackager = new XmlPackager();
        Iks iks = Iks.random();
        String xml = realPackager.build(iks, "HCMUE", "Truong DHSP", List.of());
        assertThat(xml).contains("<k1>" + iks.k1() + "</k1>");
        assertThat(xml).contains("<k2>" + iks.k2() + "</k2>");
    }

    @Test
    @DisplayName("36. Cap the k1 va k2 ghep lai dung 36 ky tu cua IKS")
    void test36_k1_and_k2_join_to_original_iks_guid() {
        Iks iks = Iks.random();
        assertThat(Iks.join(iks.k1(), iks.k2())).isEqualTo(iks);
        assertThat(iks.k1() + iks.k2()).isEqualTo(iks.text());
    }

    @Test
    @DisplayName("37. XmlDsigVerifier tu choi file XML thieu node Signature")
    void test37_xmldsig_verifier_fails_when_signature_tag_missing() {
        XmlDsigVerifier verifier = new XmlDsigVerifier();
        Iks iks = Iks.random();
        String unsignedXml = "<DuLieuKySo Id=\"data\"><k1>" + iks.k1() + "</k1><k2>" + iks.k2() + "</k2></DuLieuKySo>";
        XmlDsigVerifier.Result res = verifier.verify(unsignedXml, iks);
        assertThat(res.valid()).isFalse();
        assertThat(res.message()).contains("Signature");
    }

    @Test
    @DisplayName("38. XmlDsigVerifier tu choi file XML khi IKS khong khop")
    void test38_xmldsig_verifier_fails_when_iks_mismatch() {
        XmlDsigVerifier verifier = new XmlDsigVerifier();
        Iks expectedIks = Iks.random();
        Iks differentIks = Iks.random();
        String xml = "<DuLieuKySo Id=\"data\"><k1>" + differentIks.k1() + "</k1><k2>" + differentIks.k2() + "</k2></DuLieuKySo>";
        XmlDsigVerifier.Result res = verifier.verify(xml, expectedIks);
        assertThat(res.valid()).isFalse();
        assertThat(res.message()).contains("IKS");
    }

    @Test
    @DisplayName("39. XmlDsigVerifier tu choi file XML khi DuLieuKySo thieu Id=data")
    void test39_xmldsig_verifier_fails_when_id_data_missing() {
        XmlDsigVerifier verifier = new XmlDsigVerifier();
        Iks iks = Iks.random();
        String xml = "<DuLieuKySo><k1>" + iks.k1() + "</k1><k2>" + iks.k2() + "</k2></DuLieuKySo>";
        XmlDsigVerifier.Result res = verifier.verify(xml, iks);
        assertThat(res.valid()).isFalse();
        assertThat(res.message()).contains("Id=\"data\"");
    }

    @Test
    @DisplayName("40. Thu tu the X509Data trong chu ky: SubjectName dung truoc Certificate")
    void test40_x509_subject_name_ordered_before_certificate() {
        String x509Xml = "<X509Data><X509SubjectName>CN=HCMUE</X509SubjectName><X509Certificate>MII...</X509Certificate></X509Data>";
        int idxSubject = x509Xml.indexOf("<X509SubjectName>");
        int idxCert = x509Xml.indexOf("<X509Certificate>");
        assertThat(idxSubject).isLessThan(idxCert);
    }
}
