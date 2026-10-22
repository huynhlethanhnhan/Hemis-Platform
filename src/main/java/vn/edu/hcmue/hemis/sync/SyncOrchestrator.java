package vn.edu.hcmue.hemis.sync;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tools.jackson.databind.ObjectMapper;

import vn.edu.hcmue.hemis.client.HemisResponse;
import vn.edu.hcmue.hemis.client.HemisSyncClient;
import vn.edu.hcmue.hemis.config.HemisProperties;
import vn.edu.hcmue.hemis.journal.ApiLog;
import vn.edu.hcmue.hemis.journal.ApiLogRepository;
import vn.edu.hcmue.hemis.journal.SyncBatch;
import vn.edu.hcmue.hemis.journal.SyncBatchRepository;
import vn.edu.hcmue.hemis.journal.SyncError;
import vn.edu.hcmue.hemis.journal.SyncErrorRepository;
import vn.edu.hcmue.hemis.journal.ValidationRuleRepository;
import vn.edu.hcmue.hemis.packaging.Iks;
import vn.edu.hcmue.hemis.packaging.XmlPackager;
import vn.edu.hcmue.hemis.signing.SignJob;
import vn.edu.hcmue.hemis.signing.SignJobRepository;
import vn.edu.hcmue.hemis.staging.PhanHeExtractor;
import vn.edu.hcmue.hemis.validation.RecordValidator;

/**
 * Dieu phoi mot dot dong bo. Chia lam HAI buoc tach biet, co the chay cach nhau:
 *
 * <ol>
 *   <li>{@link #chuanBi} - trich xuat, dong goi, dua vao hang doi ky so.
 *       Ket thuc o trang thai CHO_KY_SO.</li>
 *   <li>{@link #gui} - sau khi tep da duoc ky, nop db16 roi goi dbN.
 *       Ket thuc o trang thai DA_GUI_JSON.</li>
 * </ol>
 *
 * <p>Tach hai buoc vi giua chung co hanh dong cua con nguoi (lanh dao phe duyet, cam USB
 * token, nhap ma PIN). Khong duoc gop thanh mot lenh chay thang.
 */
@Service
public class SyncOrchestrator {

    private static final Logger log = LoggerFactory.getLogger(SyncOrchestrator.class);

    private final List<PhanHeExtractor> extractors;
    private final XmlPackager xmlPackager;
    private final HemisSyncClient syncClient;
    private final SyncBatchRepository batches;
    private final SignJobRepository signJobs;
    private final ApiLogRepository apiLogs;
    private final HemisProperties props;
    private final ObjectMapper objectMapper;
    private final RecordValidator validator;
    private final ValidationRuleRepository validationRules;
    private final SyncErrorRepository syncErrors;

    public SyncOrchestrator(List<PhanHeExtractor> extractors, XmlPackager xmlPackager,
                            HemisSyncClient syncClient, SyncBatchRepository batches,
                            SignJobRepository signJobs, ApiLogRepository apiLogs,
                            HemisProperties props, ObjectMapper objectMapper,
                            RecordValidator validator, ValidationRuleRepository validationRules,
                            SyncErrorRepository syncErrors) {
        this.extractors = extractors;
        this.xmlPackager = xmlPackager;
        this.syncClient = syncClient;
        this.batches = batches;
        this.signJobs = signJobs;
        this.apiLogs = apiLogs;
        this.props = props;
        this.objectMapper = objectMapper;
        this.validator = validator;
        this.validationRules = validationRules;
        this.syncErrors = syncErrors;
    }

