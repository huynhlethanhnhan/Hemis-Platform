package vn.edu.hcmue.hemis.client;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;
import java.util.zip.GZIPOutputStream;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

import tools.jackson.databind.ObjectMapper;

import vn.edu.hcmue.hemis.config.HemisProperties;

/**
 * Goi hai API dong bo cua HEMIS theo dung thu tu quy dinh trong dac ta:
 *
 * <ol>
 *   <li>{@link #uploadSignedXml} - db16: nop tep XML da ky so, khoa phien la IKS</li>
 *   <li>{@link #syncJson}        - db1..db13: gui than JSON voi {@code t_k = IKS}</li>
 * </ol>
 *
 * <p>IKS phai la DUY NHAT cho moi dot. Gui lai cung mot IKS se bi HEMIS tu choi
 * voi loi "Du lieu da ton tai" - day chinh la co che chong gui trung, khong duoc
 * sinh lai IKS khi thu lai mot dot da nop thanh cong o buoc db16.
 */
@Component
public class HemisSyncClient {

    private static final Logger log = LoggerFactory.getLogger(HemisSyncClient.class);

    private final RestClient gateway;
    private final HemisAuthClient auth;
    private final HemisProperties props;
    private final ObjectMapper objectMapper;

    public HemisSyncClient(RestClient gatewayRestClient, HemisAuthClient auth,
                           HemisProperties props, ObjectMapper objectMapper) {
        this.gateway = gatewayRestClient;
        this.auth = auth;
        this.props = props;
        this.objectMapper = objectMapper;
    }

    /**
     * db16 - nop tep XML da ky so.
     *
     * @param iks      ma phien ky so (Guid); phai trung voi k1+k2 ben trong tep XML
     * @param ph       phan he: COSOGIAODUC, CANBO, HOIDONG, NGANHDT, DAOTAO, TUYENSINH,
     *                 HOCVIEN, VANBANG, NCKH, COSOVATCHAT, TAISAN, HTQT, HTDN
     * @param signedXml noi dung tep XML da ky
     */
    public HemisResponse uploadSignedXml(UUID iks, String ph, String signedXml) {
        byte[] payload = encodePayload(signedXml);
        String filename = "hemis-" + ph + "-" + iks + ".xml" + (props.upload().gzip() ? ".gz" : "");

        MultiValueMap<String, Object> form = new LinkedMultiValueMap<>();
        form.add("file", new NamedByteArrayResource(payload, filename));

        String url = props.paths().xmlUpload();
        long t0 = System.currentTimeMillis();

        HemisResponse res = withRetry(() -> gateway.post()
                .uri(url, props.donViId(), iks.toString(), ph)
                .header(HttpHeaders.AUTHORIZATION, auth.bearer())
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(form)
                .retrieve()
                .body(HemisResponse.class));

        log.info("db16 [{}] iks={} kich thuoc={} byte, {} ms -> success={}",
                ph, iks, payload.length, System.currentTimeMillis() - t0,
                res != null && res.success());

        if (res == null) {
            throw new HemisResponse.HemisApiException("db16 khong tra ve du lieu");
        }
        return res;
    }

    /**
     * db1..db13 - gui than JSON cua phan he.
     *
     * @param api    ma API: db1 (co so giao duc), db2 (hoi dong), db3 (doi ngu),
     *               db4 (nganh), db5 (chuong trinh dao tao), db6 (tuyen sinh),
     *               db7 (nguoi hoc), db9 (co so vat chat), db10 (NCKH),
     *               db11 (tai chinh, tai san), db12 (HTQT), db13 (HTDN)
     * @param idKey  ma phien dong bo do ben goi tu sinh, dung tra cuu nhat ky
     * @param body   than JSON; bat buoc co {@code t_k} = IKS da xac thuc o db16
     */
    public HemisResponse syncJson(String api, UUID idKey, Map<String, Object> body) {
        String url = props.paths().jsonSync();
        long t0 = System.currentTimeMillis();

        HemisResponse res = withRetry(() -> gateway.post()
                .uri(url, api, props.donViId(), idKey.toString())
                .header(HttpHeaders.AUTHORIZATION, auth.bearer())
                .contentType(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(HemisResponse.class));

        log.info("{} idKey={} {} ms -> success={}", api, idKey,
                System.currentTimeMillis() - t0, res != null && res.success());

        if (res == null) {
            throw new HemisResponse.HemisApiException(api + " khong tra ve du lieu");
        }
        return res;
    }

    // -----------------------------------------------------------------
    // Ho tro
    // -----------------------------------------------------------------

    private byte[] encodePayload(String signedXml) {
        String content = signedXml;

        // Dac ta ghi: "File chua noi dung XML da ky so, duoc ma hoa duoi dang
        // chuoi JSON string (escape chuan JSON)". Cho den khi Cuc KHCN&TT xac nhan,
        // mac dinh TAT (gui XML nguyen ban) va co the bat bang cau hinh.
        if (props.upload().jsonStringEncoded()) {
            try {
                content = objectMapper.writeValueAsString(signedXml);
            } catch (Exception e) {
                throw new HemisResponse.HemisApiException("Khong ma hoa duoc XML thanh chuoi JSON", e);
            }
        }

        byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
        if (props.upload().gzip()) {
            bytes = gzip(bytes);
        }
        return bytes;
    }

    private static byte[] gzip(byte[] input) {
        try (ByteArrayOutputStream bos = new ByteArrayOutputStream();
             GZIPOutputStream gz = new GZIPOutputStream(bos)) {
            gz.write(input);
            gz.finish();
            return bos.toByteArray();
        } catch (IOException e) {
            throw new HemisResponse.HemisApiException("Khong nen duoc gzip", e);
        }
    }

    /**
     * Thu lai co kiem soat. Lan dau that bai vi 401 se lay token moi roi thu lai;
     * cac loi khac cho theo cap so cong.
     */
    private HemisResponse withRetry(java.util.function.Supplier<HemisResponse> call) {
        int max = Math.max(1, props.http().maxRetries());
        RuntimeException last = null;
        for (int i = 1; i <= max; i++) {
            try {
                return call.get();
            } catch (RuntimeException e) {
                last = e;
                String msg = String.valueOf(e.getMessage());
                boolean unauthorized = msg.contains("401");
                if (unauthorized) {
                    log.warn("Bi tu choi 401, lay token moi roi thu lai (lan {}/{})", i, max);
                    auth.forceRefresh();
                } else {
                    log.warn("Goi API that bai lan {}/{}: {}", i, max, msg);
                }
                if (i < max) {
                    sleep(props.http().retryBackoffSeconds() * i);
                }
            }
        }
        throw new HemisResponse.HemisApiException("Goi API that bai sau " + max + " lan thu", last);
    }

    private static void sleep(long seconds) {
        try {
            Thread.sleep(seconds * 1000L);
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
        }
    }

    /** ByteArrayResource co ten tep - bat buoc de phan multipart hop le. */
    static class NamedByteArrayResource extends ByteArrayResource {
        private final String filename;

        NamedByteArrayResource(byte[] data, String filename) {
            super(data);
            this.filename = filename;
        }

        @Override
        public String getFilename() {
            return filename;
        }
    }
}
