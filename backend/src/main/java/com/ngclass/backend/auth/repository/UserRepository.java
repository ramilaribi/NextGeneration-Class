package com.ngclass.backend.auth.repository;

import com.ngclass.backend.auth.domain.Role;
import com.ngclass.backend.auth.domain.User;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface UserRepository extends JpaRepository<User, UUID> {
	Optional<User> findByUsername(String username);

	Optional<User> findByPhone(String phone);

	boolean existsByUsername(String username);

	boolean existsByRole(Role role);

	List<User> findByRoleOrderByCreatedAtAsc(Role role);

	boolean existsByPhone(String phone);

	boolean existsByPhoneAndIdNot(String phone, UUID id);

	boolean existsByUsernameAndIdNot(String username, UUID id);

	/** Usernames starting with this base, to pick the next free suffix ("prenom.nom2"). */
	@Query("select u.username from User u where u.username = :base or u.username like concat(:base, '%')")
	List<String> findUsernamesLike(@Param("base") String base);

	@Query("select u.mustChangePassword from User u where u.id = :id")
	Optional<Boolean> findMustChangePassword(@Param("id") UUID id);

	/** A parent who has not accepted [version] of the privacy notice yet. */
	@Query("""
			select count(u) > 0 from User u where u.id = :id and u.role = com.ngclass.backend.auth.domain.Role.PARENT
			and (u.privacyVersion is null or u.privacyVersion < :version)""")
	boolean privacyRequired(@Param("id") UUID id, @Param("version") int version);
}
