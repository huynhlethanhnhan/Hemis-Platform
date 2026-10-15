package vn.edu.hcmue.hemis.client;

import tools.jackson.databind.JsonNode;

/**
 * Khung phan hoi dung chung cho moi API nghiep vu cua HEMIS.
 *
 * <pre>
 * { "success": true, "message": null, "data": ... }
 * </pre>
 *
 * <p>Luu y: HEMIS KHONG tra ve loi theo tung ban ghi. Chi co mot co {@code success}
 * cho ca dot gui. Do do viec kiem tra du lieu phai lam o phia Truong truoc khi gui,
 * va phai doi soat lai tren giao dien HEMIS sau khi gui.
 */
public record HemisResponse(boolean success, String message, JsonNode data) {

    public void requireSuccess(String what) {
        if (!success) {
            throw new HemisApiException(what + " that bai: " + message);
        }
    }

    /** Loi nghiep vu do HEMIS tra ve (khac voi loi mang / loi HTTP). */
    public static class HemisApiException extends RuntimeException {
        public HemisApiException(String message) {
            super(message);
        }

        public HemisApiException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
