import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import QRCode from "qrcode";
import { env } from "../config.js";
import { db } from "../db.js";
import type { DeviceStatus, InstanceRow } from "../types.js";
import { generateId, generateToken } from "../utils/crypto.js";

async function persistSessionFile(instanceId: string, data: Record<string, unknown>): Promise<string> {
  await mkdir(env.DATA_DIR, { recursive: true });
  const sessionPath = path.join(env.DATA_DIR, `${instanceId}.json`);
  await writeFile(sessionPath, JSON.stringify(data, null, 2), "utf-8");
  return sessionPath;
}

export async function createInstance(userId: string, name: string, webhookUrl?: string): Promise<InstanceRow> {
  const id = generateId("inst");
  const qrToken = generateToken();
  const sessionPath = await persistSessionFile(id, {
    id,
    userId,
    createdAt: new Date().toISOString(),
    linked: false,
    token: qrToken,
  });

  const result = await db.query<InstanceRow>(
    `INSERT INTO instances
      (id, user_id, name, status, webhook_url, session_path, qr_token, linked_device_id)
      VALUES ($1, $2, $3, 'pending', $4, $5, $6, NULL)
      RETURNING *`,
    [id, userId, name, webhookUrl ?? null, sessionPath, qrToken],
  );
  return result.rows[0];
}

export async function listInstances(userId: string): Promise<InstanceRow[]> {
  const result = await db.query<InstanceRow>("SELECT * FROM instances WHERE user_id = $1 ORDER BY created_at DESC", [userId]);
  return result.rows;
}

export async function getOwnedInstance(userId: string, instanceId: string): Promise<InstanceRow | null> {
  const result = await db.query<InstanceRow>("SELECT * FROM instances WHERE id = $1 AND user_id = $2 LIMIT 1", [instanceId, userId]);
  return result.rows[0] ?? null;
}

export async function getQrCodeDataUrl(instance: InstanceRow): Promise<string> {
  const payload = `companion://link?instanceId=${instance.id}&token=${instance.qr_token}`;
  return QRCode.toDataURL(payload, { width: 420, margin: 1 });
}

export async function updateWebhook(instanceId: string, webhookUrl: string): Promise<void> {
  await db.query("UPDATE instances SET webhook_url = $2, updated_at = NOW() WHERE id = $1", [instanceId, webhookUrl]);
}

export async function deleteInstance(instance: InstanceRow): Promise<void> {
  await db.query("DELETE FROM instances WHERE id = $1", [instance.id]);
  await rm(instance.session_path, { force: true });
  await rm(path.join(env.DATA_DIR, instance.id), { recursive: true, force: true });
}

export async function markLinked(instance: InstanceRow, deviceId: string): Promise<void> {
  await db.query(
    "UPDATE instances SET status = 'linked', linked_device_id = $2, updated_at = NOW() WHERE id = $1",
    [instance.id, deviceId],
  );

  let prev: Record<string, unknown> = {};
  try {
    prev = JSON.parse(await readFile(instance.session_path, "utf-8")) as Record<string, unknown>;
  } catch {
    prev = {};
  }
  await writeFile(
    instance.session_path,
    JSON.stringify({ ...prev, linked: true, linkedDeviceId: deviceId, updatedAt: new Date().toISOString() }, null, 2),
    "utf-8",
  );
}

export async function persistStatusEvent(instanceId: string, deviceId: string, status: DeviceStatus, timestampIso: string): Promise<void> {
  await db.query(
    `
      INSERT INTO status_events (instance_id, device_id, status, event_ts, payload)
      VALUES ($1, $2, $3, $4::timestamptz, $5::jsonb)
    `,
    [instanceId, deviceId, status, timestampIso, JSON.stringify({ status })],
  );
}
