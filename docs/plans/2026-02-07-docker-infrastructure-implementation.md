# Docker Infrastructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build and deploy a multi-service Docker infrastructure stack for the Meridian Lex autonomous agent system with 15 services across 5 functional groups.

**Architecture:** Services organized by function (core, storage, communication, observability, utilities) with multi-tier network segmentation (frontend, backend, monitoring). Automated dependency orchestration with healthchecks. Integrated with Lex secrets management system.

**Tech Stack:** Docker Compose v3.8+, nginx/Caddy (API Gateway), bash scripts, PostgreSQL 16+pgvector, Qdrant, OpenSearch, Memgraph, RabbitMQ, Prometheus, Grafana, Loki, Traefik v3, Authelia, ntfy, Portainer, FileBrowser, Watchtower

---

## Task 1: Repository Structure Setup

**Files:**
- Create: `core/.gitkeep`
- Create: `storage/.gitkeep`
- Create: `communication/.gitkeep`
- Create: `observability/.gitkeep`
- Create: `utilities/.gitkeep`
- Create: `scripts/.gitkeep`
- Modify: `.gitignore`

**Step 1: Create service group directories**

```bash
mkdir -p core storage communication observability utilities scripts
touch core/.gitkeep storage/.gitkeep communication/.gitkeep observability/.gitkeep utilities/.gitkeep scripts/.gitkeep
```

**Step 2: Update.gitignore for Docker artifacts**

Add to `.gitignore`:
```
# Docker artifacts
docker-secrets.env
.env

# Generated configs
*/config/generated/
```

**Step 3: Verify structure**

Run: `tree -L 1`
Expected: Shows all service group directories and scripts/

**Step 4: Commit**

```bash
git add.
git commit -m "feat: create service group directory structure"
git push origin master
```

---

## Task 2: Secrets Management Script

**Files:**
- Create: `scripts/init-docker-secrets.sh`
- Create: `scripts/.secrets-template.yaml`

**Step 1: Create secrets template**

File: `scripts/.secrets-template.yaml`
```yaml
# Template for docker_services section in ~/.config/secrets.yaml
docker_services:
  postgres:
    postgres_password: ""
    lex_db_password: ""
  rabbitmq:
    admin_password: ""
    erlang_cookie: ""
  authelia:
    jwt_secret: ""
    session_secret: ""
    encryption_key: ""
  opensearch:
    admin_password: ""
  grafana:
    admin_password: ""
```

**Step 2: Write secrets initialization script**

File: `scripts/init-docker-secrets.sh`
```bash
#!/bin/bash
set -euo pipefail

# Secrets initialization for lex-docker infrastructure
# Integrates with Meridian Lex ~/.config/secrets.yaml

SECRETS_FILE="$HOME/.config/secrets.yaml"
DOCKER_SECRETS_ENV="$(dirname "$0")/../docker-secrets.env"

echo "==> Initializing Docker secrets for lex-docker"

# Check if secrets.yaml exists
if [[! -f "$SECRETS_FILE" ]]; then
    echo "ERROR: $SECRETS_FILE not found"
    exit 1
fi

# Function to generate secure random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to check if docker_services section exists
check_docker_services_section() {
    grep -q "^docker_services:" "$SECRETS_FILE"
}

# Function to get value from secrets.yaml
get_secret() {
    local key="$1"
    yq eval ".docker_services.$key" "$SECRETS_FILE" 2>/dev/null || echo "null"
}

# Function to set value in secrets.yaml
set_secret() {
    local key="$1"
    local value="$2"

    # Create docker_services section if it doesn't exist
    if! check_docker_services_section; then
        echo "docker_services:" >> "$SECRETS_FILE"
    fi

    # Set the value using yq
    yq eval -i ".docker_services.$key = \"$value\"" "$SECRETS_FILE"
}

# Ensure yq is available
if! command -v yq &> /dev/null; then
    echo "ERROR: yq is required but not installed"
    echo "Install with: sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
    exit 1
fi

# Generate or read secrets
declare -A SECRETS

# PostgreSQL
SECRETS[POSTGRES_PASSWORD]=$(get_secret "postgres.postgres_password")
if [[ "${SECRETS[POSTGRES_PASSWORD]}" == "null" ]]; then
    SECRETS[POSTGRES_PASSWORD]=$(generate_password)
    set_secret "postgres.postgres_password" "${SECRETS[POSTGRES_PASSWORD]}"
fi

SECRETS[LEX_DB_PASSWORD]=$(get_secret "postgres.lex_db_password")
if [[ "${SECRETS[LEX_DB_PASSWORD]}" == "null" ]]; then
    SECRETS[LEX_DB_PASSWORD]=$(generate_password)
    set_secret "postgres.lex_db_password" "${SECRETS[LEX_DB_PASSWORD]}"
fi

# RabbitMQ
SECRETS[RABBITMQ_PASSWORD]=$(get_secret "rabbitmq.admin_password")
if [[ "${SECRETS[RABBITMQ_PASSWORD]}" == "null" ]]; then
    SECRETS[RABBITMQ_PASSWORD]=$(generate_password)
    set_secret "rabbitmq.admin_password" "${SECRETS[RABBITMQ_PASSWORD]}"
fi

SECRETS[RABBITMQ_ERLANG_COOKIE]=$(get_secret "rabbitmq.erlang_cookie")
if [[ "${SECRETS[RABBITMQ_ERLANG_COOKIE]}" == "null" ]]; then
    SECRETS[RABBITMQ_ERLANG_COOKIE]=$(generate_password)
    set_secret "rabbitmq.erlang_cookie" "${SECRETS[RABBITMQ_ERLANG_COOKIE]}"
fi

# Authelia
SECRETS[AUTHELIA_JWT_SECRET]=$(get_secret "authelia.jwt_secret")
if [[ "${SECRETS[AUTHELIA_JWT_SECRET]}" == "null" ]]; then
    SECRETS[AUTHELIA_JWT_SECRET]=$(generate_password)
    set_secret "authelia.jwt_secret" "${SECRETS[AUTHELIA_JWT_SECRET]}"
fi

SECRETS[AUTHELIA_SESSION_SECRET]=$(get_secret "authelia.session_secret")
if [[ "${SECRETS[AUTHELIA_SESSION_SECRET]}" == "null" ]]; then
    SECRETS[AUTHELIA_SESSION_SECRET]=$(generate_password)
    set_secret "authelia.session_secret" "${SECRETS[AUTHELIA_SESSION_SECRET]}"
fi

SECRETS[AUTHELIA_ENCRYPTION_KEY]=$(get_secret "authelia.encryption_key")
if [[ "${SECRETS[AUTHELIA_ENCRYPTION_KEY]}" == "null" ]]; then
    SECRETS[AUTHELIA_ENCRYPTION_KEY]=$(generate_password)
    set_secret "authelia.encryption_key" "${SECRETS[AUTHELIA_ENCRYPTION_KEY]}"
fi

# OpenSearch
SECRETS[OPENSEARCH_PASSWORD]=$(get_secret "opensearch.admin_password")
if [[ "${SECRETS[OPENSEARCH_PASSWORD]}" == "null" ]]; then
    SECRETS[OPENSEARCH_PASSWORD]=$(generate_password)
    set_secret "opensearch.admin_password" "${SECRETS[OPENSEARCH_PASSWORD]}"
fi

# Grafana
SECRETS[GRAFANA_PASSWORD]=$(get_secret "grafana.admin_password")
if [[ "${SECRETS[GRAFANA_PASSWORD]}" == "null" ]]; then
    SECRETS[GRAFANA_PASSWORD]=$(generate_password)
    set_secret "grafana.admin_password" "${SECRETS[GRAFANA_PASSWORD]}"
fi

echo "==> Secrets synchronized with $SECRETS_FILE"

# Export to docker-secrets.env
cat > "$DOCKER_SECRETS_ENV" <<EOF
# Generated by init-docker-secrets.sh - DO NOT COMMIT
# Source: ~/.config/secrets.yaml

# PostgreSQL
POSTGRES_PASSWORD=${SECRETS[POSTGRES_PASSWORD]}
LEX_DB_PASSWORD=${SECRETS[LEX_DB_PASSWORD]}

# RabbitMQ
RABBITMQ_DEFAULT_USER=admin
RABBITMQ_DEFAULT_PASS=${SECRETS[RABBITMQ_PASSWORD]}
RABBITMQ_ERLANG_COOKIE=${SECRETS[RABBITMQ_ERLANG_COOKIE]}

# Authelia
AUTHELIA_JWT_SECRET=${SECRETS[AUTHELIA_JWT_SECRET]}
AUTHELIA_SESSION_SECRET=${SECRETS[AUTHELIA_SESSION_SECRET]}
AUTHELIA_ENCRYPTION_KEY=${SECRETS[AUTHELIA_ENCRYPTION_KEY]}

# OpenSearch
OPENSEARCH_INITIAL_ADMIN_PASSWORD=${SECRETS[OPENSEARCH_PASSWORD]}

# Grafana
GF_SECURITY_ADMIN_PASSWORD=${SECRETS[GRAFANA_PASSWORD]}
EOF

chmod 600 "$DOCKER_SECRETS_ENV"
chmod 600 "$SECRETS_FILE"

echo "==> Docker secrets exported to $DOCKER_SECRETS_ENV"
echo "==> File permissions set to 600"
echo ""
echo "[OK] Secrets initialization complete"
```

