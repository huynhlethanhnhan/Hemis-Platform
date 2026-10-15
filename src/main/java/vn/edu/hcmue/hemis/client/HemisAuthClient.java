package vn.edu.hcmue.hemis.client;

import java.time.Instant;
import java.util.concurrent.locks.ReentrantLock;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

import com.fasterxml.jackson.annotation.JsonProperty;

import vn.edu.hcmue.hemis.config.HemisProperties;

/**
 * Lay va giu access token theo chuan OAuth 2.0 Resource Owner Password Credentials.
 *
 * <p>Dac ta cua Bo ghi {@code expires_in = 900000}. Gia tri nay kho co that neu tinh
 * bang giay (hon 10 ngay), rat co the la mili giay hoac loi danh may. Vi vay lop nay
 * khong tin tuyet doi gia tri tra ve ma lay {@code min(expires_in, max-lifetime-seconds)}
 * va tru them bien an toan. Khi Cuc Khoa hoc, Cong nghe va Thong tin xac nhan gia tri
 * dung, chinh lai {@code hemis.token.max-lifetime-seconds}.
 */
@Component
public class HemisAuthClient {

    private static final Logger log = LoggerFactory.getLogger(HemisAuthClient.class);

    private final RestClient sso;
    private final HemisProperties props;
    private final ReentrantLock lock = new ReentrantLock();

    private volatile String cachedToken;
    private volatile Instant expiresAt = Instant.EPOCH;

    public HemisAuthClient(RestClient ssoRestClient, HemisProperties props) {
        this.sso = ssoRestClient;
        this.props = props;
    }

    /** Tra ve access token con han; tu lay moi khi can. */
    public String accessToken() {
        if (isUsable()) {
            return cachedToken;
        }
        lock.lock();
        try {
            if (isUsable()) {
                return cachedToken;
            }
            return fetchNewToken();
        } finally {
            lock.unlock();
        }
    }

    /** Buoc lay token moi, dung khi API tra ve 401. */
    public String forceRefresh() {
        lock.lock();
        try {
            cachedToken = null;
            expiresAt = Instant.EPOCH;
            return fetchNewToken();
        } finally {
            lock.unlock();
        }
    }

    private boolean isUsable() {
        return cachedToken != null && Instant.now().isBefore(expiresAt);
    }

    private String fetchNewToken() {
        HemisProperties.Credentials c = props.credentials();

        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("grant_type", c.grantType());
        form.add("scope", c.scope());
        form.add("client_id", c.clientId());
        form.add("client_secret", c.clientSecret());
        form.add("username", c.username());
        form.add("password", c.password());

        TokenResponse res = sso.post()
                .uri(props.paths().token())
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(form)
                .retrieve()
                .body(TokenResponse.class);

        if (res == null || res.accessToken() == null || res.accessToken().isBlank()) {
            throw new IllegalStateException("May chu SSO khong tra ve access_token");
        }

        long lifetime = Math.min(
                res.expiresIn() > 0 ? res.expiresIn() : props.token().maxLifetimeSeconds(),
                props.token().maxLifetimeSeconds());
        long usable = Math.max(30, lifetime - props.token().refreshMarginSeconds());

        this.cachedToken = res.accessToken();
        this.expiresAt = Instant.now().plusSeconds(usable);

        log.info("Da lay access token moi, su dung trong {} giay (expires_in Bo tra ve = {})",
                usable, res.expiresIn());
        return cachedToken;
    }

    /** Gia tri cho header Authorization. */
    public String bearer() {
        return "Bearer " + accessToken();
    }

    /** Phan hoi cua endpoint /connect/token. */
    public record TokenResponse(
            @JsonProperty("access_token") String accessToken,
            @JsonProperty("expires_in") long expiresIn,
            @JsonProperty("token_type") String tokenType,
            @JsonProperty("scope") String scope) {
    }
}
