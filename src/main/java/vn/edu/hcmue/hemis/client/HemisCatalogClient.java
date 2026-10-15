package vn.edu.hcmue.hemis.client;

import java.util.Collections;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import vn.edu.hcmue.hemis.config.HemisProperties;

/**
 * Goi API lay danh muc dung chung cua HEMIS.
 *
 * <p>Mot lan goi tra ve HON 175 danh sach danh muc trong mot doi tuong
 * {@code data} duy nhat (DM_DAN_TOC, DM_TINH, DM_XA_NEW, DM_NGANH...).
 * Phan hoi rat lon nen dat thoi gian cho doc dai (xem {@code hemis.http.read-timeout-seconds}).
 *
 * <p>Moi phan tu danh muc co cau truc chung: Id, Code, MA_&lt;TEN&gt;, TEN_&lt;TEN&gt;,
 * ISPUBLIC, IsDeleted, Created, CreatedBy, Modified, ModifiedBy.
 */
@Component
public class HemisCatalogClient {

    private static final Logger log = LoggerFactory.getLogger(HemisCatalogClient.class);

    private final RestClient gateway;
    private final HemisAuthClient auth;
    private final HemisProperties props;

    public HemisCatalogClient(RestClient gatewayRestClient, HemisAuthClient auth, HemisProperties props) {
        this.gateway = gatewayRestClient;
        this.auth = auth;
        this.props = props;
    }

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
}