**Step 3: Make script executable**

Run: `chmod +x scripts/init-docker-secrets.sh`

**Step 4: Test script (dry run check)**

Run: `bash -n scripts/init-docker-secrets.sh`
Expected: No syntax errors

**Step 5: Commit**

```bash
git add scripts/
git commit -m "feat: add secrets management integration script"
git push origin master
```

---

## Task 3: Core Services - Docker Networks

**Files:**
- Create: `core/docker-compose.yml`

**Step 1: Create core compose file with networks only**

File: `core/docker-compose.yml`
```yaml
version: '3.8'

networks:
  frontend-network:
    name: lex-frontend
    driver: bridge

  backend-network:
    name: lex-backend
    driver: bridge

  monitoring-network:
    name: lex-monitoring
    driver: bridge
```

**Step 2: Test network creation**

Run: `docker-compose -f core/docker-compose.yml up -d`
Expected: Networks created

**Step 3: Verify networks**

Run: `docker network ls | grep lex-`
Expected: Shows lex-frontend, lex-backend, lex-monitoring

**Step 4: Clean up**

Run: `docker-compose -f core/docker-compose.yml down`

**Step 5: Commit**

```bash
git add core/docker-compose.yml
git commit -m "feat(core): add Docker network definitions"
git push origin master
```

---

## Task 4: Core Services - Traefik

**Files:**
- Modify: `core/docker-compose.yml`
- Create: `core/traefik/traefik.yml`
- Create: `core/traefik/dynamic.yml`

**Step 1: Create Traefik static configuration**

File: `core/traefik/traefik.yml`
```yaml
api:
  dashboard: true
  insecure: false

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: default

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: lex-frontend
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

certificatesResolvers:
  default:
    acme:
      storage: /certs/acme.json

log:
  level: INFO

accessLog:
  filePath: "/var/log/traefik/access.log"
```

**Step 2: Create Traefik dynamic configuration**

File: `core/traefik/dynamic.yml`
```yaml
http:
  routers: {}
  services: {}

tls:
  certificates:
    - certFile: /certs/cert.pem
      keyFile: /certs/key.pem
```

**Step 3: Add Traefik service to compose**

Modify `core/docker-compose.yml`, add after networks:
```yaml
volumes:
  traefik_certs:
  portainer_data:
  authelia_config:

services:
  traefik:
    image: traefik:v3.0
    container_name: lex-traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_certs:/certs
      -./traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      -./traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro
    networks:
      - frontend-network
      - backend-network
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

**Step 4: Test Traefik deployment**

Run: `docker-compose -f core/docker-compose.yml up -d traefik`
Expected: Traefik container starts

**Step 5: Verify Traefik is running**

Run: `docker ps | grep lex-traefik`
Expected: Shows running container

**Step 6: Check Traefik logs**

Run: `docker logs lex-traefik`
Expected: No errors, shows "Configuration loaded"

**Step 7: Clean up**

Run: `docker-compose -f core/docker-compose.yml down`

**Step 8: Commit**

```bash
git add core/
git commit -m "feat(core): add Traefik reverse proxy with TLS"
git push origin master
```

---

## Task 5: Core Services - Portainer

**Files:**
- Modify: `core/docker-compose.yml`

**Step 1: Add Portainer service**

Add to `core/docker-compose.yml` services section:
```yaml
  portainer:
    image: portainer/portainer-ce:latest
    container_name: lex-portainer
    restart: unless-stopped
    ports:
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    networks:
      - frontend-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "https://localhost:9443/api/status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 2: Test Portainer deployment**

Run: `docker-compose -f core/docker-compose.yml up -d portainer`
Expected: Portainer starts

**Step 3: Verify Portainer is accessible**

Run: `curl -k https://localhost:9443/api/status`
Expected: JSON response with Portainer version

**Step 4: Clean up**

Run: `docker-compose -f core/docker-compose.yml down`

**Step 5: Commit**

```bash
git add core/docker-compose.yml
git commit -m "feat(core): add Portainer container management UI"
git push origin master
```

