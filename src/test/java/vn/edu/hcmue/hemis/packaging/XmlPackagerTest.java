package vn.edu.hcmue.hemis.packaging;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import javax.xml.parsers.DocumentBuilderFactory;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

/**
 * Kiem tra tep XML sinh ra dung BA rang buoc ma dac ta neu ro.
 * Sai mot trong ba thi HEMIS tu choi ma khong noi ro ly do.
 */
class XmlPackagerTest {

    private XmlPackager packager;
    private Iks iks;

    @BeforeEach
    void setUp() {
        packager = new XmlPackager();
        iks = Iks.of("020eccc5-8e1f-4b57-b305-32f45d60e5ab");
    }

    private String buildSample() {
        Map<String, Object> record = new LinkedHashMap<>();
        record.put("Id", "11111111-2222-3333-4444-555555555555");
        record.put("MaDonVi", "HCMUE");
        record.put("TenDonVi", "Truong Dai hoc Su pham Thanh pho Ho Chi Minh");
        record.put("NgayQdThanhLap", LocalDate.of(1976, 10, 27));
        record.put("TruongDacThu", false);

        return packager.build(iks, "HCMUE", "Truong Dai hoc Su pham Thanh pho Ho Chi Minh",
                List.of(new XmlPackager.DanhSach("DanhSachCoSoGiaoDuc", "CoSoGiaoDuc", List.of(record))));
    }

    private Document parse(String xml) throws Exception {
        DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
        dbf.setNamespaceAware(true);
        return dbf.newDocumentBuilder()
                .parse(new ByteArrayInputStream(xml.getBytes(StandardCharsets.UTF_8)));
    }

    @Test
    @DisplayName("DuLieuKySo phai co thuoc tinh Id=\"data\" de chu ky tham chieu URI=#data")
    void coThuocTinhIdData() throws Exception {
        Document doc = parse(buildSample());
        Element duLieu = (Element) doc.getElementsByTagName("DuLieuKySo").item(0);

        assertThat(duLieu).isNotNull();
        assertThat(duLieu.getAttribute("Id")).isEqualTo("data");
    }

    @Test
    @DisplayName("k1 la node con DAU TIEN, k2 la node con CUOI CUNG cua DuLieuKySo")
    void k1DauTienK2CuoiCung() throws Exception {
        Document doc = parse(buildSample());
        Element duLieu = (Element) doc.getElementsByTagName("DuLieuKySo").item(0);

        List<Element> children = elementChildren(duLieu);
        assertThat(children.getFirst().getTagName()).isEqualTo("k1");
        assertThat(children.getLast().getTagName()).isEqualTo("k2");
        assertThat(children.getFirst().getTextContent()).isEqualTo(iks.k1());
        assertThat(children.getLast().getTextContent()).isEqualTo(iks.k2());
    }

    @Test
    @DisplayName("Ghep k1 + k2 doc tu tep ra dung IKS ban dau")
    void ghepLaiRaIksBanDau() throws Exception {
        Document doc = parse(buildSample());
        String k1 = doc.getElementsByTagName("k1").item(0).getTextContent();
        String k2 = doc.getElementsByTagName("k2").item(0).getTextContent();

        assertThat(Iks.join(k1, k2)).isEqualTo(iks);
    }

    @Test
    @DisplayName("The DanhSachXXX va ban ghi con nam giua k1 va k2")
    void danhSachNamGiuaK1VaK2() throws Exception {
        Document doc = parse(buildSample());
        Element duLieu = (Element) doc.getElementsByTagName("DuLieuKySo").item(0);
        List<Element> children = elementChildren(duLieu);

        int viTriDanhSach = -1;
        for (int i = 0; i < children.size(); i++) {
            if ("DanhSachCoSoGiaoDuc".equals(children.get(i).getTagName())) {
                viTriDanhSach = i;
            }
        }
        assertThat(viTriDanhSach).isGreaterThan(0);
        assertThat(viTriDanhSach).isLessThan(children.size() - 1);

        Element danhSach = children.get(viTriDanhSach);
        assertThat(elementChildren(danhSach)).hasSize(1);
        assertThat(elementChildren(danhSach).getFirst().getTagName()).isEqualTo("CoSoGiaoDuc");
    }

    @Test
    @DisplayName("Ngay xuat theo dinh dang yyyy-MM-dd, bool xuat true/false")
    void dinhDangGiaTri() throws Exception {
        Document doc = parse(buildSample());

        assertThat(doc.getElementsByTagName("NgayQdThanhLap").item(0).getTextContent())
                .isEqualTo("1976-10-27");
        assertThat(doc.getElementsByTagName("TruongDacThu").item(0).getTextContent())
                .isEqualTo("false");
    }

    @Test
    @DisplayName("Danh sach rong thi khong xuat the DanhSachXXX")
    void boQuaDanhSachRong() {
        String xml = packager.build(iks, "HCMUE", "HCMUE",
                List.of(new XmlPackager.DanhSach("DanhSachRong", "Rong", List.of())));

        assertThat(xml).doesNotContain("DanhSachRong");
        assertThat(xml).contains("<k1>").contains("<k2>");
    }

    private static List<Element> elementChildren(Element parent) {
        NodeList nl = parent.getChildNodes();
        return java.util.stream.IntStream.range(0, nl.getLength())
                .mapToObj(nl::item)
                .filter(n -> n.getNodeType() == Node.ELEMENT_NODE)
                .map(Element.class::cast)
                .toList();
    }
}
