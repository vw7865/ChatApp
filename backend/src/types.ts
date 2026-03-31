export type DeviceStatus = "online" | "offline" | "away";

export interface UserRow {
  id: string;
  email: string;
  api_key_hash: string;
  apns_device_token: string | null;
}

export interface InstanceRow {
  id: string;
  user_id: string;
  name: string;
  status: "pending" | "linked" | "disconnected";
  webhook_url: string | null;
  session_path: string;
  qr_token: string;
  linked_device_id: string | null;
  created_at: string;
  updated_at: string;
}
