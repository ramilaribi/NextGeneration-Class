package com.ngclass.backend.auth.filter;

import com.ngclass.backend.auth.repository.UserRepository;
import com.ngclass.backend.auth.service.AuthenticatedUser;
import com.ngclass.backend.auth.service.Privacy;
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
 * A parent who has not accepted the privacy notice can only read their profile and the notice, accept it, change
 * the password or the language, and sign out: their child's space stays closed until then. The app enforces it too.
 */
@Component
@RequiredArgsConstructor
public class PrivacyConsentFilter extends OncePerRequestFilter {
	private static final Set<String> ALLOWED = Set.of("/api/v1/me", "/api/v1/me/password", "/api/v1/me/language", "/api/v1/me/privacy");

	private final UserRepository users;
	private final JsonErrorWriter errorWriter;

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
			throws ServletException, IOException {
		Authentication auth = SecurityContextHolder.getContext().getAuthentication();
		String path = request.getRequestURI();
		if (auth != null && auth.getPrincipal() instanceof AuthenticatedUser user
				&& !ALLOWED.contains(path) && !path.startsWith("/api/v1/auth/") && !path.startsWith("/actuator/")
				&& users.privacyRequired(user.id(), Privacy.VERSION)) {
			errorWriter.write(request, response, HttpStatus.FORBIDDEN, "privacy_required");
			return;
		}
		filterChain.doFilter(request, response);
	}
}
