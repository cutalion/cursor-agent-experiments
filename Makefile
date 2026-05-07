.PHONY: bootstrap validate up down logs smoke prod-up prod-down ollama-up

bootstrap:
	sh scripts/bootstrap-env.sh

validate:
	sh scripts/check-config.sh

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f --tail=100

smoke:
	sh scripts/smoke-test.sh

prod-up:
	docker compose -f docker-compose.yml up -d

prod-down:
	docker compose -f docker-compose.yml down

ollama-up:
	docker compose --profile local-models up -d
