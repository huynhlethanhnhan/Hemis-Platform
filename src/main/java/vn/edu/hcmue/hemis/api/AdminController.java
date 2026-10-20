package vn.edu.hcmue.hemis.api;

import java.util.List;
import java.util.Map;

import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import vn.edu.hcmue.hemis.client.HemisAuthClient;
import vn.edu.hcmue.hemis.client.HemisCatalogClient;
import vn.edu.hcmue.hemis.journal.ApiLog;
import vn.edu.hcmue.hemis.journal.ApiLogRepository;
import vn.edu.hcmue.hemis.journal.SyncBatch;
import vn.edu.hcmue.hemis.journal.SyncBatchRepository;
import vn.edu.hcmue.hemis.sync.SyncOrchestrator;

/**
 * API quan tri cho man hinh theo doi dong bo.
 *
 * <p>Giai doan 1 chi can muc toi thieu. Giai doan 2 bo sung xac thuc SSO va phan quyen;
 * hien tai duong dan nay PHAI duoc chan o reverse proxy, chi mo trong mang noi bo.
 */
@RestController
@RequestMapping("/api/v1/hemis")
public class AdminController {

    private final SyncOrchestrator orchestrator;
    private final SyncBatchRepository batches;
    private final ApiLogRepository apiLogs;
    private final HemisAuthClient auth;
    private final HemisCatalogClient catalog;

    public AdminController(SyncOrchestrator orchestrator, SyncBatchRepository batches,
                           ApiLogRepository apiLogs, HemisAuthClient auth,
                           HemisCatalogClient catalog) {
        this.orchestrator = orchestrator;
        this.batches = batches;
        this.apiLogs = apiLogs;
        this.auth = auth;
        this.catalog = catalog;
    }

    /** Kiem tra nhanh ket noi toi may chu SSO cua Bo. */
    @GetMapping("/kiem-tra-token")
    public Map<String, Object> kiemTraToken() {
        String token = auth.accessToken();
        return Map.of(
                "ketNoi", "thanh cong",
                "doDaiToken", token.length(),
                "trichYeu", token.substring(0, Math.min(24, token.length())) + "...");
    }

    /** Tai danh muc dung chung, luu vao catalog_hemis, tra ve so luong. */
    @PostMapping("/danh-muc/tai-ve")
    public Map<String, Object> taiDanhMuc() {
        var result = catalog.fetchAndStore();
        var res = result.response();
        List<String> tenDanhMuc = res.data() == null
                ? List.of()
                : res.data().propertyNames().stream().sorted().limit(20).toList();
        return Map.of(
                "success", res.success(),
                "soDanhMuc", res.data() == null ? 0 : res.data().size(),
                "soBanGhiLuu", result.saved(),
                "tenDanhMucDauTien", tenDanhMuc);
    }

    /** Buoc 1: chuan bi mot dot dong bo (trich xuat, dong goi, dua vao hang doi ky so). */
    @PostMapping("/dot/{ph}/chuan-bi")
    public SyncBatch chuanBi(@PathVariable String ph) {
        return orchestrator.chuanBi(ph);
    }

    /** Buoc 2: gui dot da ky so len HEMIS (db16 roi dbN). */
    @PostMapping("/dot/{id}/gui")
    public SyncBatch gui(@PathVariable Long id) {
        return orchestrator.gui(id);
    }

    /** Danh sach dot dong bo gan nhat. */
    @GetMapping("/dot")
    public List<SyncBatch> danhSach(@RequestParam(defaultValue = "COSOGIAODUC") String ph,
                                    @RequestParam(defaultValue = "20") int limit) {
        return batches.findByPhOrderByCreatedAtDesc(ph, PageRequest.of(0, limit));
    }

    /** Chi tiet mot dot. */
    @GetMapping("/dot/{id}")
    public SyncBatch chiTiet(@PathVariable Long id) {
        return batches.findById(id).orElseThrow();
    }

    /** Nhat ky goi API cua mot dot - dung khi doi soat va xu ly su co. */
    @GetMapping("/dot/{id}/nhat-ky")
    public List<ApiLog> nhatKy(@PathVariable Long id) {
        return apiLogs.findByBatchIdOrderByCreatedAtAsc(id);
    }
}
