package vn.edu.hcmue.hemis.packaging;

import java.util.UUID;

/**
 * Ma phien ky so (IKS) va hai manh k1 / k2 nhung trong tep XML.
 *
 * <p>Quy tac cua Bo:
 * <ul>
 *   <li>IKS la chuoi Guid 36 ky tu (co dau gach ngang).</li>
 *   <li>{@code k1} = 18 ky tu DAU, la node con DAU TIEN cua {@code DuLieuKySo}.</li>
 *   <li>{@code k2} = 18 ky tu CUOI, la node con CUOI CUNG cua {@code DuLieuKySo}.</li>
 *   <li>Ghep {@code k1 + k2} theo dung thu tu phai ra lai dung chuoi IKS ban dau,
 *       khong trung, khong thieu ky tu nao.</li>
 * </ul>
 *
 * <p>Vi du: {@code 020eccc5-8e1f-4b57-b305-32f45d60e5ab}
 * <br>k1 = {@code 020eccc5-8e1f-4b57}
 * <br>k2 = {@code -b305-32f45d60e5ab}
 */
public record Iks(UUID value) {

    public static final int LENGTH = 36;
    public static final int HALF = 18;

    public static Iks random() {
        return new Iks(UUID.randomUUID());
    }

    public static Iks of(String s) {
        return new Iks(UUID.fromString(s));
    }

    public String text() {
        return value.toString();
    }

    public String k1() {
        return text().substring(0, HALF);
    }

    public String k2() {
        return text().substring(HALF, LENGTH);
    }

    /** Ghep lai tu hai manh doc duoc trong tep XML. */
    public static Iks join(String k1, String k2) {
        String s = k1 + k2;
        if (s.length() != LENGTH) {
            throw new IllegalArgumentException(
                    "k1 + k2 phai du " + LENGTH + " ky tu, dang co " + s.length());
        }
        return of(s);
    }

    /** Kiem tra tep XML co dung IKS mong doi hay khong. */
    public boolean matches(String k1, String k2) {
        return k1().equals(k1) && k2().equals(k2);
    }
}
