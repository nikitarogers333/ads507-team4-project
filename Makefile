###############################################################################
# ADS-507 Team 4 – Makefile shortcuts
###############################################################################

.PHONY: up down pipeline logs status clean test help

help: ## Show this help message
	@echo "ADS-507 E-Commerce Pipeline – available commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*##"}; {printf "  make %-14s %s\n", $$1, $$2}'
	@echo ""

up: ## Start MySQL + Adminer + run full pipeline
	docker compose up

up-db: ## Start only MySQL and Adminer (no pipeline)
	docker compose up -d mysql adminer

down: ## Stop all containers
	docker compose down

pipeline: ## Run the ETL pipeline (requires MySQL to be running)
	docker compose run --rm pipeline

logs: ## Show pipeline logs
	docker compose logs -f pipeline

status: ## Check container status
	docker compose ps

monitor: ## Show live monitoring dashboard
	docker compose exec mysql mysql -u root -p$${MYSQL_ROOT_PASSWORD} $${MYSQL_DATABASE} < sql/validation/050_validate.sql

clean: ## Remove all containers, volumes, and data
	docker compose down -v --remove-orphans

test: ## Run automated tests
	bash tests/test_pipeline.sh

reset: ## Full reset – remove everything and start fresh
	docker compose down -v --remove-orphans
	docker compose up
