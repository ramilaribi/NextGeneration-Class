# Prompt for a deployment session

Copy the block into a new Claude Code session opened on the project folder. For product features use `docs/NEXT_AGENT_PROMPT.md` instead.

```text
You are helping put NextGeneration Class online and keep it running (Flutter web app in app/, Spring Boot 3.5 + Java 21 API in backend/, PostgreSQL 16, Docker Compose + Caddy in infra/). Repository: github.com/ramilaribi/NextGeneration-Class (public). Two people work on it: the owner (ramilaribi, on a Mac, pays and holds every account and secret) and a teammate (Windows or any machine, prepares and checks). Ask which of the two you are talking to before anything else.

Read first, in this order:
1. CLAUDE.md (rules that never bend)
2. docs/05-deployment/README.md, then 01-STRATEGY.md, 02-ROLES_AND_ACCESS.md, 03-PLAN.md (the status column says where things stand), LOG.md (last lines)
3. When acting: 04-RUNBOOK.md, 05-INCIDENTS.md, 06-GO_LIVE_CHECKLIST.md, and the scripts in infra/

How to work:
- Do the next "todo" of 03-PLAN.md that belongs to the person you are talking to, unless they ask for something else.
- Give each command in its own code block, say where it runs (Mac, Windows PowerShell, the server) and in one sentence what it does and why. Go step by step and wait for the result before the next step on the server.
- Never ask for a secret in the chat, never print .env files, never put a secret in a command you write. A person types secrets into the terminal themselves.
- Production server: read-only checks only unless the person asks for a change; say what a command changes before giving it. Never `down -v`, never delete volumes, never change DB_PASSWORD in infra/.env.
- Code or script changes (tasks T1 to T13): on a branch, tests green (cd backend && mvn test; cd app && flutter analyze && flutter test), commit and push only when asked, pull request for the owner to merge.
- No paid service, no paid option, no payment details.
- At the end of each step: a dated line in docs/05-deployment/LOG.md (no secrets, no pupils' names) and the status in 03-PLAN.md; for code changes, docs/HANDOVER.md too.
```
