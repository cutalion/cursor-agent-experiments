# Convenience wrappers around scripts/. `make help` for the full list.

SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

.PHONY: help dev dev-down prod prod-down logs ps restart pull config keys hash test \
        prod-pg prod-pg-ollama

help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Targets:\n"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dev: ## Bring up dev stack (litellm:4000, caddy:8080).
	./scripts/dev-up.sh

dev-down: ## Stop dev stack.
	./scripts/dev-down.sh

prod: ## Bring up prod stack (Caddy on 80/443).
	./scripts/prod-up.sh

prod-pg: ## Prod stack + Postgres overlay.
	./scripts/prod-up.sh -f compose/postgres.yml

prod-pg-ollama: ## Prod stack + Postgres + Ollama.
	./scripts/prod-up.sh -f compose/postgres.yml -f compose/ollama.yml

prod-down: ## Stop prod stack.
	./scripts/prod-down.sh

logs: ## Tail all logs (use `make logs s=litellm` for one service).
	./scripts/logs.sh $(s)

ps: ## Show service status.
	docker compose ps

restart: ## Restart a service: make restart s=litellm
	docker compose restart $(s)

pull: ## Pull latest images.
	docker compose pull

config: ## Print the merged compose config (great for debugging overrides).
	docker compose config

keys: ## Print fresh master/salt keys (append to .env yourself).
	./scripts/gen-keys.sh

hash: ## Generate a Caddy basic-auth hash (reads password from stdin).
	./scripts/caddy-hash.sh

test: ## Smoke-test the gateway with a chat completion. make test m=gpt-4o
	./scripts/test-request.sh $(m)
