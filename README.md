# Traefik gateway

This Compose project runs Traefik only. It creates a Docker network named
`proxy` for application Compose projects to join.

The intended request flow is:

```text
Office client -> Traefik :18080 -> Docker service
```

Traefik listens directly on the approved public port `18080`. No Nginx
configuration is required for this gateway.

## Start

```bash
make start      # or: docker compose up -d
make ps
make logs
```

The first `make up` (same as `make start`) asks for the public port (Enter
keeps `18080`, the port IT approved) and writes a local `.env` with
`TRAEFIK_HTTP_PORT`, `XDG_RUNTIME_DIR`, and `DOCKER_SOCKET`. `.env` is
gitignored. `.env.example` shows the same keys. To set them by hand, copy it:
`cp .env.example .env`, then edit the uid in the paths. Run `make setup` to
change the values later; it overwrites `.env`.

`make stop` stops the container without removing the `proxy` network, so other
projects stay attached. Run `make help` for all targets.

The Compose file creates the external-to-other-projects network `proxy`.

## Join this gateway from another Compose project

```yaml
services:
  app:
    image: your-image:latest
    networks:
      - proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.app.rule=PathPrefix(`/services`)
      - traefik.http.routers.app.entrypoints=web
      - traefik.http.routers.app.middlewares=app-strip
      - traefik.http.middlewares.app-strip.stripprefix.prefixes=/services
      - traefik.http.services.app.loadbalancer.server.port=8080

networks:
  proxy:
    external: true
    name: proxy
```

The `StripPrefix` middleware is appropriate when the application serves from
`/`. Remove that middleware if the application itself expects the `/services`
prefix.
