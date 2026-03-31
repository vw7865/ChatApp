import { config as loadEnv } from "dotenv";
import path from "node:path";
import { z } from "zod";

loadEnv();

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  /** Railway and many hosts set this; falls back to 8080 for local Docker. */
  PORT: z.coerce.number().int().positive().default(8080),
  LOG_LEVEL: z.string().default("info"),
  DATA_DIR: z.string().default(path.resolve(process.cwd(), "data/sessions")),
  DEFAULT_USER_EMAIL: z.string().email().default("owner@example.com"),
  DEFAULT_API_KEY: z.string().min(12),
  /** Preferred on Railway (Postgres plugin). When set, POSTGRES_* are ignored for the pool. */
  DATABASE_URL: z
    .preprocess((v) => (typeof v === "string" && v.trim() === "" ? undefined : v), z.string().url().optional()),
  /** Maps to `pg` Pool `ssl.rejectUnauthorized`. Default `false` matches typical managed Postgres (Railway/Heroku). Set `true` when your CA chain is fully trusted. */
  PG_SSL_REJECT_UNAUTHORIZED: z
    .enum(["true", "false"])
    .default("false")
    .transform((v) => v === "true"),
  POSTGRES_HOST: z.string().default("localhost"),
  POSTGRES_PORT: z.coerce.number().int().positive().default(5432),
  POSTGRES_DB: z.string().default("companion_monitor"),
  POSTGRES_USER: z.string().default("companion_user"),
  POSTGRES_PASSWORD: z.string().default("companion_password"),
  REDIS_HOST: z.string().default("localhost"),
  REDIS_PORT: z.coerce.number().int().positive().default(6379),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(120),
  RATE_LIMIT_WINDOW: z.string().default("1 minute"),
  APNS_KEY_ID: z.string().optional(),
  APNS_TEAM_ID: z.string().optional(),
  APNS_BUNDLE_ID: z.string().optional(),
  APNS_KEY_PATH: z.string().optional(),
  APNS_PRODUCTION: z.coerce.boolean().default(false),
});

export const env = envSchema.parse(process.env);

export const pgConnectionString = `postgres://${encodeURIComponent(env.POSTGRES_USER)}:${encodeURIComponent(
  env.POSTGRES_PASSWORD,
)}@${env.POSTGRES_HOST}:${env.POSTGRES_PORT}/${env.POSTGRES_DB}`;

export function resolvePgConnectionString(): string {
  if (env.DATABASE_URL) {
    return env.DATABASE_URL;
  }
  return pgConnectionString;
}

export const redisConnectionString = `redis://${env.REDIS_HOST}:${env.REDIS_PORT}`;
