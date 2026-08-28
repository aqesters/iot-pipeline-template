# IIoT Data Pipeline Template

Dockerized Node-RED -> InfluxDB -> Grafana stack for pulling machine/process
data off the plant floor and into dashboards clients can actually use.

This is a **template repo** — clone it per client (`git clone` into a new
private repo, or use it as a GitHub template), customize the input node and
the business logic in `node-red/data/flows.json`, and ship it. See
`docs/ARCHITECTURE.md` for how the pipeline is structured and
`docs/ARCHITECTURE.md#going-from-simulator-to-a-real-input` for wiring up a
client's actual equipment.

## Stack

| Component | Role |
|---|---|
| [Node-RED](https://nodered.org/) | Ingestion, routing, and transformation |
| [InfluxDB 2.x](https://www.influxdata.com/) | Time-series storage |
| [Grafana](https://grafana.com/) | Dashboards |
| Docker Compose | Reproducible deployment |

Runs out of the box with a built-in data simulator (three fake machines) so
you can see the whole pipeline working before connecting real hardware.

## Quick start

Requires Docker and Docker Compose.

```bash
cp .env.example .env
```

Generate real secrets instead of the placeholders (prints values to paste into `.env`):

```bash
make secrets
```

At minimum, set in `.env`:
- `INFLUXDB_INIT_ADMIN_TOKEN` and `INFLUXDB_TOKEN` — **use the same value for both.** The former is what InfluxDB creates itself with on first boot; the latter is what Node-RED/Grafana authenticate with.
- `INFLUXDB_INIT_PASSWORD`, `GRAFANA_ADMIN_PASSWORD` — real passwords.
- `NODE_RED_CREDENTIAL_SECRET` — random string, used to encrypt any credentials Node-RED stores.
- `INFLUXDB_INIT_ORG` / `INFLUXDB_ORG` and `INFLUXDB_INIT_BUCKET` / `INFLUXDB_BUCKET` — keep each pair identical; rename to match the client.

Then bring up the stack:

```bash
make up
# or: docker compose up -d --build
```

Open:
- Node-RED editor: http://localhost:1880
- Grafana: http://localhost:3000 (login with `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`)
- InfluxDB UI: http://localhost:8086 (only if you keep the port binding in `docker-compose.yml`)

The **Plant Floor Overview** dashboard in Grafana should show data moving
within ~10 seconds — the simulator injects a reading every 3 seconds for one
of three fake machines (`press-01`, `press-02`, `cnc-04`).

## Repo layout

```
.
├── docker-compose.yml              # Core 3-service stack
├── docker-compose.portainer.yml    # Optional: add a Docker GUI (see file header)
├── .env.example                    # Copy to .env, fill in secrets
├── Makefile                        # up / down / logs / backup / secrets
├── node-red/
│   ├── Dockerfile                  # Bakes in node-red-contrib-influxdb at build time
│   └── data/
│       ├── flows.json              # The pipeline itself — see docs/ARCHITECTURE.md
│       ├── settings.js             # Env-driven runtime config (no secrets hardcoded)
│       └── package.json            # Palette manifest
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/influxdb.yml    # Auto-configures the InfluxDB datasource
│   │   └── dashboards/dashboard.yml    # Auto-loads dashboards from grafana/dashboards/
│   └── dashboards/
│       └── plant-floor-overview.json   # Starter dashboard
└── docs/
    └── ARCHITECTURE.md             # Pipeline design + how to connect real equipment
```

## Common tasks

```bash
make logs      # tail all container logs
make ps        # container status
make config    # validate docker-compose.yml + .env interpolation
make backup    # dump InfluxDB data + Node-RED flows to ./backups/<timestamp>/
make down      # stop the stack (keeps data)
make clean     # stop the stack AND delete all volumes (destructive)
```

## Version control per client

Per the standard workflow: **one private repo per client.**

```bash
# Starting a new client from this template
git clone <this-repo-url> client-acme-pipeline
cd client-acme-pipeline
rm -rf .git && git init
git remote add origin <new-private-repo-url>
cp .env.example .env   # fill in this client's real secrets — .env is gitignored
git add .
git commit -m "Initial pipeline for Acme Manufacturing"
git push -u origin main
```

Keep `.env` and `node-red/data/flows_cred.json` out of every commit (already
covered by `.gitignore`) — they hold the InfluxDB token, Grafana admin
password, and any credentials Node-RED encrypts.

## Going live at a client site

1. Replace the simulator with a real input node for their equipment (MQTT / Modbus / OPC-UA / S7 / REST) — see `docs/ARCHITECTURE.md`.
2. Tune calibration constants, thresholds, and health-score weighting in the `Math`, `Stateful Ops`, and `Synthetic` function nodes for their actual machines.
3. Set `NODE_RED_ENABLE_AUTH=true` and configure `adminAuth` in `node-red/data/settings.js` if the Node-RED editor is reachable outside a VPN/Tailscale network.
4. Turn off the public InfluxDB port binding in `docker-compose.yml` (leave InfluxDB reachable only on the internal Docker network) once you don't need it for debugging.
5. Decide on hosting (client-hosted vs. your managed VM vs. hybrid) and remote access (Tailscale vs. WireGuard) per the standard tool-stack decision tree.
6. Point Uptime Kuma (run centrally, across all clients) at this stack's exposed endpoints.
7. Set a real retention policy (`INFLUXDB_INIT_RETENTION`) matching what the client needs and what your storage budget allows.

## Notes

- **Why Flux, not InfluxQL**: the Grafana datasource is provisioned in Flux mode to match InfluxDB 2.x's native query language and to use `schema.tagValues()` for the machine-picker dashboard variable. If you're more comfortable in InfluxQL, InfluxDB 2.x still accepts it via the `/query` compatibility endpoint, but the provisioned datasource here is Flux-first.
- **Environment variable substitution**: both Node-RED (`${VAR}` in `flows.json`) and Grafana (`$__env{VAR}` in provisioning YAML) resolve these directly from the container's environment at startup — nothing needs templating at build time. Update `.env` and restart the affected container to change them.
