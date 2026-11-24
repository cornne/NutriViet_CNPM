import type { Env } from "./types";

export type OcrProviderId =
  | "kilo-particle-1"
  | "cf-mistral-vision"
  | "baidu-paddleocr"
  | "kilo-nemotron-vl"
  | "cf-llama4-vision";

export type OcrProviderKind = "openai_vision" | "cf_ai_vision" | "baidu_async";

export interface OcrProviderConfig {
  id: OcrProviderId;
  rank: number;
  displayName: string;
  kind: OcrProviderKind;
  model: string;
  endpoint?: string;
  baselineMs: number;
  timeoutMs: number;
  maxRequestsPerWindow: number;
  windowMs: number;
  rateLimitCooldownMs: number;
  errorCooldownMs: number;
  maxTokens?: number;
  extraBody?: Record<string, unknown>;
}

export interface OcrProviderState {
  providerId: OcrProviderId;
  windowStartMs: number;
  windowCount: number;
  cooldownUntilMs: number;
  consecutiveFailures: number;
  lastStatus: "ready" | "ok" | "cooldown_rate_limit" | "cooldown_error";
  lastLatencyMs: number | null;
  lastError: string;
  successCount: number;
  failureCount: number;
  updatedAtMs: number;
}

export interface OcrAttemptTrace {
  provider_id: OcrProviderId;
  engine: string;
  outcome: "ok" | "skipped_cooldown" | "skipped_unavailable" | "rate_limited" | "error";
  latency_ms?: number;
  retry_after_sec?: number;
  detail?: string;
}

export interface OcrImageInput {
  bytes: Uint8Array;
  mimeType: string;
  fileName: string;
  useDocOrientationClassify: boolean;
  useDocUnwarping: boolean;
}

export type OcrRouteOutcome =
  | {
      kind: "sync_done";
      providerId: OcrProviderId;
      engine: string;
      rawMarkdown: string;
      latencyMs: number;
      attempts: OcrAttemptTrace[];
    }
  | {
      kind: "async_job";
      providerId: OcrProviderId;
      engine: string;
      jobId: string;
      latencyMs: number;
      attempts: OcrAttemptTrace[];
    }
  | {
      kind: "all_failed";
      httpStatus: 429 | 502 | 503;
      authError: boolean;
      retryAfterSec: number;
      message: string;
      attempts: OcrAttemptTrace[];
    };

export const AI_STUDIO_JOB_URL = "https://paddleocr.aistudio-app.com/api/v2/ocr/jobs";
export const PADDLE_OCR_MODEL = "PaddleOCR-VL-1.6";

const STRICT_OCR_PROMPT =
  "Perform strict OCR on this food packaging label. Return ONLY the exact transcribed text from the label as plain text, preserving every ingredient, percentage, E-number / INS additive code in parentheses, and allergen warning verbatim. Do not translate, summarize, add markdown, or add commentary.";

/**
 * Empirically benchmarked fastest-to-slowest OCR provider chain.
 * Each provider carries a soft per-window rate cap plus automatic cooldown &
 * recovery on HTTP 429 / upstream errors so requests seamlessly spill over to
 * the next fastest healthy engine until the faster tier recovers.
 */
