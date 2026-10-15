package vn.edu.hcmue.hemis.config;

import java.time.Duration;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/**
 * Hai {@link RestClient} rieng biet:
 * <ul>
 *   <li>{@code ssoRestClient}     - goi may chu SSO de lay access token</li>
 *   <li>{@code gatewayRestClient} - goi cac API nghiep vu tren gateway cua Bo</li>
 * </ul>
 *
 * <p>Tach lam hai vi hai he thong co the nam tren hai ten mien khac nhau va
 * co yeu cau thoi gian cho khac nhau (tai danh muc hon 175 bang co the rat lau).
 */
@Configuration
@EnableConfigurationProperties(HemisProperties.class)
public class RestClientConfig {

    private final HemisProperties props;

    public RestClientConfig(HemisProperties props) {
        this.props = props;
    }

    @Bean
    RestClient ssoRestClient(RestClient.Builder builder) {
        return builder
                .baseUrl(props.ssoUrl())
                .requestFactory(requestFactory())
                .build();
    }

    @Bean
    RestClient gatewayRestClient(RestClient.Builder builder) {
        return builder
                .baseUrl(props.gatewayUrl())
                .requestFactory(requestFactory())
                .build();
    }

    private SimpleClientHttpRequestFactory requestFactory() {
        SimpleClientHttpRequestFactory f = new SimpleClientHttpRequestFactory();
        f.setConnectTimeout(Duration.ofSeconds(props.http().connectTimeoutSeconds()));
        f.setReadTimeout(Duration.ofSeconds(props.http().readTimeoutSeconds()));
        return f;
    }
}
