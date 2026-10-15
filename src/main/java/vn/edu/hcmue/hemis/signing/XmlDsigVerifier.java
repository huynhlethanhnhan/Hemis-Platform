package vn.edu.hcmue.hemis.signing;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.security.PublicKey;
import java.security.cert.X509Certificate;
import java.util.Iterator;

import javax.xml.crypto.dsig.XMLSignature;
import javax.xml.crypto.dsig.XMLSignatureFactory;
import javax.xml.crypto.dsig.dom.DOMValidateContext;
import javax.xml.crypto.dsig.keyinfo.KeyInfo;
import javax.xml.crypto.dsig.keyinfo.X509Data;
import javax.xml.parsers.DocumentBuilderFactory;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;

import vn.edu.hcmue.hemis.packaging.Iks;

/**
 * Tu xac minh lai tep XML da ky TRUOC KHI gui len HEMIS.
 *
 * <p>Day la buoc re tien nhung chan duoc phan lon loi thuong gap: tep bi sua sau khi ky,
 * sai node tham chieu, thieu k1/k2, sai IKS. Khong co buoc nay thi chi phat hien duoc
 * loi khi HEMIS tra ve "khong thanh cong" ma khong noi ro ly do.
 *
 * <p>Dung thu vien XML-DSig co san trong JDK ({@code javax.xml.crypto.dsig}), khong can
 * phu thuoc ben ngoai.
 */
@Component
public class XmlDsigVerifier {

    private static final Logger log = LoggerFactory.getLogger(XmlDsigVerifier.class);
    private static final String DSIG_NS = "http://www.w3.org/2000/09/xmldsig#";

    /** Ket qua xac minh. */
    public record Result(boolean valid, String signerSubject, String message) {
        public static Result ok(String subject) {
            return new Result(true, subject, "Chu ky hop le");
        }

        public static Result fail(String message) {
            return new Result(false, null, message);
        }
    }

    /**
     * Xac minh chu ky va kiem tra IKS trong tep khop voi IKS mong doi.
     *
     * @param signedXml  noi dung tep da ky
     * @param expectedIks IKS cua dot dong bo
     */
    public Result verify(String signedXml, Iks expectedIks) {
        try {
            DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
            dbf.setNamespaceAware(true);
            dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
            Document doc = dbf.newDocumentBuilder()
                    .parse(new ByteArrayInputStream(signedXml.getBytes(StandardCharsets.UTF_8)));

            // 1. Kiem tra cau truc bat buoc
            String structure = checkStructure(doc, expectedIks);
            if (structure != null) {
                return Result.fail(structure);
            }

            // 2. Kiem tra chu ky so
            NodeList nl = doc.getElementsByTagNameNS(DSIG_NS, "Signature");
            if (nl.getLength() == 0) {
                return Result.fail("Khong tim thay the Signature trong tep");
            }

            // Dang ky node co thuoc tinh Id="data" de tham chieu URI="#data" giai duoc
            Element duLieu = findElement(doc, "DuLieuKySo");
            if (duLieu != null) {
                duLieu.setIdAttribute("Id", true);
            }
            registerObjectIds(doc);

            XMLSignatureFactory factory = XMLSignatureFactory.getInstance("DOM");
            X509KeySelector selector = new X509KeySelector();
            DOMValidateContext ctx = new DOMValidateContext(selector, nl.item(0));
            XMLSignature signature = factory.unmarshalXMLSignature(ctx);

            boolean valid = signature.validate(ctx);
            if (!valid) {
                StringBuilder sb = new StringBuilder("Chu ky khong hop le.");
                if (!signature.getSignatureValue().validate(ctx)) {
                    sb.append(" Gia tri chu ky sai.");
                }
                return Result.fail(sb.toString());
            }

            String subject = readSubjectName(doc);
            log.info("Xac minh chu ky dat, nguoi ky: {}", subject);
            return Result.ok(subject);

        } catch (Exception e) {
            return Result.fail("Loi khi xac minh chu ky: " + e.getMessage());
        }
    }

