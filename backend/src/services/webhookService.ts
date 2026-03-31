import { db } from "../db.js";
import type { DeviceStatus, InstanceRow, UserRow } from "../types.js";
import { sendApnsNotification } from "./apnsService.js";

interface StatusWebhookPayload {
  event: "status.update";
  instanceId: string;
  data: {
    deviceId: string;
    status: DeviceStatus;
    timestamp: string;
  };
}

export async function dispatchStatusWebhook(
  instance: InstanceRow,
  user: UserRow,
  deviceId: string,
  status: DeviceStatus,
  timestamp: string,
): Promise<void> {
  const payload: StatusWebhookPayload = {
    event: "status.update",
    instanceId: instance.id,
    data: {
      deviceId,
      status,
      timestamp,
    },
  };

  if (instance.webhook_url) {
    await fetch(instance.webhook_url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(payload),
    });
  }

  if (user.apns_device_token) {
    await sendApnsNotification({
      deviceToken: user.apns_device_token,
      silent: true,
      payload: payload as unknown as Record<string, unknown>,
    });
  }
}

export async function setUserApnsToken(userId: string, token: string): Promise<void> {
  await db.query("UPDATE users SET apns_device_token = $2 WHERE id = $1", [userId, token]);
}
