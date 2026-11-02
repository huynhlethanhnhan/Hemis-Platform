package vn.edu.hcmue.hemis.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import vn.edu.hcmue.hemis.journal.ValidationRule;
import vn.edu.hcmue.hemis.journal.ValidationRuleRepository;

class ValidationRuleImportServiceTest {

    private ValidationRuleRepository repository;
    private List<ValidationRule> savedRules;

    @BeforeEach
    void setUp() {
        repository = mock(ValidationRuleRepository.class);
        savedRules = new ArrayList<>();
        when(repository.saveAll(any())).thenAnswer(invocation -> {
            List<ValidationRule> rules = invocation.getArgument(0);
            savedRules.addAll(rules);
            return rules;
        });
    }

    @Test
    @DisplayName("Imports packaged rules and applies defaults to omitted optional values")
    void importsRulesAndDefaults() {
        when(repository.findByPhAndEntity("COSOGIAODUC", "_CO_SO_GIAO_DUC")).thenReturn(List.of());
        ValidationRuleImportService service = new ValidationRuleImportService(repository);

        assertThat(service.importRules()).isGreaterThan(2);

        verify(repository).findByPhAndEntity("COSOGIAODUC", "_CO_SO_GIAO_DUC");
        assertThat(savedRules).hasSizeGreaterThan(2);
        ValidationRule idRule = savedRules.stream().filter(r -> r.getField().equals("Id")).findFirst().orElseThrow();
        assertThat(idRule.getPh()).isEqualTo("COSOGIAODUC");
        assertThat(idRule.getEntity()).isEqualTo("_CO_SO_GIAO_DUC");
        assertThat(idRule.getField()).isEqualTo("Id");
        assertThat(idRule.getRequired()).isTrue();
        assertThat(idRule.getMaxLength()).isEqualTo(36);
        assertThat(idRule.getDataType()).isEqualTo("guid");
        assertThat(idRule.getNote()).isEqualTo("Id ban ghi");

        ValidationRule websiteRule = savedRules.stream().filter(r -> r.getField().equals("WEBSITE")).findFirst().orElseThrow();
        assertThat(websiteRule.getRequired()).isTrue();
        assertThat(websiteRule.getMaxLength()).isEqualTo(250);
        assertThat(websiteRule.getDataType()).isEqualTo("string");
        assertThat(websiteRule.getNote()).isEqualTo("Website");
        ValidationRule noMaxLengthRule = savedRules.stream().filter(r -> r.getField().equals("SO_GV_GDTC")).findFirst().orElseThrow();
        assertThat(noMaxLengthRule.getMaxLength()).isZero();
    }

    @Test
    @DisplayName("Updates matching packaged fields, inserts missing fields, and removes obsolete rules")
    void reconcilesExistingRulesOnRepeatedImport() {
        ValidationRule existing = rule(7L, "MA_DON_VI");
        existing.setNote("Old note");
        ValidationRule obsolete = rule(8L, "OBSOLETE");
        when(repository.findByPhAndEntity("COSOGIAODUC", "_CO_SO_GIAO_DUC"))
                .thenReturn(List.of(existing, obsolete));
        ValidationRuleImportService service = new ValidationRuleImportService(repository);

        assertThat(service.importRules()).isGreaterThan(2);

        verify(repository).deleteAll(argThat(obsoleteRules -> {
            List<ValidationRule> deleted = new ArrayList<>();
            obsoleteRules.forEach(deleted::add);
            return deleted.contains(obsolete);
        }));
        verify(repository).saveAll(any());
        assertThat(savedRules).hasSizeGreaterThan(2);
        ValidationRule updated = savedRules.stream().filter(r -> r.getField().equals("MA_DON_VI")).findFirst().orElseThrow();
        assertThat(updated).isSameAs(existing);
        assertThat(existing.getId()).isEqualTo(7L);
        assertThat(existing.getRequired()).isTrue();
        assertThat(existing.getMaxLength()).isEqualTo(50);
        assertThat(existing.getDataType()).isEqualTo("string");
        assertThat(existing.getNote()).isEqualTo("Ma don vi tren he thong HEMIS");
        assertThat(savedRules).anySatisfy(rule -> {
            assertThat(rule.getField()).isEqualTo("TEN_DON_VI");
            assertThat(rule.getPh()).isEqualTo("COSOGIAODUC");
            assertThat(rule.getEntity()).isEqualTo("_CO_SO_GIAO_DUC");
        });
    }

    @Test
    @DisplayName("Imports the packaged COSOGIAODUC rule YAML")
    void importsPackagedRules() {
        when(repository.findByPhAndEntity("COSOGIAODUC", "_CO_SO_GIAO_DUC")).thenReturn(List.of());
        ValidationRuleImportService service = new ValidationRuleImportService(repository);

        int importedCount = service.importRules();

        assertThat(importedCount).isGreaterThan(0);
        assertThat(savedRules).hasSize(importedCount);
        assertThat(savedRules)
                .anySatisfy(rule -> {
                    assertThat(rule.getField()).isEqualTo("Id");
                    assertThat(rule.getRequired()).isTrue();
                    assertThat(rule.getMaxLength()).isEqualTo(36);
                    assertThat(rule.getDataType()).isEqualTo("guid");
                });
        assertThat(savedRules).allSatisfy(rule -> {
            assertThat(rule.getPh()).isEqualTo("COSOGIAODUC");
            assertThat(rule.getEntity()).isEqualTo("_CO_SO_GIAO_DUC");
        });
    }

    private static ValidationRule rule(Long id, String field) {
        ValidationRule rule = new ValidationRule();
        rule.setId(id);
        rule.setPh("COSOGIAODUC");
        rule.setEntity("_CO_SO_GIAO_DUC");
        rule.setField(field);
        return rule;
    }
}
