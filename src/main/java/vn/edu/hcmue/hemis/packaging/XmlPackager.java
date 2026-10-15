package vn.edu.hcmue.hemis.packaging;

import java.io.StringWriter;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

import org.springframework.stereotype.Component;
import org.w3c.dom.Document;
import org.w3c.dom.Element;

/**
 * Sinh tep XML CHUA KY theo dung cau truc dac ta cua Bo.
 *
 * <pre>{@code
 * <?xml version="1.0" encoding="utf-8"?>
 * <Data xmlns:xsd="http://www.w3.org/2001/XMLSchema"
 *       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
 *   <DuLieuKySo Id="data">
 *     <k1>020eccc5-8e1f-4b57</k1>
 *     <MaDonVi>...</MaDonVi>
 *     <TenDonVi>...</TenDonVi>
 *     <DanhSachCanboHoso>
 *       <CanboHoso>
 *         <Id>...</Id>
 *         ...
 *       </CanboHoso>
 *     </DanhSachCanboHoso>
 *     <k2>-b305-32f45d60e5ab</k2>
 *   </DuLieuKySo>
 *   <!-- the KySo do buoc ky so chen vao, NGANG HANG voi DuLieuKySo -->
 * </Data>
 * }</pre>
 *
 * <p>Ba diem bat buoc, sai mot trong ba thi HEMIS tu choi tep:
 * <ol>
 *   <li>Thuoc tinh {@code Id="data"} tren {@code DuLieuKySo} - chu ky tham chieu
 *       toi node nay qua {@code URI="#data"}.</li>
 *   <li>{@code k1} la con dau tien, {@code k2} la con cuoi cung.</li>
 *   <li>Ten the {@code DanhSachXXX} va ten truong viet kieu PascalCase
 *       (khac voi ten truong trong than JSON la UPPER_SNAKE).</li>
 * </ol>
 */
@Component
public class XmlPackager {

    /** Dinh dang ngay dung trong XML. Xem ghi chu "Diem can lam ro" trong tai lieu. */
    public static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("yyyy-MM-dd");
    public static final DateTimeFormatter DATETIME = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss");

    /**
     * @param iks      ma phien ky so
     * @param maDonVi  ma don vi tren HEMIS
     * @param tenDonVi ten don vi
     * @param lists    cac danh sach du lieu; khoa la ten the DanhSachXXX,
     *                 gia tri la danh sach ban ghi. Moi ban ghi la mot cap
     *                 (ten the con, map truong -> gia tri).
     */
    public String build(Iks iks, String maDonVi, String tenDonVi, List<DanhSach> lists) {
        try {
            DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
            dbf.setNamespaceAware(true);
            dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            Document doc = dbf.newDocumentBuilder().newDocument();
            doc.setXmlStandalone(true);

            Element root = doc.createElement("Data");
            root.setAttribute("xmlns:xsd", "http://www.w3.org/2001/XMLSchema");
            root.setAttribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance");
            doc.appendChild(root);

            Element duLieu = doc.createElement("DuLieuKySo");
            duLieu.setAttribute("Id", "data");
            root.appendChild(duLieu);

            // (1) k1 - PHAI la con dau tien
            duLieu.appendChild(text(doc, "k1", iks.k1()));

            appendIfNotBlank(doc, duLieu, "MaDonVi", maDonVi);
            appendIfNotBlank(doc, duLieu, "TenDonVi", tenDonVi);

            // (2) cac danh sach du lieu nghiep vu
            for (DanhSach ds : lists) {
                if (ds.records() == null || ds.records().isEmpty()) {
                    continue; // chi xuat danh sach thuc su co du lieu
                }
                Element list = doc.createElement(ds.listTag());
                for (Map<String, Object> record : ds.records()) {
                    Element item = doc.createElement(ds.itemTag());
                    record.forEach((field, value) -> {
                        if (value != null) {
                            item.appendChild(text(doc, field, format(value)));
                        }
                    });
                    list.appendChild(item);
                }
                duLieu.appendChild(list);
            }

            // (3) k2 - PHAI la con cuoi cung
            duLieu.appendChild(text(doc, "k2", iks.k2()));

            return serialize(doc);
        } catch (Exception e) {
            throw new IllegalStateException("Khong sinh duoc tep XML: " + e.getMessage(), e);
        }
    }

    // -----------------------------------------------------------------

    private static Element text(Document doc, String tag, String value) {
        Element el = doc.createElement(tag);
        el.setTextContent(value);
        return el;
    }

    private static void appendIfNotBlank(Document doc, Element parent, String tag, String value) {
        if (value != null && !value.isBlank()) {
            parent.appendChild(text(doc, tag, value));
        }
    }

    private static String format(Object v) {
        if (v instanceof LocalDate d) {
            return d.format(DATE);
        }
        if (v instanceof LocalDateTime dt) {
            return dt.format(DATETIME);
        }
        if (v instanceof Boolean b) {
            return b ? "true" : "false";
        }
        return String.valueOf(v);
    }

    private static String serialize(Document doc) throws Exception {
        TransformerFactory tf = TransformerFactory.newInstance();
        tf.setAttribute(javax.xml.XMLConstants.ACCESS_EXTERNAL_DTD, "");
        tf.setAttribute(javax.xml.XMLConstants.ACCESS_EXTERNAL_STYLESHEET, "");
        Transformer t = tf.newTransformer();
        t.setOutputProperty(OutputKeys.ENCODING, "utf-8");
        t.setOutputProperty(OutputKeys.INDENT, "yes");
        t.setOutputProperty(OutputKeys.STANDALONE, "yes");
        StringWriter sw = new StringWriter();
        t.transform(new DOMSource(doc), new StreamResult(sw));
        return sw.toString();
    }

    /**
     * Mot the {@code DanhSachXXX} trong tep XML.
     *
     * @param listTag ten the danh sach, vi du {@code DanhSachCanboHoso}
     * @param itemTag ten the ban ghi, vi du {@code CanboHoso}
     * @param records danh sach ban ghi; LinkedHashMap de giu thu tu truong
     */
    public record DanhSach(String listTag, String itemTag, List<Map<String, Object>> records) {
    }
}
