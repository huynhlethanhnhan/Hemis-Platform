package vn.edu.hcmue.hemis.journal;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CatalogHemisRepository extends JpaRepository<CatalogHemis, Long> {

    Optional<CatalogHemis> findByDmNameAndMa(String dmName, String ma);

    List<CatalogHemis> findByDmNameIn(Collection<String> dmNames);
}
