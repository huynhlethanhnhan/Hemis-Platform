package vn.edu.hcmue.hemis.signing;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.edu.hcmue.hemis.config.HemisProperties;
import vn.edu.hcmue.hemis.journal.SyncBatch;
import vn.edu.hcmue.hemis.journal.SyncBatchRepository;
import vn.edu.hcmue.hemis.packaging.Iks;

/**
 * API noi bo danh RIENG cho tac nhan ky so chay tren tram ky so.
 *
 * <p>Quy trinh cua tac nhan (lap lai moi vai giay):
 * <ol>
 *   <li>{@code GET  /internal/sign/jobs}        - lay danh sach viec dang cho</li>
 *   <li>{@code POST /internal/sign/jobs/{id}/lease} - nhan viec, tra ve noi dung XML chua ky</li>
 *   <li>goi plugin tai {@code http://127.0.0.1:64005} de ky bang USB token</li>
 *   <li>{@code POST /internal/sign/jobs/{id}/result} - tra ve XML da ky</li>
 * </ol>
 *
 * <p>Bao ve bang mot token dung chung ({@code hemis.signing.agent-token}) truyen trong
 * header {@code X-Agent-Token}. Duong dan nay chi duoc mo trong mang noi bo, khong
 * duoc expose ra ngoai reverse proxy.
 */
@RestController
@RequestMapping("/internal/sign")
public class SignAgentController {

    private static final Logger log = LoggerFactory.getLogger(SignAgentController.class);

    private final SignJobRepository jobs;
    private final SyncBatchRepository batches;
    private final XmlDsigVerifier verifier;
    private final HemisProperties props;

    public SignAgentController(SignJobRepository jobs, SyncBatchRepository batches,
                               XmlDsigVerifier verifier, HemisProperties props) {
        this.jobs = jobs;
        this.batches = batches;
        this.verifier = verifier;
        this.props = props;
    }

    public record JobSummary(Long id, Long batchId, String ph, OffsetDateTime createdAt) {
    }

    public record LeasedJob(Long id, Long batchId, String ph, String iks, String xml) {
    }

    public record SignResult(String signedXml, String error) {
    }

    /** Danh sach viec dang cho ky. */
    @GetMapping("/jobs")
    public List<JobSummary> pending(@RequestHeader(value = "X-Agent-Token", required = false) String token) {
        checkToken(token);
        return jobs.findByStatusOrderByCreatedAtAsc(SignJob.Status.PENDING, PageRequest.of(0, 10))
                .stream()
                .map(j -> new JobSummary(j.getId(), j.getBatchId(),
                        batches.findById(j.getBatchId()).map(SyncBatch::getPh).orElse("?"),
                        j.getCreatedAt()))
                .toList();
    }

    /** Nhan mot viec va lay noi dung XML chua ky. */
    @PostMapping("/jobs/{id}/lease")
    @Transactional
    public ResponseEntity<LeasedJob> lease(@PathVariable Long id,
                                           @RequestHeader(value = "X-Agent-Token", required = false) String token,
                                           @RequestHeader(value = "X-Agent-Name", defaultValue = "tram-ky-so") String agent) {
        checkToken(token);
        Optional<SignJob> found = jobs.findById(id);
        if (found.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        SignJob job = found.get();
        if (job.getStatus() != SignJob.Status.PENDING) {
            return ResponseEntity.status(HttpStatus.CONFLICT).build();
        }

        job.setStatus(SignJob.Status.LEASED);
        job.setLeasedBy(agent);
        job.setLeasedAt(OffsetDateTime.now());
        job.setAttempts(job.getAttempts() + 1);
        jobs.save(job);

        SyncBatch batch = batches.findById(job.getBatchId()).orElseThrow();
        String xml = readFile(job.getXmlPath());

        log.info("Tac nhan {} nhan viec ky so #{} (dot {}, phan he {})",
                agent, id, batch.getId(), batch.getPh());

        return ResponseEntity.ok(new LeasedJob(job.getId(), batch.getId(), batch.getPh(),
                batch.getIks().toString(), xml));
    }

    /** Nhan ket qua ky so tu tac nhan; tu xac minh lai truoc khi chap nhan. */
    @PostMapping("/jobs/{id}/result")
    @Transactional
    public ResponseEntity<String> result(@PathVariable Long id,
                                          @RequestHeader(value = "X-Agent-Token", required = false) String token,
                                          @RequestBody SignResult body) {
        checkToken(token);
        SignJob job = jobs.findById(id).orElseThrow();
        SyncBatch batch = batches.findById(job.getBatchId()).orElseThrow();

        if (body.error() != null && !body.error().isBlank()) {
            job.setStatus(SignJob.Status.FAILED);
            job.setError(body.error());
            jobs.save(job);
            batch.setStatus(SyncBatch.Status.THAT_BAI);
            batch.setMessage("Ky so that bai: " + body.error());
            batches.save(batch);
            log.error("Ky so that bai cho dot {}: {}", batch.getId(), body.error());
            return ResponseEntity.ok("Da ghi nhan loi");
        }

        // Tu xac minh lai chu ky va cau truc tep truoc khi chap nhan
        if (props.signing().verifyBeforeSend()) {
            XmlDsigVerifier.Result check = verifier.verify(body.signedXml(), new Iks(batch.getIks()));
            if (!check.valid()) {
                job.setStatus(SignJob.Status.FAILED);
                job.setError(check.message());
                jobs.save(job);
                log.error("Tep da ky khong dat kiem tra: {}", check.message());
                return ResponseEntity.badRequest().body("Khong dat: " + check.message());
            }
            batch.setSignerSubject(check.signerSubject());
        }

        Path signed = Path.of(job.getXmlPath().replace(".xml", ".signed.xml"));
        writeFile(signed, body.signedXml());

        job.setStatus(SignJob.Status.SIGNED);
        job.setSignedPath(signed.toString());
        jobs.save(job);

        batch.setSignedXmlPath(signed.toString());
        batch.setSignedAt(OffsetDateTime.now());
        batch.setStatus(SyncBatch.Status.DA_KY_SO);
        batches.save(batch);

        log.info("Dot {} da ky so xong, nguoi ky: {}", batch.getId(), batch.getSignerSubject());
        return ResponseEntity.ok("Da nhan tep da ky");
    }

    // -----------------------------------------------------------------

    private void checkToken(String token) {
        String expected = props.signing().agentToken();
        if (expected == null || expected.isBlank() || !expected.equals(token)) {
            throw new org.springframework.web.server.ResponseStatusException(
                    HttpStatus.UNAUTHORIZED, "Token cua tac nhan ky so khong hop le");
        }
    }

    private static String readFile(String path) {
        try {
            return Files.readString(Path.of(path), StandardCharsets.UTF_8);
        } catch (Exception e) {
            throw new IllegalStateException("Khong doc duoc tep " + path, e);
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
}
