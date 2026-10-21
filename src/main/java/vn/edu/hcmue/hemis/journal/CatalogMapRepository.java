package vn.edu.hcmue.hemis.journal;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CatalogMapRepository extends JpaRepository<CatalogMap, Long> {

    Optional<CatalogMap> findByDmNameAndLocalCode(String dmName, String localCode);
}
