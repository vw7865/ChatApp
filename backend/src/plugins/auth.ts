import fp from "fastify-plugin";
import type { FastifyReply, FastifyRequest } from "fastify";
import { db } from "../db.js";
import type { UserRow } from "../types.js";
import { hashApiKey } from "../utils/crypto.js";

declare module "fastify" {
  interface FastifyRequest {
    user: UserRow;
  }
}

async function authGuard(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const apiKey = request.headers["x-api-key"];
  if (!apiKey || Array.isArray(apiKey)) {
    reply.code(401).send({ error: "Missing x-api-key header" });
    return;
  }

  const hashed = hashApiKey(apiKey);
  const result = await db.query<UserRow>(
    "SELECT id, email, api_key_hash, apns_device_token FROM users WHERE api_key_hash = $1 LIMIT 1",
    [hashed],
  );
  const user = result.rows[0];
  if (!user) {
    reply.code(401).send({ error: "Invalid API key" });
    return;
  }

  request.user = user;
}

export const authPlugin = fp(async (app) => {
  app.decorateRequest("user", null);
  app.decorate("authGuard", authGuard);
});

declare module "fastify" {
  interface FastifyInstance {
    authGuard: typeof authGuard;
  }
}
