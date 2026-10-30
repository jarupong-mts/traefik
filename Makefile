# Thin wrappers around Docker Compose. The first `make up` (or `make start`) creates
# .env (per host, gitignored) after asking for the public port. Compose reads .env
# itself, so plain `docker compose up -d` works once it exists. See .env.example.

SHELL := /bin/sh
.DEFAULT_GOAL := help

ENV_FILE := .env

.PHONY: help up setup check start stop restart ps logs

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

# Asks for the public port (Enter keeps 18080) and detects the rootless socket dir.
$(ENV_FILE):
	@printf "Public port for Traefik [18080]: "; read port; \
	port=$${port:-18080}; \
	case "$$port" in ''|*[!0-9]*) echo "Port must be a number"; exit 1;; esac; \
	if [ "$$port" -lt 1 ] || [ "$$port" -gt 65535 ]; then echo "Port must be 1-65535"; exit 1; fi; \
	xdg=$${XDG_RUNTIME_DIR:-/run/user/$$(id -u)}; \
	printf 'TRAEFIK_HTTP_PORT=%s\nXDG_RUNTIME_DIR=%s\nDOCKER_SOCKET=%s/docker.sock\n' "$$port" "$$xdg" "$$xdg" > $@; \
	echo "Wrote $@"

setup: ## Re-create .env (overwrites it and asks for the port again)
	@rm -f $(ENV_FILE)
	@$(MAKE) --no-print-directory $(ENV_FILE)

check: $(ENV_FILE) ## Verify the Docker socket from .env exists
	@set -a; . ./$(ENV_FILE); set +a; \
	test -S "$$DOCKER_SOCKET" || { \
		echo "Docker socket not found: $$DOCKER_SOCKET"; \
		echo "Fix XDG_RUNTIME_DIR or DOCKER_SOCKET in $(ENV_FILE) (or run make setup) and retry."; \
		exit 1; }

start: check ## Start Traefik in the background
	docker compose up -d
	@set -a; . ./$(ENV_FILE); set +a; echo "Traefik is listening on http://localhost:$$TRAEFIK_HTTP_PORT"

up: start ## Same as start

stop: ## Stop Traefik (keeps the proxy network for other projects)
	docker compose stop

restart: check ## Restart Traefik
	docker compose restart

ps: ## Show container status
	docker compose ps

logs: ## Follow Traefik logs
	docker compose logs -f traefik