---

## Task 6: Core Services - Authelia

**Files:**
- Modify: `core/docker-compose.yml`
- Create: `core/authelia/configuration.yml`
- Create: `core/authelia/users_database.yml`

**Step 1: Create Authelia configuration**

File: `core/authelia/configuration.yml`
```yaml
theme: dark

server:
  host: 0.0.0.0
  port: 9091

log:
  level: info

jwt_secret: ${AUTHELIA_JWT_SECRET}

default_redirection_url: https://lex.local

totp:
  issuer: lex.local

authentication_backend:
  file:
    path: /config/users_database.yml

access_control:
  default_policy: one_factor
  rules:
    - domain: "*.lex.local"
      policy: one_factor

session:
  name: authelia_session
  secret: ${AUTHELIA_SESSION_SECRET}
  expiration: 1h
  inactivity: 5m
  domain: lex.local

regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

storage:
  encryption_key: ${AUTHELIA_ENCRYPTION_KEY}
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notification.txt
```

**Step 2: Create users database template**

File: `core/authelia/users_database.yml`
```yaml
# Users database for Authelia
# Use: authelia crypto hash generate pbkdf2 --password 'yourpassword'
# to generate password hashes

users:
  # Example user - replace with actual user
  # admin:
  # displayname: "Admin User"
  # password: "$pbkdf2-sha512$..."
  # email: admin@lex.local
  # groups:
  # - admins
```

**Step 3: Add Authelia service**

Add to `core/docker-compose.yml` services:
```yaml
  authelia:
    image: authelia/authelia:latest
    container_name: lex-authelia
    restart: unless-stopped
    env_file:
      -../docker-secrets.env
    ports:
      - "9091:9091"
    volumes:
      - authelia_config:/config
      -./authelia/configuration.yml:/config/configuration.yml:ro
      -./authelia/users_database.yml:/config/users_database.yml:ro
    networks:
      - frontend-network
    depends_on:
      traefik:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9091/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 4: Test Authelia deployment**

Run: `docker-compose -f core/docker-compose.yml up -d authelia`
Expected: Authelia starts (may fail without secrets, that's expected)

**Step 5: Check logs for configuration validation**

Run: `docker logs lex-authelia 2>&1 | head -20`
Expected: Shows configuration loading (may show env var errors without secrets)

**Step 6: Clean up**

Run: `docker-compose -f core/docker-compose.yml down`

**Step 7: Commit**

```bash
git add core/
git commit -m "feat(core): add Authelia authentication service"
git push origin master
```

---

## Task 7: Storage Services - PostgreSQL

**Files:**
- Create: `storage/docker-compose.yml`
- Create: `storage/postgres/init-db.sh`

**Step 1: Create PostgreSQL init script**

File: `storage/postgres/init-db.sh`
```bash
#!/bin/bash
set -e

# Create lex databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE lex_state;
    CREATE DATABASE lex_tasks;
    CREATE DATABASE lex_memory;

    \c lex_state
    CREATE EXTENSION IF NOT EXISTS vector;

    \c lex_tasks
    CREATE EXTENSION IF NOT EXISTS vector;

    \c lex_memory
    CREATE EXTENSION IF NOT EXISTS vector;

    -- Create lex user
    CREATE USER lex WITH PASSWORD '${LEX_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON DATABASE lex_state TO lex;
    GRANT ALL PRIVILEGES ON DATABASE lex_tasks TO lex;
    GRANT ALL PRIVILEGES ON DATABASE lex_memory TO lex;
EOSQL

echo "Lex databases initialized successfully"
```

**Step 2: Create storage compose file**

File: `storage/docker-compose.yml`
```yaml
version: '3.8'

networks:
  backend-network:
    external: true
    name: lex-backend

volumes:
  postgres_data:
  qdrant_data:
  opensearch_data:
  memgraph_data:
  rabbitmq_data:

services:
  postgres:
    image: ankane/pgvector:pg16
    container_name: lex-postgres
    restart: unless-stopped
    env_file:
      -../docker-secrets.env
    environment:
      POSTGRES_USER: postgres
      POSTGRES_DB: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      -./postgres/init-db.sh:/docker-entrypoint-initdb.d/init-db.sh:ro
    networks:
      - backend-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 3: Test PostgreSQL deployment**

Run: `docker-compose -f storage/docker-compose.yml up -d postgres`
Expected: PostgreSQL starts (will fail without secrets - expected)

**Step 4: Clean up**

Run: `docker-compose -f storage/docker-compose.yml down`

**Step 5: Commit**

```bash
git add storage/
git commit -m "feat(storage): add PostgreSQL with pgvector"
git push origin master
```

---

## Task 8: Storage Services - Qdrant

**Files:**
- Modify: `storage/docker-compose.yml`

**Step 1: Add Qdrant service**

Add to `storage/docker-compose.yml` services:
```yaml
  qdrant:
    image: qdrant/qdrant:v1.7.4
    container_name: lex-qdrant
    restart: unless-stopped
    ports:
      - "6333:6333"
    volumes:
      - qdrant_data:/qdrant/storage
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:6333/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 2: Test Qdrant deployment**

Run: `docker-compose -f storage/docker-compose.yml up -d qdrant`
Expected: Qdrant starts

**Step 3: Verify Qdrant API**

Run: `curl http://localhost:6333/`
Expected: JSON response with Qdrant version

**Step 4: Clean up**

Run: `docker-compose -f storage/docker-compose.yml down`

**Step 5: Commit**

```bash
git add storage/docker-compose.yml
git commit -m "feat(storage): add Qdrant vector database"
git push origin master
```

---

## Task 9: Storage Services - OpenSearch

**Files:**
- Modify: `storage/docker-compose.yml`

**Step 1: Add OpenSearch service**

Add to `storage/docker-compose.yml` services:
```yaml
  opensearch:
    image: opensearchproject/opensearch:2.11.1
    container_name: lex-opensearch
    restart: unless-stopped
    env_file:
      -../docker-secrets.env
    environment:
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"
      - DISABLE_SECURITY_PLUGIN=false
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - opensearch_data:/usr/share/opensearch/data
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "curl", "-f", "-k", "-u", "admin:${OPENSEARCH_INITIAL_ADMIN_PASSWORD}", "https://localhost:9200/_cluster/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

**Step 2: Test OpenSearch deployment**

Run: `docker-compose -f storage/docker-compose.yml up -d opensearch`
Expected: OpenSearch starts (will need secrets)

**Step 3: Clean up**

Run: `docker-compose -f storage/docker-compose.yml down`

**Step 4: Commit**

```bash
git add storage/docker-compose.yml
git commit -m "feat(storage): add OpenSearch for log indexing"
git push origin master
```

---

## Task 10: Storage Services - Memgraph & RabbitMQ

**Files:**
- Modify: `storage/docker-compose.yml`

**Step 1: Add Memgraph service**

Add to `storage/docker-compose.yml` services:
```yaml
  memgraph:
    image: memgraph/memgraph-platform:2.14.1
    container_name: lex-memgraph
    restart: unless-stopped
    ports:
      - "7687:7687"
      - "3001:3000"
    volumes:
      - memgraph_data:/var/lib/memgraph
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "nc", "-z", "localhost", "7687"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 2: Add RabbitMQ service**

