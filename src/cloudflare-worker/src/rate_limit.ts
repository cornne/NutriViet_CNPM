/**
 * Lightweight per-isolate sliding-window IP rate limiter for Cloudflare Workers.
 * Protects authentication and OCR submission endpoints against bursts & brute force.
 */
export interface RateLimitRule {
  bucket: string;
  limit: number;
  windowMs: number;
}

export interface RateLimitVerdict {
  allowed: boolean;
  remaining: number;
  retryAfterSec: number;
}

export class SlidingWindowRateLimiter {
  private readonly hits = new Map<string, number[]>();
  private readonly maxTrackedKeys: number;

  constructor(maxTrackedKeys = 512) {
    this.maxTrackedKeys = maxTrackedKeys;
  }

  check(rule: RateLimitRule, clientIp: string, nowMs = Date.now()): RateLimitVerdict {
    const ip = (clientIp || "unknown").trim() || "unknown";
    const key = `${rule.bucket}:${ip}`;
    const cutoff = nowMs - rule.windowMs;

    let timestamps = this.hits.get(key);
    if (timestamps) {
      timestamps = timestamps.filter((t) => t > cutoff);
    } else {
      timestamps = [];
    }

    if (timestamps.length >= rule.limit) {
      this.hits.set(key, timestamps);
      const oldest = timestamps[0] ?? nowMs;
      const retryAfterSec = Math.max(1, Math.ceil((oldest + rule.windowMs - nowMs) / 1000));
      return { allowed: false, remaining: 0, retryAfterSec };
    }

    timestamps.push(nowMs);
    this.hits.set(key, timestamps);

    // Prevent unbounded map growth inside long-lived Worker isolates
    if (this.hits.size > this.maxTrackedKeys) {
      for (const [k, list] of this.hits.entries()) {
        if (list.length === 0 || list[list.length - 1] <= cutoff) {
          this.hits.delete(k);
        }
        if (this.hits.size <= this.maxTrackedKeys) break;
      }
      if (this.hits.size > this.maxTrackedKeys) {
        const firstKey = this.hits.keys().next().value;
        if (firstKey !== undefined) this.hits.delete(firstKey);
      }
    }

    return {
      allowed: true,
      remaining: Math.max(0, rule.limit - timestamps.length),
      retryAfterSec: 0,
    };
  }
}

export function extractClientIp(req: Request): string {
  const cfIp = (req.headers.get("CF-Connecting-IP") || "").trim();
  if (cfIp) return cfIp;
  const xff = (req.headers.get("X-Forwarded-For") || "").split(",")[0]?.trim();
  if (xff) return xff;
  return "unknown";
}

