package vn.edu.hcmue.hemis.journal;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ValidationRuleRepository extends JpaRepository<ValidationRule, Long> {
    List<ValidationRule> findByPhAndEntity(String ph, String entity);
}