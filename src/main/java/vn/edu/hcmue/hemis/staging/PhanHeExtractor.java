package vn.edu.hcmue.hemis.staging;

import java.util.List;
import java.util.Map;

import vn.edu.hcmue.hemis.packaging.XmlPackager;

/**
 * Trich xuat du lieu mot phan he tu kho du lieu cua Truong va chuyen sang mo hinh chuan HEMIS.
 *
 * <p>Moi phan he (COSOGIAODUC, CANBO, HOCVIEN...) co mot lop thuc thi rieng. Lop thuc thi
 * chiu trach nhiem:
 * <ul>
 *   <li>Doc du liệu tu schema {@code dwh}</li>
 *   <li>Gan dinh danh GUID on dinh qua bang {@code entity_map}</li>
 *   <li>Doi ma danh muc noi bo sang ma HEMIS qua bang {@code catalog_map}</li>
 *   <li>Sinh song song HAI dinh dang tu CUNG mot nguon: XML (PascalCase) va JSON (UPPER_SNAKE)</li>
 * </ul>
 *
 * <p>Quan trong: XML va JSON phai sinh tu cung mot doi tuong trong bo nho. Khong duoc
 * viet hai doan ma doc lap, vi se phat sinh sai lech giua hai ban gui.
 */
public interface PhanHeExtractor {

    /** Ma phan he dung cho API db16, vi du COSOGIAODUC. */
    String ph();

    /** Ma API JSON tuong ung, vi du db1. */
    String api();

    /** Trich xuat du lieu can gui trong dot nay. */
    Result extract();

    /**
     * @param xmlLists   cac the DanhSachXXX dua vao tep XML
     * @param jsonBody   cac truong _XXX dua vao than JSON (chua gom t_k va DomainConnect)
     * @param recordCount tong so ban ghi, dung de ghi nhat ky
     */
    record Result(List<XmlPackager.DanhSach> xmlLists,
                  Map<String, Object> jsonBody,
                  int recordCount) {
    }
}
