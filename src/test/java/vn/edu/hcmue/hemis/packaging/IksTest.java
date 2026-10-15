package vn.edu.hcmue.hemis.packaging;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.UUID;
import java.util.stream.IntStream;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * Kiem tra quy tac tach IKS thanh k1 / k2.
 * Day la loi de mac va kho phat hien nhat, vi HEMIS chi tra ve "khong thanh cong".
 */
class IksTest {

    @Test
    @DisplayName("k1 la 18 ky tu dau, k2 la 18 ky tu cuoi, ghep lai ra dung IKS")
    void tachVaGhepLai() {
        Iks iks = Iks.of("020eccc5-8e1f-4b57-b305-32f45d60e5ab");

        assertThat(iks.k1()).isEqualTo("020eccc5-8e1f-4b57");
        assertThat(iks.k2()).isEqualTo("-b305-32f45d60e5ab");
        assertThat(iks.k1()).hasSize(18);
        assertThat(iks.k2()).hasSize(18);
        assertThat(iks.k1() + iks.k2()).isEqualTo(iks.text());
    }

    @Test
    @DisplayName("Dung voi 1000 Guid ngau nhien - khong trung, khong thieu ky tu")
    void dungVoiMoiGuid() {
        IntStream.range(0, 1000).forEach(i -> {
            Iks iks = Iks.random();
            assertThat(iks.text()).hasSize(36);
            assertThat(iks.k1() + iks.k2()).isEqualTo(iks.text());
            assertThat(Iks.join(iks.k1(), iks.k2())).isEqualTo(iks);
        });
    }

    @Test
    @DisplayName("matches() phat hien tep co IKS khac")
    void phatHienIksKhac() {
        Iks a = Iks.random();
        Iks b = Iks.random();

        assertThat(a.matches(a.k1(), a.k2())).isTrue();
        assertThat(a.matches(b.k1(), b.k2())).isFalse();
    }

    @Test
    @DisplayName("join() tu choi khi thieu ky tu")
    void tuChoiKhiThieuKyTu() {
        assertThatThrownBy(() -> Iks.join("020eccc5-8e1f-4b5", "-b305-32f45d60e5ab"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("36");
    }

    @Test
    @DisplayName("UUID.randomUUID() luon sinh chuoi 36 ky tu co dau gach ngang")
    void dinhDangGuid() {
        assertThat(UUID.randomUUID().toString())
                .hasSize(36)
                .matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
    }
}
