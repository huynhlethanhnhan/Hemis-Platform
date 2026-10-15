package vn.edu.hcmue.hemis;

import org.junit.jupiter.api.Disabled;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

/**
 * Kiem tra ung dung khoi dong duoc va Flyway chay dung tren PostgreSQL that.
 *
 * <p>Test nay dung Testcontainers nen CAN Docker Desktop dang chay. Bo @Disabled
 * khi may da bat Docker (xem docs/05_MOI_TRUONG_PHAT_TRIEN.md).
 */
@Import(TestcontainersConfiguration.class)
@SpringBootTest
@Disabled("Can Docker Desktop dang chay - bo dong nay khi da bat Docker")
class HemisPlatformApplicationTests {

    @Test
    void contextLoads() {
    }
}
