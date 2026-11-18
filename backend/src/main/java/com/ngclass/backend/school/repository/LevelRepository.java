package com.ngclass.backend.school.repository;

import com.ngclass.backend.school.domain.Level;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface LevelRepository extends JpaRepository<Level, UUID> {
	/** Every level of every space: labels only (search), never a choice offered to a teacher. */
	List<Level> findAllByOrderByPositionAsc();

	/** What a teacher can choose: the shared levels, then her own. */
	@Query("select l from Level l where l.teacherId is null or l.teacherId = :teacherId order by l.position, lower(l.nameFr)")
	List<Level> findVisible(@Param("teacherId") UUID teacherId);

	@Query("select l from Level l where l.teacherId is null order by l.position")
	List<Level> findShared();

	@Query("select l from Level l where l.id = :id and (l.teacherId is null or l.teacherId = :teacherId)")
	Optional<Level> findVisibleById(@Param("id") UUID id, @Param("teacherId") UUID teacherId);

	Optional<Level> findByIdAndTeacherId(UUID id, UUID teacherId);

	List<Level> findByTeacherIdOrderByPositionAsc(UUID teacherId);

	@Query("select count(l) > 0 from Level l where lower(l.nameFr) = lower(:nameFr) and (l.teacherId is null or l.teacherId = :teacherId)")
	boolean existsVisibleName(@Param("teacherId") UUID teacherId, @Param("nameFr") String nameFr);

	Optional<Level> findByNameFr(String nameFr);
}
