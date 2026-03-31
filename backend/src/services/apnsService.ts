import apn from "apn";
import { env } from "../config.js";

export interface PushInput {
  deviceToken: string;
  title?: string;
  body?: string;
  payload?: Record<string, unknown>;
  silent?: boolean;
}

let provider: apn.Provider | null = null;

function getProvider(): apn.Provider | null {
  if (!env.APNS_KEY_ID || !env.APNS_TEAM_ID || !env.APNS_BUNDLE_ID || !env.APNS_KEY_PATH) {
    return null;
  }
  if (provider) return provider;

  provider = new apn.Provider({
    token: {
      key: env.APNS_KEY_PATH,
      keyId: env.APNS_KEY_ID,
      teamId: env.APNS_TEAM_ID,
    },
    production: env.APNS_PRODUCTION,
  });
  return provider;
}

export async function sendApnsNotification(input: PushInput): Promise<boolean> {
  const p = getProvider();
  if (!p) return false;
  const topic = env.APNS_BUNDLE_ID;
  if (!topic) return false;

  const note = new apn.Notification();
  note.topic = topic;
  note.payload = input.payload ?? {};
  if (input.silent) {
    note.contentAvailable = true;
  } else {
    note.alert = { title: input.title ?? "Status update", body: input.body ?? "Device status changed." };
    note.sound = "default";
  }

  const result = await p.send(note, input.deviceToken);
  return result.failed.length === 0;
}
