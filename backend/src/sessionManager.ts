import makeWASocket, { useMultiFileAuthState, DisconnectReason, fetchLatestBaileysVersion } from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import P from 'pino';
import fs from 'fs';
import path from 'path';
import { env } from './config.js';

const sessions = new Map<string, any>();

// Safe fallback to prevent crashes
const fallbackWebhook = async (instanceId: string, payload: any) => {
  console.log(`[WEBHOOK FALLBACK] ${payload.event} for instance ${instanceId}`);
};

let sendWebhookFn: (instanceId: string, payload: any) => Promise<void> = fallbackWebhook;

export function setSendWebhook(fn: (instanceId: string, payload: any) => Promise<void>) {
  sendWebhookFn = fn;
  console.log("[SESSION] Webhook sender successfully registered");
}

export async function createSession(instanceId: string, userId: string) {
  const sessionDir = path.join(env.DATA_DIR, instanceId);
  if (!fs.existsSync(sessionDir)) {
    fs.mkdirSync(sessionDir, { recursive: true });
  }

  const { state, saveCreds } = await useMultiFileAuthState(sessionDir);
  const { version } = await fetchLatestBaileysVersion();

  const sock = makeWASocket({
    version,
    auth: state,
    logger: P({ level: 'silent' }),
    printQRInTerminal: false,
  });

  sessions.set(instanceId, sock);

  sock.ev.on('connection.update', async (update) => {
    const { connection, lastDisconnect, qr } = update;

    if (qr) {
      console.log(`QR for ${instanceId} generated`);
      await sendWebhookFn(instanceId, { event: 'qr', qr });
    }

    if (connection === 'close') {
      const shouldReconnect = (lastDisconnect?.error as Boom)?.output?.statusCode !== DisconnectReason.loggedOut;
      if (shouldReconnect) {
        console.log(`[SESSION] ${instanceId} disconnected - reconnecting in 3 seconds...`);
        setTimeout(() => {
          createSession(instanceId, userId).catch(err => 
            console.error(`[SESSION] Reconnect failed for ${instanceId}:`, err)
          );
        }, 3000);
      } else {
        console.log(`[SESSION] ${instanceId} logged out permanently`);
      }
    } else if (connection === 'open') {
      console.log(`✅ Session ${instanceId} connected successfully`);
      await sendWebhookFn(instanceId, { event: 'connected' });
    }
  });

  // Presence updates for online/offline tracking
  sock.ev.on('presence.update', (update) => {
    const { id, presences } = update;

    Object.entries(presences).forEach(([participant, presenceData]) => {
      const status = presenceData.lastKnownPresence || 'offline';

      sendWebhookFn(instanceId, {
        event: 'status.update',
        instanceId,
        data: {
          deviceId: participant,
          status: status === 'available' ? 'online' : 'offline',
          timestamp: new Date().toISOString()
        }
      });
    });
  });

  sock.ev.on('creds.update', saveCreds);

  return sock;
}

export function deleteSession(instanceId: string) {
  const sock = sessions.get(instanceId);
  if (sock) {
    sock.end();
    sessions.delete(instanceId);
  }
}