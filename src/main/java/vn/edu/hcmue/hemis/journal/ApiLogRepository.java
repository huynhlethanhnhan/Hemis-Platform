package vn.edu.hcmue.hemis.journal;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface ApiLogRepository extends JpaRepository<ApiLog, Long> {

    List<ApiLog> findByBatchIdOrderByCreatedAtAsc(Long batchId);
}
