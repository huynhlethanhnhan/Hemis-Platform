package vn.edu.hcmue.hemis.signing;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SignJobRepository extends JpaRepository<SignJob, Long> {

    List<SignJob> findByStatusOrderByCreatedAtAsc(SignJob.Status status, Pageable pageable);

    Optional<SignJob> findFirstByBatchIdOrderByIdDesc(Long batchId);
}
