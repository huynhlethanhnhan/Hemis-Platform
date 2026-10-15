package vn.edu.hcmue.hemis.journal;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SyncBatchRepository extends JpaRepository<SyncBatch, Long> {

    Optional<SyncBatch> findByIks(UUID iks);

    Optional<SyncBatch> findByIdKey(UUID idKey);

    List<SyncBatch> findByPhOrderByCreatedAtDesc(String ph, Pageable pageable);

    List<SyncBatch> findByStatusOrderByCreatedAtAsc(SyncBatch.Status status);
}
