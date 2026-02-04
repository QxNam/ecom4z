
### All services
up:
	docker compose \
	  -f infra/docker/compose/docker-compose.yml \
	  up -d
down:
	docker compose \
	  -f infra/docker/compose/docker-compose.yml \
	  down
down-v:
	docker compose \
	  -f infra/docker/compose/docker-compose.yml \
	  down -v


### Infra services
infra-up:
	docker compose -f infra/docker/compose/docker-compose.infra.yml up -d

infra-down:
	docker compose -f infra/docker/compose/docker-compose.infra.yml down

infra-down-v:
	docker compose -f infra/docker/compose/docker-compose.infra.yml down -v

infra-logs:
	docker compose -f infra/docker/compose/docker-compose.infra.yml logs -f

infra-ps:
	docker compose -f infra/docker/compose/docker-compose.infra.yml ps

### Application services
app-up:
	docker compose -f infra/docker/compose/docker-compose.app.yml up -d

app-down:
	docker compose -f infra/docker/compose/docker-compose.app.yml down

app-down-v:
	docker compose -f infra/docker/compose/docker-compose.app.yml down -v

app-logs:
	docker compose -f infra/docker/compose/docker-compose.app.yml logs -f

app-ps:
	docker compose -f infra/docker/compose/docker-compose.app.yml ps

### Monitoring services
obs-up:
	docker compose -f infra/docker/compose/docker-compose.obs.yml up -d

obs-down:
	docker compose -f infra/docker/compose/docker-compose.obs.yml down

obs-down-v:
	docker compose -f infra/docker/compose/docker-compose.obs.yml down -v

obs-logs:
	docker compose -f infra/docker/compose/docker-compose.obs.yml logs -f

obs-ps:
	docker compose -f infra/docker/compose/docker-compose.obs.yml ps