export const OCR_PROVIDER_CHAIN: readonly OcrProviderConfig[] = [
  {
    id: "kilo-particle-1",
    rank: 1,
    displayName: "Kilo Particle-1",
    kind: "openai_vision",
    model: "particle-ai/particle-1:free",
    endpoint: "https://api.kilo.ai/api/gateway/v1/chat/completions",
    baselineMs: 2100,
    timeoutMs: 12_000,
    maxRequestsPerWindow: 6,
    windowMs: 60_000,
    rateLimitCooldownMs: 90_000,
    errorCooldownMs: 45_000,
    maxTokens: 550,
  },
  {
    id: "cf-mistral-vision",
    rank: 2,
    displayName: "Cloudflare Mistral-3.1",
    kind: "cf_ai_vision",
    model: "@cf/mistralai/mistral-small-3.1-24b-instruct",
    baselineMs: 2900,
    timeoutMs: 15_000,
    maxRequestsPerWindow: 10,
    windowMs: 60_000,
    rateLimitCooldownMs: 300_000,
    errorCooldownMs: 45_000,
    maxTokens: 550,
  },
  {
    id: "baidu-paddleocr",
    rank: 3,
    displayName: PADDLE_OCR_MODEL,
    kind: "baidu_async",
    model: PADDLE_OCR_MODEL,
    endpoint: AI_STUDIO_JOB_URL,
    baselineMs: 4500,
    timeoutMs: 15_000,
    maxRequestsPerWindow: 12,
    windowMs: 60_000,
    rateLimitCooldownMs: 180_000,
    errorCooldownMs: 60_000,
  },
  {
    id: "kilo-nemotron-vl",
    rank: 4,
    displayName: "Kilo Nemotron-VL",
    kind: "openai_vision",
    model: "nvidia/nemotron-3.5-super-vl:free",
    endpoint: "https://api.kilo.ai/api/gateway/v1/chat/completions",
    baselineMs: 8800,
    timeoutMs: 18_000,
    maxRequestsPerWindow: 6,
    windowMs: 60_000,
    rateLimitCooldownMs: 120_000,
    errorCooldownMs: 60_000,
    maxTokens: 750,
    extraBody: { reasoning: { effort: "none", exclude: true } },
  },
  {
    id: "cf-llama4-vision",
    rank: 5,
    displayName: "Cloudflare Llama-4-Scout",
    kind: "cf_ai_vision",
    model: "@cf/meta/llama-4-scout-17b-16e-instruct",
    baselineMs: 9700,
    timeoutMs: 20_000,
    maxRequestsPerWindow: 8,
    windowMs: 60_000,
    rateLimitCooldownMs: 300_000,
    errorCooldownMs: 60_000,
    maxTokens: 550,
  },
];

export function bytesToBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, Math.min(i + chunkSize, bytes.length));
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

export function sniffImageMimeType(bytes: Uint8Array, fallbackName = ""): string {
  if (bytes.length >= 4) {
    if (bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) {
      return "image/png";
    }
    if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
      return "image/jpeg";
    }
    if (
      bytes.length >= 12 &&
      bytes[0] === 0x52 &&
      bytes[1] === 0x49 &&
      bytes[2] === 0x46 &&
      bytes[3] === 0x46 &&
      bytes[8] === 0x57 &&
      bytes[9] === 0x45 &&
      bytes[10] === 0x42 &&
      bytes[11] === 0x50
    ) {
      return "image/webp";
    }
  }
  const low = fallbackName.toLowerCase();
  if (low.endsWith(".png")) return "image/png";
  if (low.endsWith(".webp")) return "image/webp";
  return "image/jpeg";
}

function defaultState(id: OcrProviderId, now: number): OcrProviderState {
  return {
    providerId: id,
    windowStartMs: now,
    windowCount: 0,
    cooldownUntilMs: 0,
    consecutiveFailures: 0,
    lastStatus: "ready",
    lastLatencyMs: null,
    lastError: "",
    successCount: 0,
    failureCount: 0,
    updatedAtMs: 0,
  };
}

function parseRetryAfterMs(headerVal: string | null, fallbackMs: number): number {
  if (!headerVal) return fallbackMs;
  const secs = Number(headerVal.trim());
  if (Number.isFinite(secs) && secs > 0) {
    return Math.max(15_000, Math.min(600_000, Math.round(secs * 1000)));
  }
  const dateMs = Date.parse(headerVal);
  if (Number.isFinite(dateMs)) {
    const diff = dateMs - Date.now();
    if (diff > 0) return Math.max(15_000, Math.min(600_000, diff));
  }
  return fallbackMs;
}

