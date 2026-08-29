.PHONY: up down restart logs ps config backup restore clean secrets

# Bring the stack up (build Node-RED image if needed)
up:
	docker compose up -d --build

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f --tail=200

ps:
	docker compose ps

# Validate compose file + interpolated env without starting anything
config:
	docker compose config

# Dump InfluxDB data + Node-RED flows to ./backups/<timestamp>/
backup:
	@mkdir -p backups/$$(date +%Y%m%d-%H%M%S)
	@BK=backups/$$(date +%Y%m%d-%H%M%S); \
	docker compose exec -T influxdb influx backup /tmp/backup --org "$${INFLUXDB_ORG}" && \
	docker cp $$(docker compose ps -q influxdb):/tmp/backup "$$BK/influxdb" && \
	docker cp $$(docker compose ps -q node-red):/data/flows.json "$$BK/flows.json" && \
	echo "Backup written to $$BK"

# Generate fresh random secrets for .env (prints to stdout — paste manually)
secrets:
	@echo "INFLUXDB_INIT_ADMIN_TOKEN=$$(openssl rand -hex 32)"
	@echo "INFLUXDB_TOKEN=<same value as above>"
	@echo "NODE_RED_CREDENTIAL_SECRET=$$(openssl rand -hex 32)"
	@echo "INFLUXDB_INIT_PASSWORD=$$(openssl rand -base64 18)"
	@echo "GRAFANA_ADMIN_PASSWORD=$$(openssl rand -base64 18)"

# DANGER: removes containers AND volumes (all InfluxDB/Grafana/Node-RED data)
#clean:
#	docker compose down -v