    // -----------------------------------------------------------------

    /** Kiem tra cac rang buoc cau truc ma dac ta neu ro. */
    private String checkStructure(Document doc, Iks expectedIks) {
        Element duLieu = findElement(doc, "DuLieuKySo");
        if (duLieu == null) {
            return "Thieu the DuLieuKySo";
        }
        if (!"data".equals(duLieu.getAttribute("Id"))) {
            return "The DuLieuKySo phai co thuoc tinh Id=\"data\"";
        }

        Element first = firstChildElement(duLieu);
        Element last = lastChildElement(duLieu);
        if (first == null || !"k1".equals(first.getTagName())) {
            return "k1 phai la node con DAU TIEN cua DuLieuKySo";
        }
        if (last == null || !"k2".equals(last.getTagName())) {
            return "k2 phai la node con CUOI CUNG cua DuLieuKySo";
        }
        if (expectedIks != null && !expectedIks.matches(first.getTextContent(), last.getTextContent())) {
            return "k1 + k2 trong tep khong khop IKS cua dot dong bo";
        }

        // KySo phai ngang hang voi DuLieuKySo, khong long ben trong
        if (duLieu.getElementsByTagName("KySo").getLength() > 0) {
            return "The KySo khong duoc nam ben trong DuLieuKySo";
        }

        // X509SubjectName phai dung TRUOC X509Certificate
        NodeList x509 = doc.getElementsByTagNameNS(DSIG_NS, "X509Data");
        if (x509.getLength() > 0) {
            Element data = (Element) x509.item(0);
            Element c = firstChildElement(data);
            if (c != null && "X509Certificate".equals(c.getLocalName())) {
                return "X509SubjectName phai dung TRUOC X509Certificate trong X509Data";
            }
        }
        return null;
    }

    private static void registerObjectIds(Document doc) {
        NodeList objects = doc.getElementsByTagNameNS(DSIG_NS, "Object");
        for (int i = 0; i < objects.getLength(); i++) {
            Element o = (Element) objects.item(i);
            if (o.hasAttribute("Id")) {
                o.setIdAttribute("Id", true);
            }
        }
    }

    private static Element findElement(Document doc, String tag) {
        NodeList nl = doc.getElementsByTagName(tag);
        return nl.getLength() == 0 ? null : (Element) nl.item(0);
    }

    private static Element firstChildElement(Element parent) {
        NodeList children = parent.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            if (children.item(i) instanceof Element e) {
                return e;
            }
        }
        return null;
    }

    private static Element lastChildElement(Element parent) {
        NodeList children = parent.getChildNodes();
        for (int i = children.getLength() - 1; i >= 0; i--) {
            if (children.item(i) instanceof Element e) {
                return e;
            }
        }
        return null;
    }

    private String readSubjectName(Document doc) {
        NodeList nl = doc.getElementsByTagNameNS(DSIG_NS, "X509SubjectName");
        return nl.getLength() > 0 ? nl.item(0).getTextContent() : null;
    }

    /** Lay khoa cong khai tu chung thu nhung trong KeyInfo/X509Data. */
    static class X509KeySelector extends javax.xml.crypto.KeySelector {
        @Override
        public javax.xml.crypto.KeySelectorResult select(KeyInfo keyInfo,
                                                         Purpose purpose,
                                                         javax.xml.crypto.AlgorithmMethod method,
                                                         javax.xml.crypto.XMLCryptoContext context) {
            if (keyInfo == null) {
                throw new IllegalArgumentException("KeyInfo rong - khong co chung thu de xac minh");
            }
            for (Object o : keyInfo.getContent()) {
                if (o instanceof X509Data x509Data) {
                    for (Object c : x509Data.getContent()) {
                        if (c instanceof X509Certificate cert) {
                            PublicKey key = cert.getPublicKey();
                            return () -> key;
                        }
                    }
                }
            }
            throw new IllegalArgumentException("Khong tim thay chung thu X509 trong KeyInfo");
        }
    }
}