    // =================================================================
    // Buoc 1: chuan bi dot - trich xuat, dong goi, dua vao hang doi ky so
    // =================================================================
    @Transactional
    public SyncBatch chuanBi(String ph) {
        PhanHeExtractor extractor = extractors.stream()
                .filter(e -> e.ph().equalsIgnoreCase(ph))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Chua co bo trich xuat cho phan he " + ph));

        Iks iks = Iks.random();
        UUID idKey = UUID.randomUUID();

        SyncBatch batch = new SyncBatch();
        batch.setPh(extractor.ph());
        batch.setApi(extractor.api());
        batch.setIks(iks.value());
        batch.setIdKey(idKey);
        batch.setDonViId(UUID.fromString(props.donViId()));
        batch.setStatus(SyncBatch.Status.KHOI_TAO);
        batch = batches.save(batch);

        // 1. Trich xuat
        PhanHeExtractor.Result data = extractor.extract();
        batch.setRecordCount(data.recordCount());

        // 2. Kiem tra tung ban ghi, luu moi vi pham thanh mot dong sync_error.
        List<SyncError> errors = kiemTraBanGhi(batch, extractor.ph(), data.jsonBody());
        SyncBatch batchForLog = batch;
        if (!errors.isEmpty()) {
            errors.stream().filter(e -> RecordValidator.SEVERITY_WARN.equals(e.getSeverity()))
                .forEach(e -> log.warn("Canh bao dong bo batch {}: {}", batchForLog.getId(), e.getMessage()));
        }
        boolean hasBlock = errors.stream()
                .anyMatch(e -> RecordValidator.SEVERITY_BLOCK.equals(e.getSeverity()));
        if (hasBlock) {
            batch.setStatus(SyncBatch.Status.CHO_SUA_LOI);
            batch.setMessage("Có " + errors.stream()
                    .filter(e -> RecordValidator.SEVERITY_BLOCK.equals(e.getSeverity())).count()
                    + " lỗi BLOCK; cần sửa dữ liệu nguồn trước khi đóng gói");
            return batches.save(batch);
        }

        // 3. Dong goi XML (chua ky) va JSON
        String xml = xmlPackager.build(iks, props.maDonVi(), props.tenDonVi(), data.xmlLists());

        Map<String, Object> jsonBody = new LinkedHashMap<>();
        jsonBody.put("t_k", iks.text());                      // ma phien ky so da xac thuc o db16
        jsonBody.put("DomainConnect", props.domainConnect());
        jsonBody.putAll(data.jsonBody());

        Path dir = Path.of(props.signing().storageDir(), extractor.ph(), iks.text());
        Path xmlPath = dir.resolve("payload.xml");
        Path jsonPath = dir.resolve("payload.json");
        writeFile(xmlPath, xml);
        writeFile(jsonPath, toJson(jsonBody));

        batch.setXmlPath(xmlPath.toString());
        batch.setJsonPath(jsonPath.toString());
        batch.setPayloadSha256(sha256(xml));
        batch.setStatus(SyncBatch.Status.DA_DONG_GOI);

        // 4. Dua vao hang doi ky so
        SignJob job = new SignJob();
        job.setBatchId(batch.getId());
        job.setXmlPath(xmlPath.toString());
        job.setStatus(SignJob.Status.PENDING);
        signJobs.save(job);

        batch.setStatus(SyncBatch.Status.CHO_KY_SO);
        batches.save(batch);

        log.info("Da chuan bi dot {} phan he {} - {} ban ghi, IKS={}, cho ky so",
                batch.getId(), batch.getPh(), batch.getRecordCount(), iks.text());
        return batch;
    }

    // =================================================================
    // Buoc 2: gui - db16 (XML da ky) roi dbN (JSON)
    // =================================================================
    @Transactional
    public SyncBatch gui(Long batchId) {
        SyncBatch batch = batches.findById(batchId)
                .orElseThrow(() -> new IllegalArgumentException("Khong tim thay dot " + batchId));

        if (batch.getStatus() != SyncBatch.Status.DA_KY_SO) {
            throw new IllegalStateException(
                    "Dot " + batchId + " dang o trang thai " + batch.getStatus()
                    + ", chi duoc gui khi da ky so");
        }

        Iks iks = new Iks(batch.getIks());

        // --- Buoc 2a: db16 - nop tep XML da ky ---
        String signedXml = readFile(batch.getSignedXmlPath());
        long t0 = System.currentTimeMillis();
        try {
            HemisResponse res = syncClient.uploadSignedXml(iks.value(), batch.getPh(), signedXml);
            ghiNhatKy(batch, "POST", "db16/" + batch.getPh(), res, signedXml.length(),
                    System.currentTimeMillis() - t0, null);
            res.requireSuccess("Nop tep XML da ky (db16)");
            batch.setStatus(SyncBatch.Status.DA_GUI_XML);
            batches.save(batch);
        } catch (RuntimeException e) {
            ghiNhatKy(batch, "POST", "db16/" + batch.getPh(), null, signedXml.length(),
                    System.currentTimeMillis() - t0, e.getMessage());
            batch.setStatus(SyncBatch.Status.THAT_BAI);
            batch.setMessage("db16 that bai: " + e.getMessage());
            batches.save(batch);
            throw e;
        }

        // --- Buoc 2b: dbN - gui than JSON voi t_k = IKS ---
        Map<String, Object> jsonBody = readJson(batch.getJsonPath());
        t0 = System.currentTimeMillis();
        try {
            HemisResponse res = syncClient.syncJson(batch.getApi(), batch.getIdKey(), jsonBody);
            ghiNhatKy(batch, "POST", batch.getApi(), res, 0, System.currentTimeMillis() - t0, null);
            res.requireSuccess("Dong bo " + batch.getApi());
            batch.setStatus(SyncBatch.Status.DA_GUI_JSON);
            batch.setSentAt(OffsetDateTime.now());
            batch.setMessage("Gui thanh cong");
            batches.save(batch);
        } catch (RuntimeException e) {
            ghiNhatKy(batch, "POST", batch.getApi(), null, 0, System.currentTimeMillis() - t0, e.getMessage());
            batch.setStatus(SyncBatch.Status.THAT_BAI);
            batch.setMessage(batch.getApi() + " that bai: " + e.getMessage());
            batches.save(batch);
            throw e;
        }

        log.info("Dot {} da gui xong. Buoc tiep theo: doi soat tren giao dien HEMIS trong 03 ngay lam viec",
                batch.getId());
        return batch;
    }