Add to `storage/docker-compose.yml` services:
```yaml
  rabbitmq:
    image: rabbitmq:3.13-management
    container_name: lex-rabbitmq
    restart: unless-stopped
    env_file:
      -../docker-secrets.env
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - backend-network
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 3: Test deployment**

Run: `docker-compose -f storage/docker-compose.yml up -d memgraph rabbitmq`
Expected: Both services start

**Step 4: Clean up**

Run: `docker-compose -f storage/docker-compose.yml down`

**Step 5: Commit**

```bash
git add storage/docker-compose.yml
git commit -m "feat(storage): add Memgraph and RabbitMQ"
git push origin master
```

---

## Task 11: Communication Services - ntfy

**Files:**
- Create: `communication/docker-compose.yml`
- Create: `communication/ntfy/server.yml`

**Step 1: Create ntfy configuration**

File: `communication/ntfy/server.yml`
```yaml
base-url: http://localhost:2586
cache-file: /var/cache/ntfy/cache.db
cache-duration: "12h"
keepalive-interval: "45s"
manager-interval: "1m"
attachment-cache-dir: /var/cache/ntfy/attachments
attachment-total-size-limit: "5G"
attachment-file-size-limit: "100M"
```

**Step 2: Create communication compose file**

File: `communication/docker-compose.yml`
```yaml
version: '3.8'

networks:
  frontend-network:
    external: true
    name: lex-frontend
  backend-network:
    external: true
    name: lex-backend

volumes:
  ntfy_cache:
  ntfy_config:

services:
  ntfy:
    image: binwiederhier/ntfy:latest
    container_name: lex-ntfy
    restart: unless-stopped
    command: serve
    ports:
      - "2586:80"
    volumes:
      - ntfy_cache:/var/cache/ntfy
      - ntfy_config:/etc/ntfy
      -./ntfy/server.yml:/etc/ntfy/server.yml:ro
    networks:
      - frontend-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
```

**Step 3: Test ntfy deployment**

Run: `docker-compose -f communication/docker-compose.yml up -d ntfy`
Expected: ntfy starts

**Step 4: Verify ntfy is working**

Run: `curl http://localhost:2586/v1/health`
Expected: JSON with healthy status

**Step 5: Test publishing**

Run: `curl -d "Test message" http://localhost:2586/lex-system-alerts`
Expected: 200 OK

**Step 6: Clean up**

Run: `docker-compose -f communication/docker-compose.yml down`

**Step 7: Commit**

```bash
git add communication/
git commit -m "feat(communication): add ntfy messaging service"
git push origin master
```

---

## Task 12: Communication Services - API Gateway

**Files:**
- Modify: `communication/docker-compose.yml`
- Create: `communication/gateway/nginx.conf`
- Create: `communication/gateway/Dockerfile`

**Step 1: Create API Gateway nginx config**

File: `communication/gateway/nginx.conf`
```nginx
events {
    worker_connections 1024;
}

http {
    upstream postgres {
        server lex-postgres:5432;
    }

    upstream qdrant {
        server lex-qdrant:6333;
    }

    upstream opensearch {
        server lex-opensearch:9200;
    }

    upstream rabbitmq {
        server lex-rabbitmq:15672;
    }

    upstream ntfy {
        server lex-ntfy:80;
    }

    server {
        listen 8000;

        # Health check
        location /health {
            access_log off;
            return 200 "OK\n";
            add_header Content-Type text/plain;
        }

        # Qdrant proxy
        location /qdrant/ {
            proxy_pass http://qdrant/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # OpenSearch proxy
        location /opensearch/ {
            proxy_pass https://opensearch:9200/;
            proxy_ssl_verify off;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # RabbitMQ Management API proxy
        location /rabbitmq/ {
            proxy_pass http://rabbitmq/api/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # ntfy proxy
        location /ntfy/ {
            proxy_pass http://ntfy/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

**Step 2: Create Gateway Dockerfile**

File: `communication/gateway/Dockerfile`
```dockerfile
FROM nginx:alpine

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8000

CMD ["nginx", "-g", "daemon off;"]
```

**Step 3: Add gateway service**

Add to `communication/docker-compose.yml` services:
```yaml
  gateway:
    build:
      context:./gateway
      dockerfile: Dockerfile
    container_name: lex-gateway
    restart: unless-stopped
    ports:
      - "8000:8000"
    networks:
      - frontend-network
      - backend-network
    depends_on:
      - ntfy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
```

**Step 4: Test gateway deployment**

Run: `docker-compose -f communication/docker-compose.yml up -d gateway`
Expected: Gateway builds and starts

**Step 5: Verify gateway health**

Run: `curl http://localhost:8000/health`
Expected: "OK"

**Step 6: Clean up**

Run: `docker-compose -f communication/docker-compose.yml down`

**Step 7: Commit**

```bash
git add communication/
git commit -m "feat(communication): add API Gateway for host-agent bridge"
git push origin master
```

---

## Task 13: Observability Services - Prometheus

**Files:**
- Create: `observability/docker-compose.yml`
- Create: `observability/prometheus/prometheus.yml`
- Create: `observability/prometheus/alerts.yml`

**Step 1: Create Prometheus configuration**

File: `observability/prometheus/prometheus.yml`
```yaml
global:
  scrape_interval: 30s
  evaluation_interval: 30s
  external_labels:
    cluster: 'lex-docker'

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  - /etc/prometheus/alerts.yml

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'traefik'
    static_configs:
      - targets: ['lex-traefik:8080']

  - job_name: 'docker'
    static_configs:
      - targets: ['172.17.0.1:9323']
```

**Step 2: Create Prometheus alert rules**

File: `observability/prometheus/alerts.yml`
```yaml
groups:
  - name: lex_infrastructure
    interval: 30s
    rules:
      - alert: ContainerDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ $labels.instance }} is down"
          description: "{{ $labels.job }} on {{ $labels.instance }} has been down for more than 2 minutes"

      - alert: HighMemoryUsage
        expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) > 0.90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage on {{ $labels.name }}"
          description: "Container {{ $labels.name }} is using {{ $value | humanizePercentage }} of memory"

      - alert: ServiceHealthcheckFailing
        expr: container_health_status{status!="healthy"} == 1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service healthcheck failing for {{ $labels.name }}"
          description: "Container {{ $labels.name }} healthcheck has been failing for 2 minutes"
```

