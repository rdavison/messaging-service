.PHONY: setup run test clean clean-test help db-up db-down db-logs db-shell

help:
	@echo "Available commands:"
	@echo "  setup      - Set up the project environment and start database"
	@echo "  run        - Run the application"
	@echo "  test       - Run tests"
	@echo "  clean      - Clean up temporary files and stop containers"
	@echo "  clean-test - Clean up test database only"
	@echo "  db-up      - Start the PostgreSQL database"
	@echo "  db-down    - Stop the PostgreSQL database"
	@echo "  db-logs    - Show database logs"
	@echo "  db-shell   - Connect to the database shell"
	@echo "  help       - Show this help message"

setup:
	@echo "Setting up the project..."
	@docker compose build --pull
	@echo "Starting PostgreSQL database..."
	@docker compose up db-reinit
	@echo "Setup complete!"

run:
	@echo "Running the application..."
	@./bin/start.sh

test:
	@echo "Running tests..."
	@echo "Starting test database if not running..."
	@docker compose up -d test-db test-apiserver test-processor
	@echo "Running test script..."
	@./bin/test.sh
	@echo "Tearing down test services"
	@docker compose stop test-db test-apiserver test-processor
	@docker compose rm -f test-db test-apiserver test-processor

clean-test:
	@echo "Cleaning up test db..."
	@echo "Stopping and removing containers..."
	@docker compose stop test-db
	@docker compose rm -f test-db
	@echo "Removing any temporary files..."
	@rm -rf *.log *.tmp

clean:
	@echo "Cleaning up..."
	@echo "Stopping and removing containers (and volumes)..."
	@docker compose down -v
	@echo "Removing any temporary files..."
	@rm -rf *.log *.tmp

db-up:
	@echo "Starting PostgreSQL database..."
	@docker compose up -d app-db

db-stop:
	@echo "Stopping PostgreSQL database..."
	@docker compose stop app-db

db-rm:
	@echo "Destroying PostgreSQL database..."
	@docker compose rm -f app-db

db-logs:
	@echo "Showing database logs..."
	@docker compose logs -f app-db

db-shell:
	@echo "Connecting to database shell..."
	@docker compose exec app-db psql -U app-db-user -d app-db-id
