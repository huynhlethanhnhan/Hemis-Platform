package vn.edu.hcmue.hemis.service;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.yaml.snakeyaml.LoaderOptions;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.SafeConstructor;

import vn.edu.hcmue.hemis.journal.ValidationRule;
import vn.edu.hcmue.hemis.journal.ValidationRuleRepository;

@Service
public class ValidationRuleImportService implements ApplicationRunner {

    private final ValidationRuleRepository repository;
    private final Resource ruleFile;

    public ValidationRuleImportService(
            ValidationRuleRepository repository,
            @Value("classpath:rules/cosogiaoduc.yml") Resource ruleFile) {
        this.repository = repository;
        this.ruleFile = ruleFile;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        importRules();
    }

    @Transactional
    public int importRules() {
        RuleSet ruleSet = readRuleSet();
        List<ValidationRule> existingRules =
                repository.findByPhAndEntity(ruleSet.ph(), ruleSet.entity());
        Map<String, ValidationRule> existingByField = new HashMap<>();
        for (ValidationRule rule : existingRules) {
            existingByField.put(rule.getField(), rule);
        }

        List<ValidationRule> importedRules = new ArrayList<>();
        for (RuleDefinition definition : ruleSet.rules()) {
            ValidationRule rule = existingByField.remove(definition.field());
            if (rule == null) {
                rule = new ValidationRule();
            }
            rule.setPh(ruleSet.ph());
            rule.setEntity(ruleSet.entity());
            rule.setField(definition.field());
            rule.setRequired(definition.required());
            rule.setMaxLength(definition.maxLength());
            rule.setDataType(definition.dataType());
            rule.setCatalogName(definition.catalogName());
            rule.setConditionExpr(definition.conditionExpr());
            rule.setNote(definition.note());
            importedRules.add(rule);
        }

        repository.deleteAll(existingByField.values());
        repository.saveAll(importedRules);
        return importedRules.size();
    }

    private RuleSet readRuleSet() {
        try (InputStream input = ruleFile.getInputStream()) {
            Object loaded = new Yaml(new SafeConstructor(new LoaderOptions())).load(input);
            Map<?, ?> root = requireMap(loaded, "root");
            String ph = requiredString(root, "ph");
            String entity = requiredString(root, "entity");
            Object rulesValue = root.get("rules");
            if (!(rulesValue instanceof List<?> ruleEntries)) {
                throw new IllegalStateException("The validation rule YAML must contain a rules list");
            }

            Map<String, RuleDefinition> rulesByField = new LinkedHashMap<>();
            for (Object entry : ruleEntries) {
                Map<?, ?> values = requireMap(entry, "rule");
                String field = requiredString(values, "field");
                RuleDefinition definition = new RuleDefinition(
                        field,
                        optionalBoolean(values, "required", false),
                        optionalInteger(values, "max_length", 0),
                        optionalString(values, "data_type"),
                        optionalString(values, "catalog_name"),
                        optionalString(values, "condition_expr"),
                        optionalString(values, "note"));
                if (rulesByField.putIfAbsent(field, definition) != null) {
                    throw new IllegalStateException("Duplicate validation rule field: " + field);
                }
            }
            return new RuleSet(ph, entity, List.copyOf(rulesByField.values()));
        } catch (IOException e) {
            throw new IllegalStateException("Could not read validation rule YAML: " + ruleFile, e);
        }
    }

    private static Map<?, ?> requireMap(Object value, String description) {
        if (value instanceof Map<?, ?> map) {
            return map;
        }
        throw new IllegalStateException("Expected a mapping for validation rule " + description);
    }

    private static String requiredString(Map<?, ?> values, String key) {
        String value = optionalString(values, key);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Missing required validation rule property: " + key);
        }
        return value;
    }

    private static String optionalString(Map<?, ?> values, String key) {
        Object value = values.get(key);
        if (value == null) {
            return null;
        }
        if (value instanceof String string) {
            return string;
        }
        throw new IllegalStateException("Validation rule property '" + key + "' must be a string");
    }

    private static Boolean optionalBoolean(Map<?, ?> values, String key, boolean defaultValue) {
        Object value = values.get(key);
        if (value == null) {
            return defaultValue;
        }
        if (value instanceof Boolean bool) {
            return bool;
        }
        throw new IllegalStateException("Validation rule property '" + key + "' must be a boolean");
    }

    private static int optionalInteger(Map<?, ?> values, String key, int defaultValue) {
        Object value = values.get(key);
        if (value == null) {
            return defaultValue;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        throw new IllegalStateException("Validation rule property '" + key + "' must be an integer");
    }

    private record RuleSet(String ph, String entity, List<RuleDefinition> rules) {}

    private record RuleDefinition(
            String field,
            Boolean required,
            int maxLength,
            String dataType,
            String catalogName,
            String conditionExpr,
            String note) {}
}