**Step 3: Create observability compose file**

File: `observability/docker-compose.yml`
```yaml
version: '3.8'

networks:
  monitoring-network:
    external: true
    name: lex-monitoring
  backend-network:
    external: true
    name: lex-backend
  frontend-network:
    external: true
    name: lex-frontend

volumes:
  prometheus_data:
  grafana_data:
  loki_data:

services:
  prometheus:
    image: prom/prometheus:v2.48.1
    container_name: lex-prometheus
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
    ports:
      - "9090:9090"
    volumes:
      - prometheus_data:/prometheus
      -./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      -./prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro
    networks:
      - monitoring-network
      - backend-network
      - frontend-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 4: Test Prometheus deployment**

Run: `docker-compose -f observability/docker-compose.yml up -d prometheus`
Expected: Prometheus starts

**Step 5: Verify Prometheus**

Run: `curl http://localhost:9090/-/healthy`
Expected: "Prometheus is Healthy"

**Step 6: Clean up**

Run: `docker-compose -f observability/docker-compose.yml down`

**Step 7: Commit**

```bash
git add observability/
git commit -m "feat(observability): add Prometheus metrics collection"
git push origin master
```

---

## Task 14: Observability Services - Loki, Grafana, cAdvisor

**Files:**
- Modify: `observability/docker-compose.yml`
- Create: `observability/loki/loki.yml`

**Step 1: Create Loki configuration**

File: `observability/loki/loki.yml`
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
```

**Step 2: Add Loki service**

Add to `observability/docker-compose.yml` services:
```yaml
  loki:
    image: grafana/loki:2.9.3
    container_name: lex-loki
    restart: unless-stopped
    ports:
      - "3100:3100"
    volumes:
      - loki_data:/loki
      -./loki/loki.yml:/etc/loki/local-config.yaml:ro
    command: -config.file=/etc/loki/local-config.yaml
    networks:
      - backend-network
      - monitoring-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3100/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 3: Add Grafana service**

Add to `observability/docker-compose.yml` services:
```yaml
  grafana:
    image: grafana/grafana:10.2.3
    container_name: lex-grafana
    restart: unless-stopped
    env_file:
      -../docker-secrets.env
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_INSTALL_PLUGINS=
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - monitoring-network
    depends_on:
      prometheus:
        condition: service_healthy
      loki:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Step 4: Add cAdvisor service**

Add to `observability/docker-compose.yml` services:
```yaml
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: lex-cadvisor
    restart: unless-stopped
    privileged: true
    ports:
      - "8080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
    networks:
      - monitoring-network
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

**Step 5: Test observability stack**

Run: `docker-compose -f observability/docker-compose.yml up -d`
Expected: All services start

**Step 6: Verify services**

Run: `curl http://localhost:3000/api/health && curl http://localhost:3100/ready`
Expected: Both return healthy status

**Step 7: Clean up**

Run: `docker-compose -f observability/docker-compose.yml down`

**Step 8: Commit**

```bash
git add observability/
git commit -m "feat(observability): add Loki, Grafana, and cAdvisor"
git push origin master
```

---

## Task 15: Utilities Services - FileBrowser & Watchtower

**Files:**
- Create: `utilities/docker-compose.yml`

**Step 1: Create utilities compose file**

File: `utilities/docker-compose.yml`
```yaml
version: '3.8'

networks:
  frontend-network:
    external: true
    name: lex-frontend

volumes:
  fb_db:

services:
  filebrowser:
    image: hurlenko/filebrowser:latest
    container_name: lex-filebrowser
    restart: unless-stopped
    ports:
      - "8090:8080"
    volumes:
      - /home:/data/home
      - fb_db:/database
    environment:
      - FB_BASEURL=/
    networks:
      - frontend-network
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  watchtower:
    image: containrrr/watchtower:latest
    container_name: lex-watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --interval 86400 --label-enable
    environment:
      - WATCHTOWER_NOTIFICATIONS=shoutrrr
      - WATCHTOWER_NOTIFICATION_URL=generic+http://lex-ntfy:80/lex-system-alerts
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
```

**Step 2: Test utilities deployment**

Run: `docker-compose -f utilities/docker-compose.yml up -d`
Expected: Both services start

**Step 3: Verify FileBrowser**

Run: `curl http://localhost:8090`
Expected: HTML response (FileBrowser UI)

**Step 4: Clean up**

Run: `docker-compose -f utilities/docker-compose.yml down`

**Step 5: Commit**

```bash
git add utilities/
git commit -m "feat(utilities): add FileBrowser and Watchtower"
git push origin master
```

---

## Task 16: Certificate Rotation Script

**Files:**
- Create: `scripts/rotate-certs.sh`

**Step 1: Create certificate rotation script**

File: `scripts/rotate-certs.sh`
```bash
#!/bin/bash
set -euo pipefail

# Certificate rotation for Traefik
# Generates self-signed certificates with 30-day validity

CERT_DIR="/var/lib/docker/volumes/traefik_certs/_data"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"
NTFY_URL="http://localhost:2586/lex-system-alerts"

echo "==> Rotating TLS certificates"

# Check if Traefik volume exists
if [[! -d "$CERT_DIR" ]]; then
    echo "ERROR: Traefik certs volume not found at $CERT_DIR"
    exit 1
fi

# Generate new certificate
openssl req -x509 -nodes -days 30 -newkey rsa:4096 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -subj "/CN=lex.local/O=Meridian Lex/C=UK" \
    -addext "subjectAltName=DNS:lex.local,DNS:*.lex.local,DNS:localhost"

# Set permissions
chmod 644 "$CERT_FILE"
chmod 600 "$KEY_FILE"

# Calculate next rotation date
NEXT_ROTATION=$(date -d '+25 days' '+%Y-%m-%d')

echo "[OK] Certificate rotated successfully"
echo " Next rotation: $NEXT_ROTATION"

# Notify via ntfy
if command -v curl &> /dev/null; then
    curl -d "Certificate rotated successfully. Next rotation: $NEXT_ROTATION" \
         "$NTFY_URL" 2>/dev/null || echo " (Failed to send ntfy notification)"
fi

# Traefik will automatically reload the certificate via file watcher
echo " Traefik will hot-reload the new certificate"
```

**Step 2: Make script executable**

Run: `chmod +x scripts/rotate-certs.sh`

**Step 3: Test script syntax**

Run: `bash -n scripts/rotate-certs.sh`
Expected: No syntax errors

