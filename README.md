# BOOM Sandbox NRP Nautilus deployment

This repository contains the Kubernetes deployment manifests and technical documentation for running [boom-filter-sandbox](https://github.com/boom-astro/boom-filter-sandbox) (the filter sandbox variant of BOOM) on the [NRP](https://nrp.ai/) cluster.

> ⚠️ **This deployment intentionally exposes the filter endpoints publicly (unauthenticated).**
> That is acceptable here only because the instance is isolated and serves public data exclusively.
> See the [Boom sandbox README](https://github.com/boom-astro/boom-filter-sandbox#readme).

## Deployment Overview

The stack runs in the `umn-babamul` namespace on NRP Nautilus.

- **API endpoint:** `https://boom-api.nrp-nautilus.io`
- **Container image:** `ghcr.io/boom-astro/boom-filter-sandbox:latest` (built from [boom-astro/boom-filter-sandbox](https://github.com/boom-astro/boom-filter-sandbox))
- **Current data status:** April 8 and 9, 2026 ZTF public alerts are fully ingested and available.

## Manifest Layout

Manifests are split into three groups so you only deploy what you need:

| Folder / File                 | Contents                                                       | When to deploy                                                           |
|-------------------------------|----------------------------------------------------------------|--------------------------------------------------------------------------|
| `k8s/secrets.example.yaml`    | Template for the Boom Secrets                                  | One-time setup (or when rotating credentials) via `make deploy-secrets`. |
| `k8s/core/`                   | MongoDB, boom-api, `boom-api-config` (minimal API-only config) | Required — Minimal stack for the Boom filter sandbox to work.            |
| `k8s/ingestion/`              | Valkey, Kafka, consumer, scheduler, ZTF ingest job, kafka ACLs, `boom-config` (full config) | Only if you want to ingest new alert data.                               |
| `k8s/observability/`          | OTel Collector, Prometheus, Grafana, exporters                 | Only if you want metrics, traces and dashboards.                         |

> **Why two ConfigMaps for BOOM?** `boom-api` only reads a subset of the BOOM config (`api`, `database`, a `kafka.producer` stub, `babamul.enabled`). The consumer and scheduler need the full thing (`redis`, `workers`, `crossmatch`, full `kafka.consumer`). Splitting keeps `core/` lean: deploying just `core/` doesn't carry along ingestion-only knobs.

## Getting Started

1. **Namespace:** Make sure you target `umn-babamul` (the Makefile does this automatically).

2. **Secrets (one-time):** Copy the template, fill with real credentials, then apply explicitly.
   ```bash
   cp k8s/secrets.example.yaml k8s/secrets.yaml
   # edit k8s/secrets.yaml
   make deploy-secrets
   ```
   Run this when create or rotate credentials. Other deploy targets do not apply secrets automatically.

3. **Deploy the minimum (mongo + api):**
   ```bash
   make deploy-core
   ```

4. **Optional — add the ingestion stack** (Kafka, Valkey, consumer, scheduler):
   ```bash
   make deploy-ingestion
   ```

5. **Optional — add the observability stack** (OTel, Prometheus, Grafana, exporters):
   ```bash
   make deploy-observability
   ```

6. **Everything at once**:
   ```bash
   make deploy-all
   ```

7. **Validation:** `make status` (or `kubectl get pods -n umn-babamul`).

### Tear-down

```bash
make delete-core            # remove boom-api + mongodb (data will be lost)
make delete-ingestion       # remove kafka + valkey + consumer + scheduler
make delete-observability   # remove otel + prometheus + grafana + exporters
```

### Doing it without `make`

Each target is just a thin wrapper around `kubectl apply -f`. The equivalent commands are:

```bash
# secrets (one-time, separate from app deploys)
kubectl apply -n umn-babamul -f k8s/secrets.yaml

# core
kubectl apply -n umn-babamul -f k8s/core/boom-api-config.yaml
kubectl apply -n umn-babamul -f k8s/core/mongodb.yaml
kubectl apply -n umn-babamul -f k8s/core/boom-api.yaml

# ingestion (includes the full boom-config ConfigMap used by consumer + scheduler)
kubectl apply -n umn-babamul -f k8s/ingestion/

# observability
kubectl apply -n umn-babamul -f k8s/observability/
```

_Note: `kubectl apply -f <dir>` does not recurse and skips only files not ending in `.yaml`/`.json`. `*.example.yaml` can be picked up. You should not `apply` a directory that contains a `.example.yaml` file._

## Key Documentation

- [Deployment Notes & Troubleshooting](DEPLOYMENT_NOTES.md): Critical information on solving storage latency and Kafka race conditions on NRP.
- [Data Ingestion Guide](INGESTION.md): How to load additional nights of ZTF or DECam data.

## Upstream projects

- [boom-astro/boom-filter-sandbox](https://github.com/boom-astro/boom-filter-sandbox): the Boom sandbox variant deployed by this repo.
- [boom-astro/boom](https://github.com/boom-astro/boom): the main BOOM project (full documentation).
