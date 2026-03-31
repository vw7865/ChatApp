import type { FastifyInstance } from "fastify";
import { db } from "../db.js";

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get("/health", async () => {
    await db.query("SELECT 1");
    return {
      ok: true,
      service: "companion-device-status-monitor",
      timestamp: new Date().toISOString(),
    };
  });
}
