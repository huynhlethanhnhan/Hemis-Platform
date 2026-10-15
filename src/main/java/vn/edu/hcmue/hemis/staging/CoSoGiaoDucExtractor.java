package vn.edu.hcmue.hemis.staging;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Component;

import vn.edu.hcmue.hemis.config.HemisProperties;
import vn.edu.hcmue.hemis.packaging.XmlPackager;

/**
 * Phan he COSOGIAODUC (API db1) - phan he duoc chon lam thi diem cua Giai doan 1.
 *
 * <p>Ly do chon phan he nay lam thi diem: chi co mot ban ghi chinh, du lieu da san co
 * trong ho so phap ly cua Truong, khong chua du lieu ca nhan nhay cam, nen chung minh
 * duoc toan bo duong di ky thuat ma khong phu thuoc chien dich lam sach du lieu.
 *
 * <p>TRANG THAI: ban hien tai doc tu cau hinh de chay duoc ngay tu dau. Cong viec tiep theo
 * (tuan 2 cua ke hoach) la thay phan {@link #thongTinChung()} bang truy van thuc tu schema
 * {@code dwh}, va bo sung cac mang con: _CSGD_KHEN_THUONG, _CSGD_KHOA_HOC,
 * _CSGD_LICH_SU_DTEN, _CSGD_DS_DAU_MOI_LH, _CSGD_THONG_TIN_KIEM_DINH,
 * _VAN_BAN_TRIEN_KHAI_THUC_HIEN_QUYEN_TU_CHU.
 */
@Component
public class CoSoGiaoDucExtractor implements PhanHeExtractor {

    private final HemisProperties props;

    public CoSoGiaoDucExtractor(HemisProperties props) {
        this.props = props;
    }

    @Override
    public String ph() {
        return "COSOGIAODUC";
    }

    @Override
    public String api() {
        return "db1";
    }

    @Override
    public Result extract() {
        Map<String, Object> csgd = thongTinChung();

        // --- Ban JSON: ten truong UPPER_SNAKE theo dac ta ---
        Map<String, Object> jsonBody = new LinkedHashMap<>();
        jsonBody.put("_CO_SO_GIAO_DUC", csgd);

        // --- Ban XML: cung du lieu, ten the PascalCase ---
        Map<String, Object> xmlRecord = toPascalCase(csgd);
        List<XmlPackager.DanhSach> xmlLists = List.of(
                new XmlPackager.DanhSach("DanhSachCoSoGiaoDuc", "CoSoGiaoDuc", List.of(xmlRecord)));

        return new Result(xmlLists, jsonBody, 1);
    }

    /**
     * Thong tin chung cua co so giao duc (bang _CO_SO_GIAO_DUC trong dac ta).
     *
     * <p>Cac truong danh dau (*) la bat buoc theo dac ta. Cac truong tham chieu danh muc
     * phai dung MA DANH MUC CUA HEMIS, khong dung ma noi bo.
     */
    private Map<String, Object> thongTinChung() {
        Map<String, Object> m = new LinkedHashMap<>();

        // Dinh danh ban ghi - PHAI on dinh qua cac dot gui. Khi noi voi kho du lieu,
        // lay tu bang entity_map thay vi sinh moi.
        m.put("Id", UUID.fromString(props.donViId()).toString());
        m.put("Created", LocalDate.now());          // *
        m.put("Modified", LocalDate.now());         // *
        m.put("MA_DON_VI", props.maDonVi());        // *
        m.put("TEN_DON_VI", props.tenDonVi());      // *

        // TODO tuan 2: doc tu schema dwh. Cac truong bat buoc con lai theo dac ta:
        // m.put("WEBSITE", ...);                        // *
        // m.put("SO_DIEN_THOAI", ...);                  // *
        // m.put("EMAIL", ...);                          // *
        // m.put("DIA_CHI", ...);                        // *
        // m.put("SO_QD_THANH_LAP", ...);                // *
        // m.put("NGAY_QD_THANH_LAP", LocalDate...);     // *
        // m.put("NGAY_DUOC_CAP_PHEP_HOAT_DONG", ...);   // *
        // m.put("LOAI_HINH_ID", ...);                   // * ma danh muc DM_LOAI_HINH_TRUONG
        // m.put("HINH_THUC_THANH_LAP", ...);            // * ma danh muc DM_HINH_THUC_THANH_LAP
        // m.put("LOAI_CO_SO", ...);                     // * ma danh muc DM_PHAN_LOAI_CO_SO
        // m.put("TRUONG_DAC_THU", false);               // *
        // m.put("TINH_THANH_NEW", ...);                 // * dia gioi moi theo QD 19/2025
        // m.put("XA_PHUONG_NEW", ...);                  // * dia gioi moi theo QD 19/2025
        // m.put("MA_DINH_DANH_ND69", ...);              // * ma dinh danh theo Nghi dinh 69

        return m;
    }

    /**
     * Doi ten truong UPPER_SNAKE sang PascalCase cho ban XML.
     * Vi du: MA_DON_VI -> MaDonVi, SO_QD_THANH_LAP -> SoQdThanhLap.
     */
    static Map<String, Object> toPascalCase(Map<String, Object> source) {
        Map<String, Object> out = new LinkedHashMap<>();
        source.forEach((k, v) -> out.put(pascal(k), v));
        return out;
    }

    static String pascal(String upperSnake) {
        if (upperSnake == null || upperSnake.isBlank()) {
            return upperSnake;
        }
        // Truong da o dang PascalCase (Id, Created, Modified) thi giu nguyen
        if (!upperSnake.contains("_") && !upperSnake.equals(upperSnake.toUpperCase())) {
            return upperSnake;
        }
        StringBuilder sb = new StringBuilder();
        for (String part : upperSnake.split("_")) {
            if (part.isEmpty()) {
                continue;
            }
            sb.append(Character.toUpperCase(part.charAt(0)))
              .append(part.substring(1).toLowerCase());
        }
        return sb.toString();
    }
}
