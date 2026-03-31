import Fastify from "fastify";
import { env } from "./config.js";
import { db, ensureBootstrapUser, runMigrations } from "./db.js";
import { authPlugin } from "./plugins/auth.js";
import rateLimitPlugin from "./plugins/rateLimit.js";
import { healthRoutes } from "./routes/health.js";
import { instanceRoutes } from "./routes/instances.js";

// Import the setter for Baileys
import { setSendWebhook } from "./sessionManager.js";

const app = Fastify({
  logger: {
    level: env.LOG_LEVEL || "info",
  },
});

async function build(): Promise<void> {
  await runMigrations();
  await ensureBootstrapUser();

  // Register plugins
  await app.register(rateLimitPlugin);
  await app.register(authPlugin);

  // Register routes
  await app.register(healthRoutes);
  await app.register(instanceRoutes);

  // === CRITICAL: Register webhook sender for Baileys ===
  // This must happen BEFORE any QR code is generated
  setSendWebhook(async (instanceId: string, payload: any) => {
    console.log(`[WEBHOOK] Received "${payload.event}" for instance ${instanceId}`);
    // TODO: Send APNs push notification here in the future
  });

  // Root endpoint
  app.get("/", async () => ({
    name: "Companion Device Status Monitor API",
    version: "1.0.0",
    status: "running",
  }));
}

async function start(): Promise<void> {
  await build();

  try {
    await app.listen({ host: "0.0.0.0", port: env.PORT });
    app.log.info(`✅ API running on http://0.0.0.0:${env.PORT}`);
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

void start();

// Graceful shutdown
for (const signal of ["SIGTERM", "SIGINT"] as const) {
  process.on(signal, async () => {
    console.log(`[SHUTDOWN] Received ${signal}`);
    await app.close();
    await db.end();
    process.exit(0);
  });
}