/**
 * Web Crypto PBKDF2-HMAC-SHA256 (100,000 iterations, hex UTF-8 salt)
 * 100% byte-compatible with Python `hashlib.pbkdf2_hmac('sha256', pwd, salt, 100000)`.
 */

const encoder = new TextEncoder();

export function bytesToHex(bytes: Uint8Array): string {
  let hex = "";
  for (let i = 0; i < bytes.length; i++) {
    hex += bytes[i].toString(16).padStart(2, "0");
  }
  return hex;
}

export function randomHex(byteLen: number): string {
  const buf = new Uint8Array(byteLen);
  crypto.getRandomValues(buf);
  return bytesToHex(buf);
}

export function randomUrlSafeToken(byteLen = 32): string {
  const buf = new Uint8Array(byteLen);
  crypto.getRandomValues(buf);
  let bin = "";
  for (let i = 0; i < buf.length; i++) {
    bin += String.fromCharCode(buf[i]);
  }
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export async function hashPassword(
  password: string,
  salt?: string
): Promise<{ hash: string; salt: string }> {
  const actualSalt = salt && salt.length > 0 ? salt : randomHex(16);
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    encoder.encode(password),
    { name: "PBKDF2" },
    false,
    ["deriveBits"]
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-256",
      salt: encoder.encode(actualSalt),
      iterations: 100000,
    },
    keyMaterial,
    256
  );
  return { hash: bytesToHex(new Uint8Array(bits)), salt: actualSalt };
}

export function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

export async function verifyPassword(
  password: string,
  storedHash: string,
  salt: string
): Promise<boolean> {
  if (!storedHash || !salt) return false;
  const { hash } = await hashPassword(password, salt);
  return timingSafeEqualHex(hash.toLowerCase(), storedHash.toLowerCase());
}

