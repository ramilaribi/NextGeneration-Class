package com.ngclass.backend.auth.filter;

import com.ngclass.backend.auth.repository.UserRepository;
import com.ngclass.backend.auth.domain.Role;
import com.ngclass.backend.auth.service.AuthenticatedUser;
import com.ngclass.backend.common.JsonErrorWriter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * An account closed while signed in (a teacher closed by the owner, a pupil archived with their parents) is refused
 * at once: its access token would otherwise work until it expires. 401, so the app tries its refresh token, which
 * closing revoked, and the session ends.
 *
 * A user with a temporary password (created or reset by the teacher) can only read their profile,
 * change the password or the language, and sign out, until they choose their own password. The app
 * enforces it too; this keeps the API honest when called directly.
 */
@Component
@RequiredArgsConstructor
public class PasswordChangeFilter extends OncePerRequestFilter {
	private static final Set<String> ALLOWED = Set.of("/api/v1/me", "/api/v1/me/password", "/api/v1/me/language");

	private final UserRepository users;
	private final JsonErrorWriter errorWriter;

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {
		Authentication auth = SecurityContextHolder.getContext().getAuthentication();
		if (auth != null && auth.getPrincipal() instanceof AuthenticatedUser user) {
			UserRepository.AccessState state = users.findAccessState(user.id()).orElse(null);
			if (state == null || !Boolean.TRUE.equals(state.getActive())) {
				SecurityContextHolder.clearContext();
				errorWriter.write(request, response, HttpStatus.UNAUTHORIZED,
						user.role() == Role.TEACHER ? "teacher_disabled" : "account_disabled");
				return;
			}
			if (!allowed(request.getRequestURI()) && Boolean.TRUE.equals(state.getMustChangePassword())) {
				errorWriter.write(request, response, HttpStatus.FORBIDDEN, "password_change_required");
				return;
			}
		}
		filterChain.doFilter(request, response);
	}

	private static boolean allowed(String path) {
		return ALLOWED.contains(path) || path.startsWith("/api/v1/auth/") || path.startsWith("/actuator/");
	}
}
