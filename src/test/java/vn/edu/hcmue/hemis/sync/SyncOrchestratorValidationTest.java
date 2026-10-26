package vn.edu.hcmue.hemis.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.nio.file.Path;
import java.nio.file.Files;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import tools.jackson.databind.ObjectMapper;
import vn.edu.hcmue.hemis.client.HemisSyncClient;
import vn.edu.hcmue.hemis.config.HemisProperties;
import vn.edu.hcmue.hemis.journal.ApiLogRepository;
import vn.edu.hcmue.hemis.journal.CatalogMapRepository;
import vn.edu.hcmue.hemis.journal.SyncBatch;
import vn.edu.hcmue.hemis.journal.SyncBatchRepository;
import vn.edu.hcmue.hemis.journal.SyncError;
import vn.edu.hcmue.hemis.journal.SyncErrorRepository;
import vn.edu.hcmue.hemis.journal.ValidationRule;
import vn.edu.hcmue.hemis.journal.ValidationRuleRepository;
import vn.edu.hcmue.hemis.packaging.XmlPackager;
import vn.edu.hcmue.hemis.signing.SignJobRepository;
import vn.edu.hcmue.hemis.staging.PhanHeExtractor;
import vn.edu.hcmue.hemis.validation.RecordValidator;

class SyncOrchestratorValidationTest {

    private static final String ENTITY = "_CO_SO_GIAO_DUC";
    private static final String RECORD_ID = "csgd-42";

    @TempDir
    Path tempDir;

    private SyncBatchRepository batches;
    private SignJobRepository signJobs;
    private SyncErrorRepository syncErrors;
    private ValidationRuleRepository validationRules;
    private RecordValidator validator;
    private XmlPackager xmlPackager;
    private SyncOrchestrator orchestrator;
    private Map<String, Object> record;

    @BeforeEach
    void setUp() throws IOException {
        Path packageDir = Files.createDirectories(tempDir.resolve("packages"));
        batches = mock(SyncBatchRepository.class);
        signJobs = mock(SignJobRepository.class);
        syncErrors = mock(SyncErrorRepository.class);
        validationRules = mock(ValidationRuleRepository.class);
        xmlPackager = mock(XmlPackager.class);
        when(xmlPackager.build(any(), any(), any(), any())).thenReturn("<payload/>");
        CatalogMapRepository catalogMaps = mock(CatalogMapRepository.class);
        validator = new RecordValidator(catalogMaps);

        when(batches.save(any(SyncBatch.class))).thenAnswer(invocation -> {
            SyncBatch batch = invocation.getArgument(0);
            if (batch.getId() == null) {
                batch.setId(17L);
            }
            return batch;
        });
        when(syncErrors.saveAll(org.mockito.ArgumentMatchers.<Iterable<SyncError>>any()))
            .thenAnswer(invocation -> {
            List<SyncError> errors = new java.util.ArrayList<>();
            invocation.<Iterable<SyncError>>getArgument(0).forEach(errors::add);
            return errors;
        });

        record = new LinkedHashMap<>();
        record.put("Id", RECORD_ID);
        PhanHeExtractor extractor = new PhanHeExtractor() {
            @Override public String ph() { return "COSOGIAODUC"; }
            @Override public String api() { return "db1"; }
            @Override public Result extract() {
                return new Result(List.of(), Map.of(ENTITY, record), 1);
            }
        };

        HemisProperties props = new HemisProperties(
                "", "", null, null, "11111111-2222-3333-4444-555555555555",
                "HCMUE", "Truong", "", null, null, null,
                new HemisProperties.Signing("agent", packageDir.toString(), true, null));
        orchestrator = new SyncOrchestrator(List.of(extractor), xmlPackager,
                mock(HemisSyncClient.class), batches, signJobs,
                mock(ApiLogRepository.class), props, new ObjectMapper(), validator,
                validationRules, syncErrors);
    }

    @Test
    void nganChanViPhamTruocKhiDongGoiVaKySo() {
        record.put("TRANG_THAI_ID", "04");
        ValidationRule required = rule("TEN_DON_VI");
        required.setRequired(true);
        required.setConditionExpr("TRANG_THAI_ID = '04'");
        when(validationRules.findByPhAndEntity("COSOGIAODUC", ENTITY)).thenReturn(List.of(required));

        SyncBatch batch = orchestrator.chuanBi("COSOGIAODUC");

        assertThat(batch.getStatus()).isEqualTo(SyncBatch.Status.CHO_SUA_LOI);
        assertThat(batch.getMessage()).contains("2 lỗi BLOCK");
        org.mockito.ArgumentCaptor<Iterable<SyncError>> captor = org.mockito.ArgumentCaptor.captor();
        verify(syncErrors).saveAll(captor.capture());
        List<SyncError> saved = new java.util.ArrayList<>();
        captor.getValue().forEach(saved::add);
        assertThat(saved).hasSize(2).allSatisfy(error -> {
            assertThat(error.getBatchId()).isEqualTo(batch.getId());
            assertThat(error.getEntity()).isEqualTo(ENTITY);
            assertThat(error.getLocalId()).isEqualTo(RECORD_ID);
            assertThat(error.getField()).isEqualTo("TEN_DON_VI");
            assertThat(error.getSeverity()).isEqualTo(RecordValidator.SEVERITY_BLOCK);
            assertThat(error.getMessage()).contains(RECORD_ID, "TEN_DON_VI");
            assertThat(error.getOwnerUnit()).isNull();
        });
        assertThat(saved).extracting(SyncError::getRuleCode)
                .containsExactlyInAnyOrder(RecordValidator.REQUIRED, RecordValidator.CONDITIONAL);
        verify(xmlPackager, never()).build(any(), any(), any(), any());
        verify(signJobs, never()).save(any());
    }

    @Test
    void warningIsStoredAndBatchContinuesToSigningQueue() {
        record.put("EMAIL", "not-an-email");
        when(validationRules.findByPhAndEntity("COSOGIAODUC", ENTITY))
                .thenReturn(List.of(rule("EMAIL")));

        SyncBatch batch = orchestrator.chuanBi("COSOGIAODUC");

        assertThat(batch.getStatus()).isEqualTo(SyncBatch.Status.CHO_KY_SO);
        verify(syncErrors).saveAll(org.mockito.ArgumentMatchers.<Iterable<SyncError>>any());
        verify(xmlPackager).build(any(), any(), any(), any());
        verify(signJobs).save(any());
    }

    private static ValidationRule rule(String field) {
        ValidationRule rule = new ValidationRule();
        rule.setPh("COSOGIAODUC");
        rule.setEntity(ENTITY);
        rule.setField(field);
        rule.setRequired(false);
        return rule;
    }
}