**Step 4: Commit**

```bash
git add scripts/rotate-certs.sh
git commit -m "feat(scripts): add certificate rotation automation"
git push origin master
```

---

## Task 17: Deployment Orchestration Script

**Files:**
- Create: `scripts/deploy-stack.sh`

**Step 1: Create deployment script**

File: `scripts/deploy-stack.sh`
```bash
#!/bin/bash
set -euo pipefail

# Deployment orchestration for lex-docker infrastructure
# Deploys service groups in correct dependency order

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "==> Deploying lex-docker infrastructure"
echo ""

# Check if secrets are initialized
if [[! -f "$PROJECT_ROOT/docker-secrets.env" ]]; then
    echo "ERROR: docker-secrets.env not found"
    echo "Run:./scripts/init-docker-secrets.sh"
    exit 1
fi

# Function to wait for service health
wait_for_health() {
    local service="$1"
    local max_wait=60
    local count=0

    echo " Waiting for $service to be healthy..."

    while! docker inspect "$service" --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; do
        sleep 2
        count=$((count + 2))

        if [[ $count -ge $max_wait ]]; then
            echo " WARNING: $service did not become healthy within ${max_wait}s"
            return 1
        fi
    done

    echo " [OK] $service is healthy"
    return 0
}

# Phase 1: Core Infrastructure
echo "==> Phase 1: Core Infrastructure"
docker-compose -f core/docker-compose.yml up -d
wait_for_health "lex-traefik" || true
wait_for_health "lex-authelia" || true
echo "[OK] Core services deployed"
echo ""

# Phase 2: Storage Layer
echo "==> Phase 2: Storage Layer"
docker-compose -f storage/docker-compose.yml up -d
wait_for_health "lex-postgres" || true
wait_for_health "lex-qdrant" || true
wait_for_health "lex-rabbitmq" || true
echo "[OK] Storage services deployed"
echo ""

# Phase 3: Communication
echo "==> Phase 3: Communication"
docker-compose -f communication/docker-compose.yml up -d
wait_for_health "lex-ntfy" || true
wait_for_health "lex-gateway" || true
echo "[OK] Communication services deployed"
echo ""

# Phase 4: Observability
echo "==> Phase 4: Observability"
docker-compose -f observability/docker-compose.yml up -d
wait_for_health "lex-prometheus" || true
wait_for_health "lex-grafana" || true
echo "[OK] Observability services deployed"
echo ""

# Phase 5: Utilities
echo "==> Phase 5: Utilities"
docker-compose -f utilities/docker-compose.yml up -d
echo "[OK] Utility services deployed"
echo ""

# Summary
echo "==> Deployment Summary"
echo ""
docker ps --filter "name=lex-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "[OK] Full stack deployment complete"
echo ""
echo "Access points:"
echo " Portainer: https://localhost:9443"
echo " Grafana: http://localhost:3000"
echo " ntfy: http://localhost:2586"
echo " API Gateway: http://localhost:8000"
echo " FileBrowser: http://localhost:8090"
```

**Step 2: Make script executable**

Run: `chmod +x scripts/deploy-stack.sh`

**Step 3: Test script syntax**

Run: `bash -n scripts/deploy-stack.sh`
Expected: No syntax errors

**Step 4: Commit**

```bash
git add scripts/deploy-stack.sh
git commit -m "feat(scripts): add full stack deployment orchestration"
git push origin master
```

---

## Task 18: Stack Teardown Script

**Files:**
- Create: `scripts/teardown-stack.sh`

**Step 1: Create teardown script**

File: `scripts/teardown-stack.sh`
```bash
#!/bin/bash
set -euo pipefail

# Teardown lex-docker infrastructure
# Stops all services in reverse dependency order

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "==> Tearing down lex-docker infrastructure"
echo ""

# Stop in reverse order
echo "Stopping utilities..."
docker-compose -f utilities/docker-compose.yml down

echo "Stopping observability..."
docker-compose -f observability/docker-compose.yml down

echo "Stopping communication..."
docker-compose -f communication/docker-compose.yml down

echo "Stopping storage..."
docker-compose -f storage/docker-compose.yml down

echo "Stopping core..."
docker-compose -f core/docker-compose.yml down

echo ""
echo "[OK] All services stopped"
echo ""

# Ask about volume cleanup
read -p "Remove volumes? (data will be lost) [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing volumes..."
    docker volume ls --filter "name=traefik_certs" --filter "name=portainer_data" \
                     --filter "name=authelia_config" --filter "name=postgres_data" \
                     --filter "name=qdrant_data" --filter "name=opensearch_data" \
                     --filter "name=memgraph_data" --filter "name=rabbitmq_data" \
                     --filter "name=prometheus_data" --filter "name=grafana_data" \
                     --filter "name=loki_data" --filter "name=ntfy_cache" \
                     --filter "name=ntfy_config" --filter "name=fb_db" \
                     -q | xargs -r docker volume rm
    echo "[OK] Volumes removed"
else
    echo "[OK] Volumes preserved"
fi

echo ""
echo "[OK] Teardown complete"
```

**Step 2: Make script executable**

Run: `chmod +x scripts/teardown-stack.sh`

**Step 3: Test script syntax**

Run: `bash -n scripts/teardown-stack.sh`
Expected: No syntax errors

**Step 4: Commit**

```bash
git add scripts/teardown-stack.sh
git commit -m "feat(scripts): add stack teardown script with volume cleanup"
git push origin master
```

---

## Task 19: Update README with Usage Instructions

**Files:**
- Modify: `README.md`

**Step 1: Write comprehensive README**

File: `README.md`
```markdown
# lex-docker

Docker infrastructure for the Meridian Lex autonomous agent system.

## Overview

Multi-service containerized stack with 15 services organized into 5 functional groups:

- **core**: Traefik, Authelia, Portainer
- **storage**: PostgreSQL+pgvector, Qdrant, OpenSearch, Memgraph, RabbitMQ
- **communication**: ntfy, API Gateway
- **observability**: Prometheus, Grafana, Loki, cAdvisor
- **utilities**: FileBrowser, Watchtower

## Architecture

- **Multi-tier network segmentation**: frontend, backend, monitoring networks
- **Automated dependency orchestration**: services start in correct order with healthchecks
- **Integrated secrets management**: syncs with `~/.config/secrets.yaml`
- **API Gateway**: bridges host-based agent to containerized services
- **Observability**: Prometheus + Grafana with critical alerting via ntfy

See [design document](docs/plans/2026-02-07-docker-infrastructure-design.md) for full architecture details.

## Prerequisites

- Docker 24.0+
- Docker Compose 2.20+
- yq 4.0+ (YAML processor)
- OpenSSL (for certificate generation)

## Quick Start

### 1. Initialize Secrets

Generate and sync credentials with Lex secrets system:

```bash
./scripts/init-docker-secrets.sh
```

This reads from `~/.config/secrets.yaml`, generates missing passwords, and creates `docker-secrets.env`.

### 2. Deploy Full Stack

```bash
./scripts/deploy-stack.sh
```

Deploys all services in dependency order. Takes ~2-3 minutes for all healthchecks to pass.

### 3. Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Portainer | https://localhost:9443 | Set on first login |
| Grafana | http://localhost:3000 | admin / (from secrets) |
| ntfy | http://localhost:2586 | No auth |
| API Gateway | http://localhost:8000 | No auth |
| FileBrowser | http://localhost:8090 | admin / admin |
| Prometheus | http://localhost:9090 | No auth |

### 4. Generate Initial Certificate

```bash
./scripts/rotate-certs.sh
```

Generates self-signed TLS certificate for Traefik. Traefik hot-reloads automatically.

## Agent Integration

The API Gateway exposes backend services to the host-based Lex agent:

```bash
# Publish status to ntfy
curl -d "Task started" http://localhost:8000/ntfy/lex-agent-status

