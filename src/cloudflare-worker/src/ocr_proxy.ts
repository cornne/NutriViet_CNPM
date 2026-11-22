import { Hono } from "hono";
import type { Env } from "./types";

const AI_STUDIO_JOB_URL = "https://paddleocr.aistudio-app.com/api/v2/ocr/jobs";
const OCR_MODEL = "PaddleOCR-VL-1.6";
const SAFE_JOB_ID_RE = /^[A-Za-z0-9_-]{6,80}$/;

/**
 * Cleans Markdown / HTML tables returned by PaddleOCR-VL-1.6 into crisp
 * ingredient text preserving all Vietnamese diacritics, percentages, and E-codes.
 */
export function extractCleanOcrText(markdown: string): string {
  if (!markdown || !markdown.trim()) return "";
  let s = markdown.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  s = s.replace(/!\[[^\]]*\]\([^)]*\)/g, "");
  s = s.replace(/<img\b[^>]*>/gi, "");
  s = s.replace(/<br\s*\/?>/gi, "\n");
  s = s.replace(/<\/(p|div|tr|li|h[1-6])>/gi, "\n");
  s = s.replace(/<\/(td|th)>/gi, ", ");
  s = s.replace(/<[^>]+>/g, "");
  s = s.replace(/^\s{0,3}#{1,6}\s+/gm, "");
  s = s.replace(/^\s*>\s?/gm, "");
  s = s.replace(/\*\*|__|`/g, "");
  s = s.replace(/^\s*\|?[\s:\-|]+\|?\s*$/gm, "");
  s = s.replace(/\s*\|\s*/g, ", ");
  s = s
    .replace(/&amp;/g, "&")
    .replace(/&nbsp;/g, " ")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");

  const out: string[] = [];
  let prevNorm = "";
  for (const rawLine of s.split("\n")) {
    const line = rawLine
      .replace(/[ \t]+/g, " ")
      .replace(/(,\s*){2,}/g, ", ")
      .replace(/^,\s*|,\s*$/g, "")
      .trim();
    if (!line) continue;
    const norm = line.toLowerCase();
    if (norm === prevNorm) continue;
    out.push(line);
    prevNorm = norm;
  }
  return out.join("\n");
}

function resolveToken(env: Env, req: Request): string {
  const override = (req.headers.get("X-PaddleOCR-Token") || "").trim();
  if (override) return override;
  return (env.PADDLEOCR_VL_TOKEN || "").trim();
}

export function registerOcrRoutes(app: Hono<{ Bindings: Env }>) {
  /**
   * POST /api/v1/ocr/jobs
   * Accepts multipart image (`file`) or JSON `{ data_base64, filename }` and
   * submits it to Baidu AI Studio PaddleOCR-VL-1.6 using the server secret.
   */
  app.post("/api/v1/ocr/jobs", async (c) => {
    const token = resolveToken(c.env, c.req.raw);
    if (!token) {
      return c.json(
        {
          success: false,
          auth_error: true,
          message: "PADDLEOCR_VL_TOKEN secret is not configured on Cloudflare Worker.",
        },
        503
      );
    }

    const ct = (c.req.header("content-type") || "").toLowerCase();
    let fileBlob: Blob | null = null;
    let fileName = "label.jpg";
    let useOrient = true;
    let useUnwarp = false;

    try {
      if (ct.includes("multipart/form-data")) {
        const form = await c.req.formData();
        const uploaded = form.get("file");
        if (uploaded && typeof uploaded !== "string") {
          const f = uploaded as File;
          fileBlob = f;
          fileName = f.name || "label.jpg";
        }
        const optRaw = form.get("optionalPayload");
        if (typeof optRaw === "string" && optRaw.trim()) {
          try {
            const parsed = JSON.parse(optRaw) as Record<string, unknown>;
            if (typeof parsed.useDocOrientationClassify === "boolean") {
              useOrient = parsed.useDocOrientationClassify;
            }
            if (typeof parsed.useDocUnwarping === "boolean") {
              useUnwarp = parsed.useDocUnwarping;
            }
          } catch {
            // Keep safe defaults
          }
        }
      } else {
        const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
        let b64 = String(body.data_base64 || "").trim();
        if (b64.includes(",") && b64.toLowerCase().startsWith("data:")) {
          b64 = b64.split(",", 2)[1];
        }
        if (b64) {
          const bin = atob(b64);
          const arr = new Uint8Array(bin.length);
          for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
          fileBlob = new Blob([arr], { type: "image/jpeg" });
          fileName = String(body.filename || "label.jpg");
        }
        if (typeof body.useDocOrientationClassify === "boolean") {
          useOrient = body.useDocOrientationClassify;
        }
        if (typeof body.useDocUnwarping === "boolean") {
          useUnwarp = body.useDocUnwarping;
        }
      }
    } catch {
      return c.json({ success: false, message: "Invalid image upload payload." }, 400);
    }

    if (!fileBlob || fileBlob.size === 0) {
      return c.json({ success: false, message: "Missing image file." }, 400);
    }
    if (fileBlob.size > 5 * 1024 * 1024) {
      return c.json({ success: false, message: "Image size exceeds 5MB limit." }, 400);
    }

    const upstreamForm = new FormData();
    upstreamForm.append("model", OCR_MODEL);
    upstreamForm.append(
      "optionalPayload",
      JSON.stringify({
        useDocOrientationClassify: useOrient,
        useDocUnwarping: useUnwarp,
        useChartRecognition: false,
      })
    );
    upstreamForm.append("file", fileBlob, fileName);

    const upstreamResp = await fetch(AI_STUDIO_JOB_URL, {
      method: "POST",
      headers: { Authorization: `bearer ${token}` },
      body: upstreamForm,
    });

    if (upstreamResp.status === 401 || upstreamResp.status === 403) {
      return c.json(
        {
          success: false,
          auth_error: true,
          message: `AI Studio token rejected (HTTP ${upstreamResp.status}).`,
        },
        upstreamResp.status
      );
    }

    const upstreamText = await upstreamResp.text();
    if (!upstreamResp.ok) {
      return c.json(
        {
          success: false,
          message: `Upstream PaddleOCR-VL-1.6 error (HTTP ${upstreamResp.status}).`,
          detail: upstreamText.slice(0, 240),
        },
        502
      );
    }

    let parsed: Record<string, unknown> = {};
    try {
      parsed = JSON.parse(upstreamText) as Record<string, unknown>;
    } catch {
      return c.json({ success: false, message: "Invalid JSON from upstream OCR service." }, 502);
    }

    const data = (parsed.data as Record<string, unknown>) || {};
    const jobId = String(data.jobId || "").trim();
    if (!jobId) {
      return c.json({ success: false, message: "No jobId returned by PaddleOCR-VL-1.6." }, 502);
    }

    return c.json({
      success: true,
      jobId,
      engine: OCR_MODEL,
      size_bytes: fileBlob.size,
    });
  });

  /**
   * GET /api/v1/ocr/jobs/:jobId
   * Polls AI Studio job status using the server secret. When state == 'done',
   * fetches and parses the JSONL result server-side on Cloudflare Edge!
   */
  app.get("/api/v1/ocr/jobs/:jobId", async (c) => {
    const token = resolveToken(c.env, c.req.raw);
    if (!token) {
      return c.json(
        { success: false, auth_error: true, message: "PADDLEOCR_VL_TOKEN secret not configured." },
        503
      );
    }

    const jobId = (c.req.param("jobId") || "").trim();
    if (!SAFE_JOB_ID_RE.test(jobId)) {
      return c.json({ success: false, message: "Invalid jobId." }, 400);
    }

    const pollResp = await fetch(`${AI_STUDIO_JOB_URL}/${encodeURIComponent(jobId)}`, {
      method: "GET",
      headers: { Authorization: `bearer ${token}` },
    });

    if (pollResp.status === 401 || pollResp.status === 403) {
      return c.json(
        { success: false, auth_error: true, message: "AI Studio token rejected." },
        pollResp.status
      );
    }
    if (!pollResp.ok) {
      return c.json(
        { success: false, message: `Upstream poll error (HTTP ${pollResp.status}).` },
        502
      );
    }

    const pollJson = (await pollResp.json()) as {
      data?: {
        state?: string;
        errorMsg?: string;
        resultUrl?: { jsonUrl?: string };
      };
    };
    const state = String(pollJson.data?.state || "pending").toLowerCase();

    if (state === "failed") {
      return c.json({
        success: false,
        state: "failed",
        message: pollJson.data?.errorMsg || "PaddleOCR-VL-1.6 processing failed.",
      });
    }

    if (state !== "done") {
      return c.json({ success: true, state, jobId });
    }

    const jsonlUrl = String(pollJson.data?.resultUrl?.jsonUrl || "").trim();
    if (!jsonlUrl) {
      return c.json({ success: false, state: "failed", message: "Missing OCR result URL." }, 502);
    }

    const resResp = await fetch(jsonlUrl);
    if (!resResp.ok) {
      return c.json(
        { success: false, message: `Failed to fetch OCR result payload (HTTP ${resResp.status}).` },
        502
      );
    }

    const jsonlText = await resResp.text();
    const mdChunks: string[] = [];
    for (const line of jsonlText.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      try {
        const obj = JSON.parse(trimmed) as {
          result?: { layoutParsingResults?: Array<{ markdown?: { text?: string } }> };
        };
        for (const item of obj.result?.layoutParsingResults || []) {
          const md = item.markdown?.text?.trim();
          if (md) mdChunks.push(md);
        }
      } catch {
        // Ignore malformed line
      }
    }

    const rawMarkdown = mdChunks.join("\n\n").trim();
    const cleaned = extractCleanOcrText(rawMarkdown);
    const lines = cleaned.split("\n").map((l) => l.trim()).filter(Boolean);

    return c.json({
      success: true,
      state: "done",
      job_id: jobId,
      engine: OCR_MODEL,
      text: cleaned,
      raw_markdown: rawMarkdown,
      line_count: lines.length,
    });
  });
}
