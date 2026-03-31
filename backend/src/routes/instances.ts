import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { DeviceStatus } from "../types.js";
import {
  createInstance,
  deleteInstance,
  getOwnedInstance,
  getQrCodeDataUrl,
  listInstances,
  markLinked,
  persistStatusEvent,
  updateWebhook,
} from "../services/instanceService.js";
import { dispatchStatusWebhook, setUserApnsToken } from "../services/webhookService.js";

import { createSession, deleteSession } from "../sessionManager.js";

const createInstanceSchema = z.object({
  name: z.string().min(1).max(120).default("My linked device"),
  webhookUrl: z.string().url().optional(),
});

const webhookUpdateSchema = z.object({
  webhookUrl: z.string().url(),
});

const linkSchema = z.object({
  deviceId: z.string().min(1).max(200),
});

const statusSchema = z.object({
  deviceId: z.string().min(1).max(200),
  status: z.enum(["online", "offline", "away"]),
  timestamp: z.string().datetime().optional(),
});

const apnsSchema = z.object({
  token: z.string().min(32),
});

export async function instanceRoutes(app: FastifyInstance): Promise<void> {
  app.register(async (authed) => {
    authed.addHook("preHandler", authed.authGuard);

    // CREATE INSTANCE
    authed.post("/instances/create", async (request, reply) => {
      const parsed = createInstanceSchema.safeParse(request.body);
      if (!parsed.success) {
        reply.code(400);
        return { error: parsed.error.flatten() };
      }

      console.log(`[CREATE] Starting for user ${request.user.id}, name: "${parsed.data.name}"`);

      let instance;
      try {
        instance = await createInstance(
          request.user.id,
          parsed.data.name,
          parsed.data.webhookUrl
        );
        console.log(`[CREATE] DB instance created - ID: ${instance.id}`);
      } catch (err) {
        console.error("[CREATE] DB creation failed:", err);
        reply.code(500);
        return { error: "Failed to create instance" };
      }

      try {
        console.log(`[CREATE] Starting Baileys session...`);
        await createSession(instance.id, request.user.id);
        console.log(`[CREATE] Baileys session started`);
      } catch (err) {
        console.error(`[CREATE] Baileys session error:`, err);
      }

      let qrDataUrl: string | null = null;
      try {
        console.log(`[CREATE] Generating QR code...`);
        qrDataUrl = await getQrCodeDataUrl(instance);
        console.log(`[CREATE] QR length: ${qrDataUrl ? qrDataUrl.length : 0}`);
      } catch (err) {
        console.error(`[CREATE] QR generation failed:`, err);
      }

      console.log(`[CREATE] Returning JSON to client`);

      reply.code(201).type("application/json");
      return {
        success: true,
        instance: instance,
        qrCode: qrDataUrl,
        message: qrDataUrl 
          ? "Scan this QR code with WhatsApp to link your account" 
          : "QR code generation failed - check server logs"
      };
    });

    // STATUS ENDPOINT (used by iOS polling)
    authed.get("/instances/:id/status", async (request, reply) => {
      const id = (request.params as { id: string }).id;
      const instance = await getOwnedInstance(request.user.id, id);
      if (!instance) return reply.code(404).send({ error: "Instance not found" });

      return {
        instanceId: instance.id,
        linked: instance.status === "linked",
        status: instance.status,
        name: instance.name,
        linkedDeviceId: instance.linked_device_id,
        updatedAt: instance.updated_at
      };
    });

    // Other routes
    authed.get("/instances", async (request) => {
      const items = await listInstances(request.user.id);
      return { instances: items };
    });

    authed.get("/instances/:id/qr", async (request, reply) => {
      const id = (request.params as { id: string }).id;
      const instance = await getOwnedInstance(request.user.id, id);
      if (!instance) return reply.code(404).send({ error: "Instance not found" });

      const qrDataUrl = await getQrCodeDataUrl(instance);
      return { instanceId: instance.id, qrCode: qrDataUrl };
    });

    authed.put("/instances/:id/webhook", async (request, reply) => {
      const id = (request.params as { id: string }).id;
      const parsed = webhookUpdateSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

      const instance = await getOwnedInstance(request.user.id, id);
      if (!instance) return reply.code(404).send({ error: "Instance not found" });

      await updateWebhook(instance.id, parsed.data.webhookUrl);
      return { ok: true };
    });

    authed.delete("/instances/:id", async (request, reply) => {
      const id = (request.params as { id: string }).id;
      const instance = await getOwnedInstance(request.user.id, id);
      if (!instance) return reply.code(404).send({ error: "Instance not found" });

      deleteSession(id);
      await deleteInstance(instance);
      return reply.code(204).send();
    });

    authed.post("/instances/:id/link", async (request, reply) => {
      const id = (request.params as { id: string }).id;
      const parsed = linkSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

      const instance = await getOwnedInstance(request.user.id, id);
      if (!instance) return reply.code(404).send({ error: "Instance not found" });

      await markLinked(instance, parsed.data.deviceId);
      return { ok: true, instanceId: id, linkedDeviceId: parsed.data.deviceId };
    });

    authed.post("/instances/:id/status", async (request, reply) => {
      const id = (request.params as { id: string }).id;
      const parsed = statusSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

      const instance = await getOwnedInstance(request.user.id, id);
      if (!instance) return reply.code(404).send({ error: "Instance not found" });

      const timestamp = parsed.data.timestamp ?? new Date().toISOString();
      const status = parsed.data.status as DeviceStatus;

      await persistStatusEvent(instance.id, parsed.data.deviceId, status, timestamp);
      await dispatchStatusWebhook(instance, request.user, parsed.data.deviceId, status, timestamp);

      return {
        ok: true,
        forwarded: Boolean(instance.webhook_url),
        event: {
          event: "status.update",
          instanceId: instance.id,
          data: { deviceId: parsed.data.deviceId, status, timestamp },
        },
      };
    });

    authed.post("/me/device-token", async (request, reply) => {
      const parsed = apnsSchema.safeParse(request.body);
      if (!parsed.success) return reply.code(400).send({ error: parsed.error.flatten() });

      await setUserApnsToken(request.user.id, parsed.data.token);
      return { ok: true };
    });
  });
}