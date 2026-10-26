package vn.edu.hcmue.hemis.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.ClassPathResource;

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
    @DisplayName("Imports all configured rule fields and applies defaults to omitted optional values")
    void importsRulesAndDefaults() {
        ValidationRuleImportService service = serviceFor("""
                ph: COSOGIAODUC
                entity: _CO_SO_GIAO_DUC
                rules:
                  - field: Id
                    required: true
                    max_length: 36
                    data_type: guid
                    catalog_name: identifiers
                    condition_expr: "status = 'active'"
                    note: Record identifier
                  - field: WEBSITE
                """);
        when(repository.findByPhAndEntity("COSOGIAODUC", "_CO_SO_GIAO_DUC")).thenReturn(List.of());

        assertThat(service.importRules()).isEqualTo(2);

        verify(repository).findByPhAndEntity("COSOGIAODUC", "_CO_SO_GIAO_DUC");
        assertThat(savedRules).hasSize(2);
        ValidationRule idRule = savedRules.get(0);
        assertThat(idRule.getPh()).isEqualTo("COSOGIAODUC");
        assertThat(idRule.getEntity()).isEqualTo("_CO_SO_GIAO_DUC");
        assertThat(idRule.getField()).isEqualTo("Id");
        assertThat(idRule.getRequired()).isTrue();
        assertThat(idRule.getMaxLength()).isEqualTo(36);
        assertThat(idRule.getDataType()).isEqualTo("guid");
        assertThat(idRule.getCatalogName()).isEqualTo("identifiers");
        assertThat(idRule.getConditionExpr()).isEqualTo("status = 'active'");
        assertThat(idRule.getNote()).isEqualTo("Record identifier");

        ValidationRule websiteRule = savedRules.get(1);
        assertThat(websiteRule.getField()).isEqualTo("WEBSITE");
        assertThat(websiteRule.getRequired()).isFalse();
        assertThat(websiteRule.getMaxLength()).isZero();
        assertThat(websiteRule.getDataType()).isNull();
        assertThat(websiteRule.getCatalogName()).isNull();
        assertThat(websiteRule.getConditionExpr()).isNull();
        assertThat(websiteRule.getNote()).isNull();
    }

    @Test
    @DisplayName("Updates matching fields, inserts new fields, and removes rules no longer in YAML")
    void reconcilesExistingRulesOnRepeatedImport() {
        ValidationRule existing = rule(7L, "MA_DON_VI");
        existing.setNote("Old note");
        ValidationRule obsolete = rule(8L, "OBSOLETE");
        when(repository.findByPhAndEntity("COSOGIAODUC", "_CO_SO_GIAO_DUC"))
                .thenReturn(List.of(existing, obsolete));
        ValidationRuleImportService service = serviceFor("""
                ph: COSOGIAODUC
                entity: _CO_SO_GIAO_DUC
                rules:
                  - field: MA_DON_VI
                    required: true
                    max_length: 50
                    data_type: string
                    note: Updated note
                  - field: TEN_DON_VI
                    required: true
                    max_length: 250
                    data_type: string
                """);

        assertThat(service.importRules()).isEqualTo(2);

        verify(repository).deleteAll(argThat(obsoleteRules -> {
            List<ValidationRule> deleted = new ArrayList<>();
            obsoleteRules.forEach(deleted::add);
            return deleted.size() == 1 && deleted.contains(obsolete);
        }));
        verify(repository).saveAll(any());
        assertThat(savedRules).hasSize(2);
        assertThat(savedRules.get(0)).isSameAs(existing);
        assertThat(existing.getId()).isEqualTo(7L);
        assertThat(existing.getRequired()).isTrue();
        assertThat(existing.getMaxLength()).isEqualTo(50);
        assertThat(existing.getDataType()).isEqualTo("string");
        assertThat(existing.getNote()).isEqualTo("Updated note");
        assertThat(savedRules.get(1).getField()).isEqualTo("TEN_DON_VI");
        assertThat(savedRules.get(1).getPh()).isEqualTo("COSOGIAODUC");
        assertThat(savedRules.get(1).getEntity()).isEqualTo("_CO_SO_GIAO_DUC");
    }

    @Test
    @DisplayName("FR-VAL-01: unique key (ph, entity, field) rejects duplicate fields in YAML")
    void rejectsDuplicateFieldsBeforeRepositoryAccess() {
        ValidationRuleImportService service = serviceFor("""
                ph: COSOGIAODUC
                entity: _CO_SO_GIAO_DUC
                rules:
                  - field: Id
                  - field: Id
                """);

        assertThatThrownBy(service::importRules)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Duplicate validation rule field: Id");
        verifyNoInteractions(repository);
    }

    @Test
    @DisplayName("Imports the packaged COSOGIAODUC rule YAML")
    void importsPackagedRules() {
        when(repository.findByPhAndEntity("COSOGIAODUC", "_CO_SO_GIAO_DUC")).thenReturn(List.of());
        ValidationRuleImportService service = new ValidationRuleImportService(
                repository, new ClassPathResource("rules/cosogiaoduc.yml"));

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

    private ValidationRuleImportService serviceFor(String yaml) {
        return new ValidationRuleImportService(
                repository,
                new ByteArrayResource(yaml.getBytes(StandardCharsets.UTF_8)));
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