# Query Qdrant vectors
curl http://localhost:8000/qdrant/collections/memories/points/search \
  -H "Content-Type: application/json" \
  -d '{"vector": [0.1, 0.2,...], "limit": 5}'

# Search OpenSearch logs
curl http://localhost:8000/opensearch/_search?q=error

# Connect to PostgreSQL
psql -h localhost -p 5432 -U lex -d lex_state
```

## Management

### View Stack Status

```bash
docker ps --filter "name=lex-"
```

### View Logs

```bash
# All services
docker-compose -f core/docker-compose.yml logs -f
docker-compose -f storage/docker-compose.yml logs -f

# Specific service
docker logs -f lex-postgres
```

### Restart Service

```bash
docker-compose -f storage/docker-compose.yml restart postgres
```

### Stop Stack

```bash
./scripts/teardown-stack.sh
```

Prompts before removing volumes (data preservation).

## Certificate Rotation

Self-signed certificates rotate every 25 days automatically via cron:

```bash
# Add to crontab
crontab -e

# Add line:
0 2 */25 * * /path/to/lex-docker/scripts/rotate-certs.sh
```

Traefik hot-reloads certificates without downtime.

## Monitoring

- **Grafana dashboards**: http://localhost:3000
- **Prometheus metrics**: http://localhost:9090
- **Container stats**: http://localhost:9443 (Portainer)
- **ntfy alerts**: http://localhost:2586/lex-system-alerts

Critical alerts (container down, high resource usage, healthcheck failures) sent to ntfy automatically.

## Backup Strategy

VM-level snapshots handle all data persistence. Docker volumes are included in VM backup:

- `postgres_data` - Agent state database
- `qdrant_data` - Vector memory
- `grafana_data` - Dashboards and settings
- `prometheus_data` - 30 days metrics retention

No service-level backups required.

## Update Policy

**Auto-update** (Watchtower, daily 3 AM):
- Watchtower, cAdvisor, Traefik, FileBrowser

**Manual update** (pinned versions):
- PostgreSQL, Qdrant, OpenSearch, Memgraph, RabbitMQ
- Prometheus, Grafana, Loki, Authelia

Review changelogs before updating stateful services.

## Troubleshooting

### Service won't start

```bash
# Check logs
docker logs lex-<service-name>

# Check healthcheck
docker inspect lex-<service-name> --format='{{.State.Health.Status}}'

# Restart with fresh state
docker-compose -f <group>/docker-compose.yml down
docker-compose -f <group>/docker-compose.yml up -d
```

### Port conflicts

```bash
# Check what's using a port
sudo ss -tulpn | grep <port>

# Change port in compose file, redeploy
```

### Secrets issues

```bash
# Regenerate secrets
./scripts/init-docker-secrets.sh

# Verify secrets file
cat docker-secrets.env

# Restart services to pick up new secrets
docker-compose -f storage/docker-compose.yml restart postgres
```

### Gateway routing issues

```bash
# Check gateway logs
docker logs lex-gateway

# Test backend connectivity from gateway
docker exec lex-gateway wget -O- http://lex-qdrant:6333/

# Rebuild gateway
docker-compose -f communication/docker-compose.yml up -d --build gateway
```

## Development

### Add New Service

1. Add service to appropriate group's `docker-compose.yml`
2. Configure networks (frontend/backend/monitoring)
3. Add volumes if needed
4. Define healthcheck
5. Update `deploy-stack.sh` if dependencies change
6. Test deployment: `docker-compose -f <group>/docker-compose.yml up -d`

### Modify Network Topology

Networks are defined in `core/docker-compose.yml` and referenced as external in other compose files. Changes require coordinated updates across all groups.

## Future Enhancements

Tracked in [design document](docs/plans/2026-02-07-docker-infrastructure-design.md#future-enhancements):

- Internal ACME CA (step-ca) for certificate lifecycle
- Enhanced observability for agent internal state
- API Gateway request validation and rate limiting
- Refined ntfy topic structure

## License

Part of the Meridian Lex autonomous agent system infrastructure.
```

**Step 2: Commit README**

```bash
git add README.md
git commit -m "docs: comprehensive README with usage instructions"
git push origin master
```

---

## Task 20: Final Validation and Documentation

**Files:**
- Create: `DEPLOY.md`

**Step 1: Create deployment guide**

File: `DEPLOY.md`
```markdown
# Deployment Guide

Step-by-step deployment instructions for lex-docker infrastructure.

## Initial Setup

### 1. Prerequisites Check

```bash
# Verify Docker
docker --version # Need 24.0+
docker-compose --version # Need 2.20+

# Verify yq
yq --version # Need 4.0+

# If yq not installed:
sudo wget -qO /usr/local/bin/yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### 2. Clone Repository

```bash
cd ~/meridian-home/projects
git clone git@github.com:Meridian-Lex/lex-docker.git
cd lex-docker
```

### 3. Initialize Secrets

```bash
./scripts/init-docker-secrets.sh
```

**Expected output:**
```
==> Initializing Docker secrets for lex-docker
==> Secrets synchronized with /home/meridian/.config/secrets.yaml
==> Docker secrets exported to docker-secrets.env
==> File permissions set to 600
[OK] Secrets initialization complete
```

**Verify:**
```bash
ls -la docker-secrets.env # Should show 600 permissions
grep "POSTGRES_PASSWORD" docker-secrets.env # Should show generated password
```

### 4. Generate Initial Certificate

```bash
./scripts/rotate-certs.sh
```

**Note:** This will fail initially because Traefik volume doesn't exist yet. This is expected. The deployment script will create the volume, then you can run this afterward.

