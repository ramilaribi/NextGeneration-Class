// The front of NextGeneration Class on Cloudflare Workers (docs/05-deployment/07-CLOUDFLARE.md).
// The Flutter web build is served as static assets; /api/* and /health go to the backend server
// (Spring Boot + PostgreSQL), so the app keeps calling its own address + /api/v1 (app_config.dart).
export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		// Only /api/* and /health reach this code (run_worker_first in wrangler.jsonc). The www redirect is a
		// Cloudflare Redirect Rule, since page requests on www never come through here.
		if (url.pathname.startsWith("/api/") || url.pathname === "/health") {
			const target = new URL(env.BACKEND_ORIGIN);
			// Same path on the server: its Caddy forwards /api/* and turns /health into the API's health check
			// (UP only when the API and the database both work, for the uptime alert).
			target.pathname = url.pathname;
			target.search = url.search;
			const headers = new Headers(request.headers);
			headers.set("X-Forwarded-Host", url.host);
			headers.set("X-Forwarded-Proto", "https");
			const ip = request.headers.get("CF-Connecting-IP");
			if (ip) headers.set("X-Forwarded-For", ip);
			try {
				return await fetch(target, {
					method: request.method,
					headers,
					body: request.body,
					redirect: "manual",
				});
			} catch {
				// The app shows its "cannot reach the server" state for this.
				return new Response(JSON.stringify({ code: "unavailable" }), {
					status: 502,
					headers: { "Content-Type": "application/json" },
				});
			}
		}

		return env.ASSETS.fetch(request);
	},
};
