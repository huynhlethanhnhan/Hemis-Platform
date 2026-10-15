package vn.edu.hcmue.hemis.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * Toan bo cau hinh ket noi HEMIS, anh xa tu tien to {@code hemis} trong application.yml.
 *
 * <p>Khong dat gia tri bi mat truc tiep trong file cau hinh - dung bien moi truong.
 */
@ConfigurationProperties(prefix = "hemis")
public record HemisProperties(
        String ssoUrl,
        String gatewayUrl,
        Paths paths,
        Credentials credentials,
        String donViId,
        String maDonVi,
        String tenDonVi,
        String domainConnect,
        Token token,
        Http http,
        Upload upload,
        Signing signing) {

    public record Paths(
            @DefaultValue("/connect/token") String token,
            @DefaultValue("/danhmucbeta/v5/DM_BAC_LUONG/getDanhMucHemis") String catalog,
            @DefaultValue("/dongbodulieubeta/v5/co_so_giao_duc_input/db16/{donViId}/{iks}/{ph}") String xmlUpload,
            @DefaultValue("/dongbodulieubeta/v5/co_so_giao_duc_input/{api}/{donViId}/{idKey}") String jsonSync) {
    }

    public record Credentials(
            @DefaultValue("password") String clientId,
            String clientSecret,
            String username,
            String password,
            @DefaultValue("password") String scope,
            @DefaultValue("password") String grantType) {
    }

    public record Token(
            @DefaultValue("60") long refreshMarginSeconds,
            @DefaultValue("900") long maxLifetimeSeconds) {
    }

    public record Http(
            @DefaultValue("15") int connectTimeoutSeconds,
            @DefaultValue("180") int readTimeoutSeconds,
            @DefaultValue("3") int maxRetries,
            @DefaultValue("5") int retryBackoffSeconds) {
    }

    public record Upload(
            @DefaultValue("false") boolean gzip,
            @DefaultValue("false") boolean jsonStringEncoded) {
    }

    public record Signing(
            @DefaultValue("agent") String mode,
            @DefaultValue("./data/hemis-packages") String storageDir,
            @DefaultValue("true") boolean verifyBeforeSend,
            String agentToken) {

        public boolean isAgentMode() {
            return "agent".equalsIgnoreCase(mode);
        }
    }
}