function extractVisionText(payload: unknown): string {
  if (!payload) return "";
  if (typeof payload === "string") return payload.trim();
  if (typeof payload !== "object") return "";
  const obj = payload as Record<string, unknown>;

  if (typeof obj.response === "string" && obj.response.trim()) {
    return obj.response.trim();
  }
  if (typeof obj.answer === "string" && obj.answer.trim()) {
    return obj.answer.trim();
  }
  if (typeof obj.description === "string" && obj.description.trim()) {
    return obj.description.trim();
  }
  const choices = obj.choices;
  if (Array.isArray(choices) && choices.length > 0) {
    const msg = (choices[0] as Record<string, unknown>)?.message as Record<string, unknown> | undefined;
    const content = msg?.content;
    if (typeof content === "string" && content.trim()) return content.trim();
    if (Array.isArray(content)) {
      const joined = content
        .map((part) => {
          if (typeof part === "string") return part;
          if (part && typeof part === "object" && typeof (part as Record<string, unknown>).text === "string") {
            return String((part as Record<string, unknown>).text);
          }
          return "";
        })
        .join("")
        .trim();
      if (joined) return joined;
    }
  }
  return "";
}

function isRateLimitErrorMessage(msg: string): boolean {
  return /\b(429|rate.?limit|quota|too many requests|neurons|capacity|exhausted)\b/i.test(msg);
}

interface ProviderStateRow {
  provider_id: string;
  window_start_ms: number;
  window_count: number;
  cooldown_until_ms: number;
  consecutive_failures: number;
  last_status: string;
  last_latency_ms: number | null;
  last_error: string;
  success_count: number;
  failure_count: number;
  updated_at_ms: number;
}

export class OcrProviderRouter {
  private readonly chain: readonly OcrProviderConfig[];
  private readonly memState = new Map<OcrProviderId, OcrProviderState>();
  private tableInitialized = false;

  constructor(chain: readonly OcrProviderConfig[] = OCR_PROVIDER_CHAIN) {
    this.chain = chain;
  }

  private hasD1(env: Env): boolean {
    return Boolean(env.APP_DB && typeof env.APP_DB.prepare === "function");
  }

  private async ensureTable(env: Env): Promise<void> {
    if (this.tableInitialized || !this.hasD1(env)) return;
    try {
      await env.APP_DB.prepare(
        `CREATE TABLE IF NOT EXISTS ocr_provider_state (
          provider_id TEXT PRIMARY KEY,
          window_start_ms INTEGER NOT NULL DEFAULT 0,
          window_count INTEGER NOT NULL DEFAULT 0,
          cooldown_until_ms INTEGER NOT NULL DEFAULT 0,
          consecutive_failures INTEGER NOT NULL DEFAULT 0,
          last_status TEXT NOT NULL DEFAULT 'ready',
          last_latency_ms INTEGER,
          last_error TEXT NOT NULL DEFAULT '',
          success_count INTEGER NOT NULL DEFAULT 0,
          failure_count INTEGER NOT NULL DEFAULT 0,
          updated_at_ms INTEGER NOT NULL DEFAULT 0
        )`
      ).run();
      this.tableInitialized = true;
    } catch {
      // Fall back silently to isolate memory if D1 DDL is unavailable
    }
  }

  private async loadStates(env: Env, now: number): Promise<Map<OcrProviderId, OcrProviderState>> {
    const map = new Map<OcrProviderId, OcrProviderState>();
    for (const p of this.chain) {
      const mem = this.memState.get(p.id);
      map.set(p.id, mem ? { ...mem } : defaultState(p.id, now));
    }

    if (!this.hasD1(env)) return map;
    await this.ensureTable(env);
    try {
      const res = await env.APP_DB.prepare("SELECT * FROM ocr_provider_state").all<ProviderStateRow>();
      for (const row of res.results || []) {
        const id = row.provider_id as OcrProviderId;
        if (!map.has(id)) continue;
        const dbState: OcrProviderState = {
          providerId: id,
          windowStartMs: Number(row.window_start_ms || 0),
          windowCount: Number(row.window_count || 0),
          cooldownUntilMs: Number(row.cooldown_until_ms || 0),
          consecutiveFailures: Number(row.consecutive_failures || 0),
          lastStatus: (row.last_status as OcrProviderState["lastStatus"]) || "ready",
          lastLatencyMs: row.last_latency_ms != null ? Number(row.last_latency_ms) : null,
          lastError: String(row.last_error || ""),
          successCount: Number(row.success_count || 0),
          failureCount: Number(row.failure_count || 0),
          updatedAtMs: Number(row.updated_at_ms || 0),
        };
        const mem = map.get(id)!;
        if (dbState.updatedAtMs >= mem.updatedAtMs) {
          map.set(id, dbState);
          this.memState.set(id, { ...dbState });
        }
      }
    } catch {
      // Keep in-memory state on transient D1 read failure
    }
    return map;
  }