### 5. Deploy Stack

```bash
./scripts/deploy-stack.sh
```

**Expected duration:** 2-3 minutes

**Watch deployment progress:**
```bash
# In another terminal
watch docker ps --filter "name=lex-"
```

### 6. Generate Certificate (Post-Deployment)

```bash
./scripts/rotate-certs.sh
```

Now that the Traefik volume exists, this should succeed.

### 7. Set Up Certificate Rotation Cron

```bash
crontab -e

# Add line:
0 2 */25 * * /home/meridian/meridian-home/projects/lex-docker/scripts/rotate-certs.sh
```

## Verification

### Check All Services Running

```bash
docker ps --filter "name=lex-" --format "table {{.Names}}\t{{.Status}}"
```

**Expected:** All containers showing "Up" with "(healthy)" status.

### Test Service Endpoints

```bash
# Portainer
curl -k https://localhost:9443/api/status

# Grafana
curl http://localhost:3000/api/health

# ntfy
curl http://localhost:2586/v1/health

# API Gateway
curl http://localhost:8000/health

# Prometheus
curl http://localhost:9090/-/healthy

# Qdrant
curl http://localhost:6333/

# PostgreSQL
pg_isready -h localhost -p 5432 -U postgres
```

### Test Agent Integration

```bash
# Publish to ntfy via gateway
curl -d "Test from agent" http://localhost:8000/ntfy/lex-agent-status

# Check ntfy received it
curl http://localhost:2586/lex-agent-status/json?poll=1
```

## Configuration

### Authelia Users

1. Generate password hash:
```bash
docker exec lex-authelia authelia crypto hash generate pbkdf2 --password 'yourpassword'
```

2. Edit `core/authelia/users_database.yml`:
```yaml
users:
  admin:
    displayname: "Admin User"
    password: "$pbkdf2-sha512$..." # From step 1
    email: admin@lex.local
    groups:
      - admins
```

3. Restart Authelia:
```bash
docker-compose -f core/docker-compose.yml restart authelia
```

### Grafana Data Sources

Access Grafana at http://localhost:3000 (admin / password from secrets)

**Add Prometheus:**
- Configuration → Data Sources → Add data source
- Select Prometheus
- URL: `http://lex-prometheus:9090`
- Save & Test

**Add Loki:**
- Configuration → Data Sources → Add data source
- Select Loki
- URL: `http://lex-loki:3100`
- Save & Test

### FileBrowser Initial Login

1. Access http://localhost:8090
2. Login: `admin` / `admin`
3. **Change password immediately** via Settings → User Management

## Monitoring Setup

### Subscribe to ntfy Topics

**On mobile device or desktop:**

```bash
# System alerts
curl http://<vm-ip>:2586/lex-system-alerts/json?poll=1

# Agent status
curl http://<vm-ip>:2586/lex-agent-status/json?poll=1
```

**Or use ntfy web interface:**
- Open http://<vm-ip>:2586
- Subscribe to `lex-system-alerts` and `lex-agent-status`

### Import Grafana Dashboards

Recommended dashboards:
- Dashboard 179 (Docker containers)
- Dashboard 1860 (Node Exporter Full)
- Dashboard 11159 (Prometheus 2.0 Stats)

Import via Grafana UI: Dashboards → Import → Enter dashboard ID

## Maintenance

### View Logs

```bash
# All services in a group
docker-compose -f storage/docker-compose.yml logs -f

# Specific service
docker logs -f lex-postgres

# Last 100 lines
docker logs --tail 100 lex-traefik
```

### Restart Service

```bash
# Single service
docker-compose -f storage/docker-compose.yml restart postgres

# All services in group
docker-compose -f core/docker-compose.yml restart

# Full stack restart
./scripts/teardown-stack.sh
./scripts/deploy-stack.sh
```

### Update Pinned Service

```bash
# Edit version tag in compose file
vim storage/docker-compose.yml

# Redeploy with new image
docker-compose -f storage/docker-compose.yml pull postgres
docker-compose -f storage/docker-compose.yml up -d postgres

# Verify
docker logs lex-postgres
```

## Troubleshooting

### Service Stuck in Unhealthy State

```bash
# Check healthcheck output
docker inspect lex-<service> --format='{{json.State.Health}}' | jq

# Check logs
docker logs lex-<service>

# Restart service
docker-compose -f <group>/docker-compose.yml restart <service>
```

### Secrets Not Loading

```bash
# Verify secrets file exists
ls -la docker-secrets.env

# Check compose file references it
grep "env_file" storage/docker-compose.yml

# Reinitialize secrets
./scripts/init-docker-secrets.sh

# Restart affected services
docker-compose -f storage/docker-compose.yml restart
```

### Network Connectivity Issues

```bash
# List networks
docker network ls | grep lex-

# Inspect network
docker network inspect lex-backend

# Check container network membership
docker inspect lex-postgres --format='{{json.NetworkSettings.Networks}}' | jq

# Recreate networks
docker-compose -f core/docker-compose.yml down
docker-compose -f core/docker-compose.yml up -d
```

### Port Already in Use

```bash
# Find what's using the port
sudo ss -tulpn | grep:<port>

# Change port in compose file
vim <group>/docker-compose.yml

# Update port mapping: "NEW_PORT:CONTAINER_PORT"

# Redeploy
docker-compose -f <group>/docker-compose.yml up -d
```

## Rollback

### Restore from VM Snapshot

Since backup strategy is VM-level snapshots:

1. Stop all containers: `./scripts/teardown-stack.sh`
2. Restore VM from snapshot
3. Restart containers: `./scripts/deploy-stack.sh`

### Rollback Single Service

```bash
# Find previous image version
docker images | grep <service>

# Update compose file with old version tag
vim <group>/docker-compose.yml

# Redeploy
docker-compose -f <group>/docker-compose.yml up -d <service>
```

## Support

- **Design document**: `docs/plans/2026-02-07-docker-infrastructure-design.md`
- **Implementation plan**: `docs/plans/2026-02-07-docker-infrastructure-implementation.md`
- **Repository**: https://github.com/Meridian-Lex/lex-docker
```

**Step 2: Commit deployment guide**

```bash
git add DEPLOY.md
git commit -m "docs: add comprehensive deployment guide"
git push origin master
```

---

## Execution Complete

Plan complete and saved to `docs/plans/2026-02-07-docker-infrastructure-implementation.md`.

**Summary:**
- 20 tasks covering full infrastructure implementation
- All docker-compose files for 5 service groups
- Secrets management integration with Lex system
- Automation scripts (deploy, teardown, certificate rotation)
- Comprehensive documentation (README, deployment guide)
- Each task follows: create → test → commit → push workflow

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
