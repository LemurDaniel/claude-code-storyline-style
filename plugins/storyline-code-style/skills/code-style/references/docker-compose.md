# Code Style: Docker Compose
- 2 spaces. One folder per service with exactly one `docker-compose.yaml` (extension `.yaml`, not `.yml`). The folder name is the project name.
  ```
  compose/
    tmpl.docker-compose.yaml
    filebrowser/
      docker-compose.yaml
      .env
    grafana/
      docker-compose.yaml
  ```
- No `version:` key anymore, the file starts directly with `services:` (or `networks:` when networks are defined).
- Several services in one file are separated by a `# ----` banner per `SKILL.md` → "Comments". A large file groups its services into chapters (e.g. metrics, dashboards, proxy):
  ```yaml
  services:

    # ---------------------------------------------------------------------------
    # Prometheus Service
    #   Scrapes the exporters and stores the metrics.
    # ---------------------------------------------------------------------------
    prometheus:
      ...
  ```
- **Fixed order per service**, blocks separated by empty lines:
  1. Identity: `container_name` (same as the service key), `restart: unless-stopped`, `image` or `build` + `pull_policy: build`
  2. Network: `expose`, `ports`, `networks`, `network_mode`, `extra_hosts`
  3. Privileges: `user`, `privileged`, `pid`, `devices`, `group_add`
  4. `command`
  5. `environment`
  6. `volumes`
  7. Startup: `depends_on`, `healthcheck`
  8. Operations: `labels`, `logging`, `deploy`
  ```yaml
  api:
    container_name: api
    restart: unless-stopped
    build:
      context: .
      dockerfile: Dockerfile
    image: api:latest
    pull_policy: build

    expose:
      - 8080

    user: "1000:1000"   # matches the owner of ./data on the host

    environment:
      ...

    volumes:
      - ./config:/app/config:ro
      - ./data:/app/data
  ```
- **`expose` instead of `ports`** when the service sits behind the reverse proxy. The proxy joins the `<service>_default` networks as `external: true`. `ports` only for things that must be reachable directly from the LAN, with a comment on what for.
  ```yaml
  # reverse-proxy-nginx/docker-compose.yaml
  networks:
    filebrowser_default:
      external: true
    grafana_default:
      external: true

  services:
    nginx:
      ...
      ports:
        - "443:443"   # only entry point from the LAN
      networks:
        - filebrowser_default
        - grafana_default
  ```
- **`environment` as a map**, not as a `- KEY=value` list. Related variables stand as a group with a comment above:
  ```yaml
  environment:
    TZ: Europe/Berlin

    # Base URL when routed via the reverse proxy
    FB_BASEURL: /filebrowser
  ```
- **Never secrets in plain text:** They come from the `.env` next to the file and are never written into the compose file. Required values use `${VAR:?message}` so startup aborts with a clear message, and a comment next to a generated value says how to generate it (e.g. `openssl rand -hex 32`):
  ```yaml
  # Value from .env, startup aborts with the message when it is missing
  ADMIN_USER: ${ADMIN_USER:?Set ADMIN_USER in .env}
  ```
- Quote bools and values containing `:` as strings (`"true"`, `"0:0"`, `"9090:9090"`).
  ```yaml
  GF_AUTH_ANONYMOUS_ENABLED: "false"
  ports:
    - "9090:9090"
  ```
- **Volumes:** config from the repo relative (`./nginx/nginx.conf`), payload data absolute on the host storage (`/srv/...`, `/mnt/...`). What the container only reads gets `:ro`. One comment per mount or group on what lives there. Data folders of the containers (`./data`, `./config`) are in `.gitignore`.
  ```yaml
  volumes:
    # Config from the repo
    - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro

    # Media library on the host, read only for the player
    - /srv/media/movies:/media/movies:ro

    # Transcoding cache on fast storage
    - /mnt/fast/jellyfin/cache:/cache
  ```
- **Justify elevated privileges:** `privileged`, `pid: host`, `network_mode: host` and `user: "0:0"` always get a comment with the why.
  ```yaml
  network_mode: host   # DLNA discovery needs multicast on the host network
  user: "0:0"          # the backup tool must read files of every container
  ```
- **Document host prerequisites at the block:** Firewall rules, kernel settings, `daemon.json` entries or files that must exist before the first start stand as a commented-out command right where they are needed:
  ```yaml
  # Host: Elasticsearch needs a higher mmap count than the default
  # sudo sysctl -w vm.max_map_count=262144
  ```
- **Leave optional features commented out** instead of deleting them (e.g. HTTPS port, GPU devices, proxy auth), with an `(Optional)` note above.
  ```yaml
  # (Optional) Hardware transcoding with the Intel iGPU
  # devices:
  #   - /dev/dri:/dev/dri
  ```
- Pin image versions that must stay stable (`nginx:1.27.0`) or pass them as a build arg (`GRAFANA_TAG: 11.1.0`). `:latest` only for non-critical tools.
  ```yaml
  nginx:
    image: nginx:1.27.0

  grafana:
    build:
      context: .
      args:
        GRAFANA_TAG: 11.1.0
  ```
- Own image: `build` with `context` and `dockerfile`, plus `image: <name>:latest` and `pull_policy: build`, so `compose up` never tries to pull it.
- Dependencies via `depends_on`, with `condition: service_healthy` when the service has a `healthcheck`. Reach other containers by service name, never by IP.
  ```yaml
  prometheus:
    ...
    healthcheck:
      test: ["CMD", "promtool", "check", "healthy"]
      interval: 30s

  grafana:
    ...
    environment:
      PROMETHEUS_URL: http://prometheus:9090   # not: http://172.18.0.3:9090

    depends_on:
      prometheus:
        condition: service_healthy   # waits for the healthcheck, not just the container start
  ```
- **Verify** per `SKILL.md` → "Errors, logging, tests": `docker compose config -q` renders the file, with every required variable set in `.env` or as a placeholder.
  ```
  docker compose --env-file .env.example config -q
  ```