  private async saveState(env: Env, st: OcrProviderState): Promise<void> {
    this.memState.set(st.providerId, { ...st });
    if (!this.hasD1(env)) return;
    await this.ensureTable(env);
    try {
      await env.APP_DB.prepare(
        `INSERT INTO ocr_provider_state (
          provider_id, window_start_ms, window_count, cooldown_until_ms,
          consecutive_failures, last_status, last_latency_ms, last_error,
          success_count, failure_count, updated_at_ms
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(provider_id) DO UPDATE SET
          window_start_ms = excluded.window_start_ms,
          window_count = excluded.window_count,
          cooldown_until_ms = excluded.cooldown_until_ms,
          consecutive_failures = excluded.consecutive_failures,
          last_status = excluded.last_status,
          last_latency_ms = excluded.last_latency_ms,
          last_error = excluded.last_error,
          success_count = excluded.success_count,
          failure_count = excluded.failure_count,
          updated_at_ms = excluded.updated_at_ms`
      )
        .bind(
          st.providerId,
          st.windowStartMs,
          st.windowCount,
          st.cooldownUntilMs,
          st.consecutiveFailures,
          st.lastStatus,
          st.lastLatencyMs,
          st.lastError,
          st.successCount,
          st.failureCount,
          st.updatedAtMs
        )
        .run();
    } catch {
      // Keep in-memory state even if D1 write hiccups
    }
  }

  private isConfigured(provider: OcrProviderConfig, env: Env, baiduToken: string): boolean {
    if (provider.kind === "cf_ai_vision") {
      return Boolean(env.AI && typeof env.AI.run === "function");
    }
    if (provider.kind === "baidu_async") {
      return Boolean(baiduToken);
    }
    return true;
  }

  private orderedChain(preferredProvider?: string, hasCustomBaiduToken?: boolean): OcrProviderConfig[] {
    const list = [...this.chain];
    const pref = (preferredProvider || "").trim().toLowerCase();
    if (pref) {
      const idx = list.findIndex((p) => p.id === pref);
      if (idx > 0) {
        const [picked] = list.splice(idx, 1);
        list.unshift(picked);
      }
      return list;
    }
    if (hasCustomBaiduToken) {
      const idx = list.findIndex((p) => p.id === "baidu-paddleocr");
      if (idx > 0) {
        const [baidu] = list.splice(idx, 1);
        list.unshift(baidu);
      }
    }
    return list;
  }

