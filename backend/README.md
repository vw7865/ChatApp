# Companion Device Status Monitor Backend

Production-ready baseline backend (TypeScript + Fastify + PostgreSQL + Redis) for a multi-user companion device status monitor.

## Stack

- Node.js 20 + Fastify
- PostgreSQL (users + instances + events)
- Redis (global API rate limiting)
- Docker Compose (`app`, `postgres`, `redis`)

## Quick start

1. Copy env file:

```bash
cp .env.example .env
```

2. Set secure values in `.env`:
- `DEFAULT_API_KEY`
- `POSTGRES_PASSWORD`
- optional APNs values (`APNS_*`)

3. Start services:

```bash
docker compose up -d --build
```

4. API will be on:
- `http://localhost:8080`

## Auth

All protected endpoints require:

```http
x-api-key: <your key>
```

The bootstrap API key is `DEFAULT_API_KEY` from `.env`.

## Endpoints

- `GET /health` (public)
- `GET /instances`
- `POST /instances/create`
- `GET /instances/:id/qr`
- `GET /instances/:id/status`
- `PUT /instances/:id/webhook`
- `DELETE /instances/:id`
- `POST /instances/:id/link` (simulates successful link)
- `POST /instances/:id/status` (simulates live status event)
- `POST /me/device-token` (store APNs token for notifications)

## Example flow

### 1) Create instance

```bash
curl -X POST http://localhost:8080/instances/create \
  -H "content-type: application/json" \
  -H "x-api-key: change-me-super-secret" \
  -d '{"name":"Kid iPhone","webhookUrl":"https://example.com/webhook"}'
```

Response includes:
- `instance`
- `qrCode` (data URL image string)

### 2) Mark instance linked

```bash
curl -X POST http://localhost:8080/instances/<INSTANCE_ID>/link \
  -H "content-type: application/json" \
  -H "x-api-key: change-me-super-secret" \
  -d '{"deviceId":"device_abc"}'
```

### 3) Send a simulated real-time status event

```bash
curl -X POST http://localhost:8080/instances/<INSTANCE_ID>/status \
  -H "content-type: application/json" \
  -H "x-api-key: change-me-super-secret" \
  -d '{"deviceId":"device_abc","status":"online"}'
```

If `webhookUrl` exists, the backend forwards this exact shape:

```json
{
  "event": "status.update",
  "instanceId": "xxx",
  "data": {
    "deviceId": "string",
    "status": "online",
    "timestamp": "2026-03-30T12:00:00.000Z"
  }
}
```

(`status` can be `"online" | "offline" | "away"`.)

## Session persistence

- Session metadata is stored in PostgreSQL (`instances` table).
- Per-instance session files are persisted under `data/sessions`.
- `./data` is mounted into the app container, so sessions survive container restarts.

## APNs helper

`src/services/apnsService.ts` sends either:
- silent pushes (`content-available`)
- regular alert pushes

Set `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_KEY_PATH`, and `APNS_PRODUCTION` to enable.

## Security controls included

- API key auth (SHA-256 hash lookup in DB)
- Request validation with Zod
- Redis-backed global rate limiting
- No hard-coded secrets (all from `.env`)