    // -----------------------------------------------------------------

    private void ghiNhatKy(SyncBatch batch, String method, String url, HemisResponse res,
                           long bytes, long durationMs, String error) {
        ApiLog logEntry = new ApiLog();
        logEntry.setBatchId(batch.getId());
        logEntry.setMethod(method);
        logEntry.setUrl(url);
        logEntry.setRequestBytes(bytes);
        logEntry.setDurationMs(durationMs);
        logEntry.setSuccess(res != null && res.success());
        logEntry.setError(error);
        if (res != null) {
            logEntry.setResponseBodyTruncated(
                    "success=" + res.success() + ", message=" + res.message(), 2000);
        }
        apiLogs.save(logEntry);
    }

    private List<SyncError> kiemTraBanGhi(SyncBatch batch, String ph, Map<String, Object> jsonBody) {
        List<SyncError> errors = new java.util.ArrayList<>();
        for (Map.Entry<String, Object> entry : jsonBody.entrySet()) {
            String entity = entry.getKey();
            List<Map<String, Object>> records = records(entry.getValue());
            if (records.isEmpty()) {
                continue;
            }
            var rules = validationRules.findByPhAndEntity(ph, entity);
            for (Map<String, Object> record : records) {
                Object id = record.containsKey("Id") ? record.get("Id") : record.get("local_id");
                String localId = id == null ? null : String.valueOf(id);
                for (RecordValidator.Violation violation : validator.validate(localId, rules, record)) {
                    SyncError error = new SyncError();
                    error.setBatchId(batch.getId());
                    error.setEntity(entity);
                    error.setLocalId(violation.localId());
                    error.setField(violation.field());
                    error.setRuleCode(violation.ruleCode());
                    error.setSeverity(violation.severity());
                    error.setMessage(violation.message());
                    errors.add(error);
                }
            }
        }
        return syncErrors.saveAll(errors);
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> records(Object value) {
        if (value instanceof Map<?, ?> map) {
            return List.of((Map<String, Object>) map);
        }
        if (value instanceof List<?> list) {
            return list.stream().filter(Map.class::isInstance)
                    .map(item -> (Map<String, Object>) item).toList();
        }
        return List.of();
    }

    private String toJson(Map<String, Object> body) {
        try {
            return objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(body);
        } catch (Exception e) {
            throw new IllegalStateException("Khong chuyen duoc sang JSON", e);
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> readJson(String path) {
        try {
            return objectMapper.readValue(Path.of(path).toFile(), Map.class);
        } catch (Exception e) {
            throw new IllegalStateException("Khong doc duoc tep JSON " + path, e);
        }
    }

    private static void writeFile(Path path, String content) {
        try {
            Files.createDirectories(path.getParent());
            Files.writeString(path, content, StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new IllegalStateException("Khong ghi duoc tep " + path, e);
        }
    }

    private static String readFile(String path) {
        try {
            return Files.readString(Path.of(path), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new IllegalStateException("Khong doc duoc tep " + path, e);
        }
    }

    private static String sha256(String content) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(md.digest(content.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            return null;
        }
    }
}