  /**
   * Routes an OCR image through the fastest currently-available provider.
   * Automatically skips cooling-down providers, enforces soft rate limits,
   * fails over on 429/errors/empty responses, and recovers automatically once
   * cooldowns elapse.
   */
  async routeImage(
    env: Env,
    input: OcrImageInput,
    options: {
      baiduToken: string;
      hasCustomBaiduToken?: boolean;
      preferredProvider?: string;
      nowMs?: number;
      fetchImpl?: typeof fetch;
    }
  ): Promise<OcrRouteOutcome> {
    const now = options.nowMs ?? Date.now();
    const fetchFn = options.fetchImpl ?? fetch;
    const states = await this.loadStates(env, now);
    const ordered = this.orderedChain(options.preferredProvider, options.hasCustomBaiduToken);
    const attempts: OcrAttemptTrace[] = [];

    let cachedDataUrl: string | null = null;
    const getDataUrl = (): string => {
      if (!cachedDataUrl) {
        cachedDataUrl = `data:${input.mimeType};base64,${bytesToBase64(input.bytes)}`;
      }
      return cachedDataUrl;
    };

    let sawAuthError = false;
    let soonestRetrySec = 30;
    let allRateLimited = true;

    for (const provider of ordered) {
      if (!this.isConfigured(provider, env, options.baiduToken)) {
        attempts.push({
          provider_id: provider.id,
          engine: provider.displayName,
          outcome: "skipped_unavailable",
          detail: "Provider binding or token not configured",
        });
        continue;
      }

      const st = states.get(provider.id) ?? defaultState(provider.id, now);

      // 1. Cooldown check — skip instantly if still cooling down; auto-recover once expired!
      if (st.cooldownUntilMs > now) {
        const retrySec = Math.max(1, Math.ceil((st.cooldownUntilMs - now) / 1000));
        soonestRetrySec = Math.min(soonestRetrySec, retrySec);
        if (st.lastStatus !== "cooldown_rate_limit") allRateLimited = false;
        attempts.push({
          provider_id: provider.id,
          engine: provider.displayName,
          outcome: "skipped_cooldown",
          retry_after_sec: retrySec,
          detail: st.lastError || "Cooling down",
        });
        continue;
      }

      // 2. Soft per-provider window rate limit — rotate to next fastest tier before hitting upstream 429
      if (now - st.windowStartMs >= provider.windowMs) {
        st.windowStartMs = now;
        st.windowCount = 0;
      }
      if (st.windowCount >= provider.maxRequestsPerWindow) {
        const cooldownUntil = st.windowStartMs + provider.windowMs;
        const retrySec = Math.max(1, Math.ceil((cooldownUntil - now) / 1000));
        st.cooldownUntilMs = cooldownUntil;
        st.lastStatus = "cooldown_rate_limit";
        st.lastError = `Soft rate limit (${provider.maxRequestsPerWindow}/${Math.round(provider.windowMs / 1000)}s)`;
        st.updatedAtMs = now;
        await this.saveState(env, st);
        soonestRetrySec = Math.min(soonestRetrySec, retrySec);
        attempts.push({
          provider_id: provider.id,
          engine: provider.displayName,
          outcome: "rate_limited",
          retry_after_sec: retrySec,
          detail: st.lastError,
        });
        continue;
      }

      // 3. Consume soft window slot and invoke provider
      st.windowCount += 1;
      const t0 = Date.now();
      try {
        if (provider.kind === "openai_vision") {
          const res = await this.invokeOpenAIVision(provider, getDataUrl(), fetchFn);
          const latencyMs = Math.max(1, Date.now() - t0);
          if (res.ok) {
            st.consecutiveFailures = 0;
            st.cooldownUntilMs = 0;
            st.lastStatus = "ok";
            st.lastLatencyMs = latencyMs;
            st.lastError = "";
            st.successCount += 1;
            st.updatedAtMs = Date.now();
            await this.saveState(env, st);
            attempts.push({
              provider_id: provider.id,
              engine: provider.displayName,
              outcome: "ok",
              latency_ms: latencyMs,
            });
            return {
              kind: "sync_done",
              providerId: provider.id,
              engine: provider.displayName,
              rawMarkdown: res.text,
              latencyMs,
              attempts,
            };
          }

          await this.recordFailure(env, st, provider, now, {
            isRateLimit: res.rateLimited,
            retryAfterMs: res.retryAfterMs,
            detail: res.error,
          });
          if (!res.rateLimited) allRateLimited = false;
          const retrySec = Math.max(1, Math.ceil((st.cooldownUntilMs - now) / 1000));
          soonestRetrySec = Math.min(soonestRetrySec, retrySec);
          attempts.push({
            provider_id: provider.id,
            engine: provider.displayName,
            outcome: res.rateLimited ? "rate_limited" : "error",
            latency_ms: latencyMs,
            retry_after_sec: retrySec,
            detail: res.error,
          });
          continue;
        }

        if (provider.kind === "cf_ai_vision") {
          const res = await this.invokeCloudflareVision(env, provider, getDataUrl());
          const latencyMs = Math.max(1, Date.now() - t0);
          if (res.ok) {
            st.consecutiveFailures = 0;
            st.cooldownUntilMs = 0;
            st.lastStatus = "ok";
            st.lastLatencyMs = latencyMs;
            st.lastError = "";
            st.successCount += 1;
            st.updatedAtMs = Date.now();
            await this.saveState(env, st);
            attempts.push({
              provider_id: provider.id,
              engine: provider.displayName,
              outcome: "ok",
              latency_ms: latencyMs,
            });
            return {
              kind: "sync_done",
              providerId: provider.id,
              engine: provider.displayName,
              rawMarkdown: res.text,
              latencyMs,
              attempts,
            };
          }

          await this.recordFailure(env, st, provider, now, {
            isRateLimit: res.rateLimited,
            detail: res.error,
          });
          if (!res.rateLimited) allRateLimited = false;
          const retrySec = Math.max(1, Math.ceil((st.cooldownUntilMs - now) / 1000));
          soonestRetrySec = Math.min(soonestRetrySec, retrySec);
          attempts.push({
            provider_id: provider.id,
            engine: provider.displayName,
            outcome: res.rateLimited ? "rate_limited" : "error",
            latency_ms: latencyMs,
            retry_after_sec: retrySec,
            detail: res.error,
          });
          continue;
        }

        if (provider.kind === "baidu_async") {
          const res = await this.invokeBaiduSubmit(provider, input, options.baiduToken, fetchFn);
          const latencyMs = Math.max(1, Date.now() - t0);
          if (res.ok) {
            st.consecutiveFailures = 0;
            st.cooldownUntilMs = 0;
            st.lastStatus = "ok";
            st.lastLatencyMs = latencyMs;
            st.lastError = "";
            st.successCount += 1;
            st.updatedAtMs = Date.now();
            await this.saveState(env, st);
            attempts.push({
              provider_id: provider.id,
              engine: provider.displayName,
              outcome: "ok",
              latency_ms: latencyMs,
            });
            return {
              kind: "async_job",
              providerId: provider.id,
              engine: provider.displayName,
              jobId: res.jobId,
              latencyMs,
              attempts,
            };
          }

          if (res.authError) sawAuthError = true;
          await this.recordFailure(env, st, provider, now, {
            isRateLimit: res.rateLimited,
            retryAfterMs: res.retryAfterMs,
            detail: res.error,
          });
          if (!res.rateLimited) allRateLimited = false;
          const retrySec = Math.max(1, Math.ceil((st.cooldownUntilMs - now) / 1000));
          soonestRetrySec = Math.min(soonestRetrySec, retrySec);
          attempts.push({
            provider_id: provider.id,
            engine: provider.displayName,
            outcome: res.rateLimited ? "rate_limited" : "error",
            latency_ms: latencyMs,
            retry_after_sec: retrySec,
            detail: res.error,
          });
        }
      } catch (err) {
        const latencyMs = Math.max(1, Date.now() - t0);
        const msg = err instanceof Error ? err.message : String(err);
        const isRl = isRateLimitErrorMessage(msg);
        await this.recordFailure(env, st, provider, now, { isRateLimit: isRl, detail: msg });
        if (!isRl) allRateLimited = false;
        const retrySec = Math.max(1, Math.ceil((st.cooldownUntilMs - now) / 1000));
        soonestRetrySec = Math.min(soonestRetrySec, retrySec);
        attempts.push({
          provider_id: provider.id,
          engine: provider.displayName,
          outcome: isRl ? "rate_limited" : "error",
          latency_ms: latencyMs,
          retry_after_sec: retrySec,
          detail: msg.slice(0, 160),
        });
      }
    }

    const attemptedAny = attempts.some((a) => a.outcome !== "skipped_unavailable");
    if (!attemptedAny) {
      return {
        kind: "all_failed",
        httpStatus: 503,
        authError: true,
        retryAfterSec: 30,
        message: "No OCR provider is configured on Cloudflare Worker.",
        attempts,
      };
    }

    return {
      kind: "all_failed",
      httpStatus: allRateLimited ? 429 : 502,
      authError: sawAuthError && !allRateLimited,
      retryAfterSec: Math.max(1, soonestRetrySec),
      message: allRateLimited
        ? `Tất cả máy chủ OCR đang tạm nghỉ giới hạn tốc độ. Vui lòng thử lại sau ${Math.max(1, soonestRetrySec)} giây.`
        : "Không thể kết nối các máy chủ OCR lúc này. Vui lòng thử lại sau ít giây.",
      attempts,
    };
  }

