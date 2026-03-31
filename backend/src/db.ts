import { mkdir } from "node:fs/promises";
import { Pool } from "pg";
import { env, resolvePgConnectionString } from "./config.js";
import { hashApiKey } from "./utils/crypto.js";

const connectionString = resolvePgConnectionString();

function poolSsl(): false | { rejectUnauthorized: boolean } {
  if (env.DATABASE_URL) {
    return { rejectUnauthorized: env.PG_SSL_REJECT_UNAUTHORIZED };
  }
  return false;
}

export const db = new Pool({
  connectionString,
  max: env.NODE_ENV === "production" ? 10 : 20,
  ssl: poolSsl(),
  connectionTimeoutMillis: 10000,
});

export async function runMigrations(): Promise<void> {
  await mkdir(env.DATA_DIR, { recursive: true });

  console.log("Running database migrations...");

  await db.query(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      api_key_hash TEXT UNIQUE NOT NULL,
      apns_device_token TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS instances (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      name TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('pending', 'linked', 'disconnected')),
      webhook_url TEXT,
      session_path TEXT NOT NULL,
      qr_token TEXT NOT NULL,
      linked_device_id TEXT,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await db.query(`
    CREATE TABLE IF NOT EXISTS status_events (
      id BIGSERIAL PRIMARY KEY,
      instance_id TEXT NOT NULL REFERENCES instances(id) ON DELETE CASCADE,
      device_id TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('online', 'offline', 'away')),
      event_ts TIMESTAMPTZ NOT NULL,
      payload JSONB NOT NULL DEFAULT '{}'::jsonb,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  `);

  await db.query(`
    CREATE INDEX IF NOT EXISTS idx_instances_user_id ON instances(user_id);
    CREATE INDEX IF NOT EXISTS idx_status_events_instance_id ON status_events(instance_id);
  `);

  console.log("✅ Database migrations completed successfully");
}

export async function ensureBootstrapUser(): Promise<void> {
  const apiHash = hashApiKey(env.DEFAULT_API_KEY);
  await db.query(
    `
      INSERT INTO users (id, email, api_key_hash)
      VALUES ($1, $2, $3)
      ON CONFLICT (email)
      DO UPDATE SET api_key_hash = EXCLUDED.api_key_hash
    `,
    ["user_default_owner", env.DEFAULT_USER_EMAIL || "admin@example.com", apiHash],
  );
  console.log("✅ Bootstrap user ensured");
}