  private async recordFailure(
    env: Env,
    st: OcrProviderState,
    provider: OcrProviderConfig,
    now: number,
    info: { isRateLimit: boolean; retryAfterMs?: number; detail: string }
  ): Promise<void> {
    st.consecutiveFailures += 1;
    st.failureCount += 1;
    st.lastError = info.detail.slice(0, 160);
    st.updatedAtMs = now;
    if (info.isRateLimit) {
      const cd = info.retryAfterMs ?? provider.rateLimitCooldownMs;
      st.cooldownUntilMs = now + cd;
      st.lastStatus = "cooldown_rate_limit";
    } else {
      const mult = Math.pow(2, Math.min(st.consecutiveFailures - 1, 2));
      const cd = Math.min(300_000, provider.errorCooldownMs * mult);
      st.cooldownUntilMs = now + cd;
      st.lastStatus = "cooldown_error";
    }
    await this.saveState(env, st);
  }

  private async invokeOpenAIVision(
    provider: OcrProviderConfig,
    dataUrl: string,
    fetchFn: typeof fetch
  ): Promise<{ ok: true; text: string } | { ok: false; rateLimited: boolean; retryAfterMs?: number; error: string }> {
    const resp = await fetchFn(provider.endpoint!, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: provider.model,
        temperature: 0,
        max_tokens: provider.maxTokens ?? 550,
        ...(provider.extraBody || {}),
        messages: [
          {
            role: "user",
            content: [
              { type: "text", text: STRICT_OCR_PROMPT },
              { type: "image_url", image_url: { url: dataUrl } },
            ],
          },
        ],
      }),
      signal: AbortSignal.timeout(provider.timeoutMs),
    });

    const raw = await resp.text();
    if (resp.status === 429) {
      return {
        ok: false,
        rateLimited: true,
        retryAfterMs: parseRetryAfterMs(resp.headers.get("Retry-After"), provider.rateLimitCooldownMs),
        error: `HTTP 429: ${raw.slice(0, 120)}`,
      };
    }
    if (!resp.ok) {
      const isRl = isRateLimitErrorMessage(raw);
      return {
        ok: false,
        rateLimited: isRl,
        error: `HTTP ${resp.status}: ${raw.slice(0, 120)}`,
      };
    }

    let parsed: unknown = null;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return { ok: false, rateLimited: false, error: "Invalid JSON response" };
    }
    const text = extractVisionText(parsed);
    if (text.length < 8) {
      return { ok: false, rateLimited: false, error: "Empty vision OCR response" };
    }
    return { ok: true, text };
  }

  private async invokeCloudflareVision(
    env: Env,
    provider: OcrProviderConfig,
    dataUrl: string
  ): Promise<{ ok: true; text: string } | { ok: false; rateLimited: boolean; error: string }> {
    if (!env.AI) {
      return { ok: false, rateLimited: false, error: "Workers AI binding unavailable" };
    }
    const raw = await env.AI.run(provider.model, {
      messages: [
        {
          role: "user",
          content: [
            { type: "text", text: STRICT_OCR_PROMPT },
            { type: "image_url", image_url: { url: dataUrl } },
          ],
        },
      ],
      max_tokens: provider.maxTokens ?? 550,
      temperature: 0,
    });
    const text = extractVisionText(raw);
    if (text.length < 8) {
      return { ok: false, rateLimited: false, error: "Empty Cloudflare AI response" };
    }
    return { ok: true, text };
  }

  private async invokeBaiduSubmit(
    provider: OcrProviderConfig,
    input: OcrImageInput,
    token: string,
    fetchFn: typeof fetch
  ): Promise<
    | { ok: true; jobId: string }
    | { ok: false; rateLimited: boolean; authError: boolean; retryAfterMs?: number; error: string }
  > {
    const upstreamForm = new FormData();
    upstreamForm.append("model", PADDLE_OCR_MODEL);
    upstreamForm.append(
      "optionalPayload",
      JSON.stringify({
        useDocOrientationClassify: input.useDocOrientationClassify,
        useDocUnwarping: input.useDocUnwarping,
        useChartRecognition: false,
      })
    );
    const bytesCopy = new Uint8Array(input.bytes.byteLength);
    bytesCopy.set(input.bytes);
    upstreamForm.append("file", new Blob([bytesCopy], { type: input.mimeType }), input.fileName);

    const resp = await fetchFn(AI_STUDIO_JOB_URL, {
      method: "POST",
      headers: { Authorization: `bearer ${token}` },
      body: upstreamForm,
      signal: AbortSignal.timeout(provider.timeoutMs),
    });

    if (resp.status === 401 || resp.status === 403) {
      return {
        ok: false,
        rateLimited: false,
        authError: true,
        error: `AI Studio token rejected (HTTP ${resp.status})`,
      };
    }

    const raw = await resp.text();
    if (resp.status === 429) {
      return {
        ok: false,
        rateLimited: true,
        authError: false,
        retryAfterMs: parseRetryAfterMs(resp.headers.get("Retry-After"), provider.rateLimitCooldownMs),
        error: `HTTP 429: ${raw.slice(0, 120)}`,
      };
    }
    if (!resp.ok) {
      return {
        ok: false,
        rateLimited: isRateLimitErrorMessage(raw),
        authError: false,
        error: `HTTP ${resp.status}: ${raw.slice(0, 120)}`,
      };
    }

    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(raw) as Record<string, unknown>;
    } catch {
      return { ok: false, rateLimited: false, authError: false, error: "Invalid JSON from PaddleOCR" };
    }
    const data = (parsed.data as Record<string, unknown>) || {};
    const jobId = String(data.jobId || "").trim();
    if (!jobId) {
      return { ok: false, rateLimited: false, authError: false, error: "No jobId returned by PaddleOCR" };
    }
    return { ok: true, jobId };
  }

  /**
   * Returns a human-readable live status table of all OCR providers ordered
   * fastest -> slowest, including rate-limit usage and active cooldown timers.
   */
  async getStatusSnapshot(env: Env, nowMs?: number): Promise<Array<Record<string, unknown>>> {
    const now = nowMs ?? Date.now();
    const baiduToken = (env.PADDLEOCR_VL_TOKEN || "").trim();
    const states = await this.loadStates(env, now);

    return this.chain.map((p) => {
      const configured = this.isConfigured(p, env, baiduToken);
      const st = states.get(p.id) ?? defaultState(p.id, now);
      const inCooldown = st.cooldownUntilMs > now;
      const cooldownRemainingSec = inCooldown ? Math.ceil((st.cooldownUntilMs - now) / 1000) : 0;
      const windowExpired = now - st.windowStartMs >= p.windowMs;
      const windowUsed = windowExpired ? 0 : st.windowCount;

      return {
        rank: p.rank,
        id: p.id,
        engine: p.displayName,
        kind: p.kind,
        model: p.model,
        configured,
        status: !configured ? "unconfigured" : inCooldown ? "cooldown" : "ready",
        baseline_ms: p.baselineMs,
        last_latency_ms: st.lastLatencyMs,
        rate_limit_window_sec: Math.round(p.windowMs / 1000),
        rate_limit_used: windowUsed,
        rate_limit_max: p.maxRequestsPerWindow,
        cooldown_remaining_sec: cooldownRemainingSec,
        consecutive_failures: st.consecutiveFailures,
        success_count: st.successCount,
        failure_count: st.failureCount,
        last_error: st.lastError || null,
      };
    });
  }
}

export const defaultOcrRouter = new OcrProviderRouter();

