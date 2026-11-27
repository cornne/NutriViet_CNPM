import { Hono } from "hono";
import { randomHex } from "./crypto";
import type { Env, ViewerUser } from "./types";

const VALID_VERDICTS = new Set(["RED", "YELLOW", "GREEN"]);
const SAFE_MEDIA_NAME_RE = /^[a-f0-9]{16,40}\.(jpg|jpeg|png|webp)$/;
const MAX_IMAGE_BYTES = 1.5 * 1024 * 1024; // 1.5 MB cap for D1 media table

function utcNowIso(): string {
  return new Date().toISOString();
}

function sanitizeImageUrl(url: string): string {
  const clean = (url || "").trim();
  if (!clean) return "";
  if (clean.startsWith("https://") || clean.startsWith("http://") || clean.startsWith("/api/v1/community/media/")) {
    return clean.slice(0, 1200);
  }
  return "";
}

function detectImageFormat(raw: Uint8Array): { ext: string; mime: string } | null {
  if (raw.length < 12 || raw.length > MAX_IMAGE_BYTES) return null;
  if (raw[0] === 0x89 && raw[1] === 0x50 && raw[2] === 0x4e && raw[3] === 0x47) {
    return { ext: "png", mime: "image/png" };
  }
  if (raw[0] === 0xff && raw[1] === 0xd8 && raw[2] === 0xff) {
    return { ext: "jpg", mime: "image/jpeg" };
  }
  if (
    raw[0] === 0x52 && raw[1] === 0x49 && raw[2] === 0x46 && raw[3] === 0x46 &&
    raw[8] === 0x57 && raw[9] === 0x45 && raw[10] === 0x42 && raw[11] === 0x50
  ) {
    return { ext: "webp", mime: "image/webp" };
  }
  return null;
}

function decodeBase64Bytes(b64: string): Uint8Array | null {
  try {
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
  } catch {
    return null;
  }
}

export function extractBearerToken(req: Request): string {
  const auth = (req.headers.get("Authorization") || "").trim();
  return auth.toLowerCase().startsWith("bearer ")
    ? auth.slice(7).trim()
    : (req.headers.get("X-Auth-Token") || "").trim();
}

export async function authenticateViewer(
  req: Request,
  db: D1Database
): Promise<{ viewer?: ViewerUser; token?: string; errorStatus?: 401 | 403; errorBody?: Record<string, unknown> }> {
  const token = extractBearerToken(req);

  if (!token) {
    return {
      errorStatus: 401,
      errorBody: {
        success: false,
        code: "AUTH_REQUIRED",
        message: "Authentication is required.",
      },
    };
  }

  const row = await db
    .prepare(
      `SELECT u.id, u.full_name, u.email, u.is_verified, u.role, u.is_banned
       FROM user_sessions s
       JOIN users u ON u.id = s.user_id
       WHERE s.token = ?`
    )
    .bind(token)
    .first<ViewerUser>();

  if (!row) {
    return {
      errorStatus: 401,
      errorBody: {
        success: false,
        code: "INVALID_TOKEN",
        message: "Session expired or invalid. Please sign in again.",
      },
    };
  }
  if (Number(row.is_banned || 0) === 1) {
    return {
      errorStatus: 403,
      errorBody: {
        success: false,
        code: "ACCOUNT_BANNED",
        message: "This account has been suspended by an administrator.",
      },
    };
  }
  return { viewer: row, token };
}

export async function requireAdmin(
  req: Request,
  db: D1Database
): Promise<{ viewer?: ViewerUser; token?: string; errorStatus?: 401 | 403; errorBody?: Record<string, unknown> }> {
  const auth = await authenticateViewer(req, db);
  if (!auth.viewer) return auth;
  if (auth.viewer.role !== "admin") {
    return {
      errorStatus: 403,
      errorBody: {
        success: false,
        code: "ADMIN_REQUIRED",
        message: "Administrator privileges required.",
      },
    };
  }
  return auth;
}

function serializePost(row: Record<string, unknown>, viewer: ViewerUser, likedIds: Set<number>) {
  const isAdmin = viewer.role === "admin";
  const isOwner = Number(row.user_id) === Number(viewer.id);
  const id = Number(row.id);
  return {
    id,
    author_id: Number(row.user_id),
    author_name: row.author_name,
    author_role: row.author_role,
    product_name: row.product_name,
    brand: row.brand,
    verdict: row.verdict,
    ingredients_text: row.ingredients_text,
    content: row.content,
    image_url: row.image_url,
    barcode: row.barcode,
    status: row.status,
    hidden_reason: row.hidden_reason,
    likes_count: Number(row.likes_count ?? 0),
    comments_count: Number(row.comments_count ?? 0),
    is_liked: likedIds.has(id),
    can_delete: isOwner || isAdmin,
    can_moderate: isAdmin,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

async function fetchPostById(db: D1Database, postId: number, viewer: ViewerUser) {
  const row = await db
    .prepare(
      `SELECT p.*, u.full_name AS author_name, u.role AS author_role,
              (SELECT COUNT(*) FROM community_likes l WHERE l.post_id = p.id) AS likes_count,
              (SELECT COUNT(*) FROM community_comments c WHERE c.post_id = p.id AND c.status = 'visible') AS comments_count
       FROM community_posts p
       JOIN users u ON u.id = p.user_id
       WHERE p.id = ?`
    )
    .bind(postId)
    .first<Record<string, unknown>>();
  if (!row) return null;

  const liked = await db
    .prepare("SELECT 1 FROM community_likes WHERE post_id = ? AND user_id = ?")
    .bind(postId, viewer.id)
    .first();
  return serializePost(row, viewer, liked ? new Set([postId]) : new Set());
}

export function registerCommunityAndAdminRoutes(app: Hono<{ Bindings: Env }>) {
  // Public static serving for verified uploaded community images (stored in D1 community_media)
  app.get("/api/v1/community/media/:filename", async (c) => {
    const filename = c.req.param("filename");
    if (!SAFE_MEDIA_NAME_RE.test(filename)) return c.json({ success: false, message: "Not found" }, 404);
    const row = await c.env.APP_DB.prepare("SELECT mime_type, data_base64 FROM community_media WHERE filename = ?")
      .bind(filename)
      .first<{ mime_type: string; data_base64: string }>();
    if (!row) return c.json({ success: false, message: "Not found" }, 404);
    const bytes = decodeBase64Bytes(row.data_base64);
    if (!bytes) return c.json({ success: false, message: "Corrupt media" }, 500);
    return new Response(bytes, {
      status: 200,
      headers: {
        "Content-Type": row.mime_type,
        "Cache-Control": "public, max-age=86400",
        "Access-Control-Allow-Origin": "*",
      },
    });
  });

  // Upload community image (auth required)
  app.post("/api/v1/community/upload-image", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    let b64 = String(body.data_base64 || "").trim();
    if (b64.includes(",") && b64.toLowerCase().startsWith("data:")) {
      b64 = b64.split(",", 2)[1];
    }
    const raw = decodeBase64Bytes(b64);
    if (!raw) return c.json({ success: false, message: "Invalid base64 image payload." }, 400);
    const detected = detectImageFormat(raw);
    if (!detected) {
      return c.json(
        { success: false, message: "Unsupported image format or size exceeds 1.5MB (JPEG/PNG/WebP only)." },
        400
      );
    }

    const filename = `${randomHex(16)}.${detected.ext}`;
    await c.env.APP_DB.prepare(
      "INSERT INTO community_media (filename, mime_type, data_base64, size_bytes, created_at) VALUES (?, ?, ?, ?, ?)"
    )
      .bind(filename, detected.mime, b64, raw.length, utcNowIso())
      .run();

    const relPath = `/api/v1/community/media/${filename}`;
    const origin = (c.env.PUBLIC_BASE_URL || new URL(c.req.url).origin).replace(/\/+$/, "");
    return c.json(
      {
        success: true,
        image_path: relPath,
        image_url: `${origin}${relPath}`,
        mime_type: detected.mime,
        size_bytes: raw.length,
      },
      201
    );
  });

  // Feed GET
  app.get("/api/v1/community/posts", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const viewer = auth.viewer;

    const verdict = (c.req.query("verdict") || "ALL").trim().toUpperCase();
    const qText = (c.req.query("q") || "").trim().toLowerCase();
    const incHiddenRaw = (c.req.query("include_hidden") || "0").trim().toLowerCase();
    const includeHidden = viewer.role === "admin" && ["1", "true", "yes"].includes(incHiddenRaw);
    const limit = Math.max(1, Math.min(Number(c.req.query("limit") || 30), 100));
    const offset = Math.max(0, Number(c.req.query("offset") || 0));

    const where: string[] = [];
    const params: unknown[] = [];
    if (!includeHidden) where.push("p.status = 'visible'");
    if (VALID_VERDICTS.has(verdict)) {
      where.push("p.verdict = ?");
      params.push(verdict);
    }
    if (qText) {
      const likeQ = `%${qText}%`;
      where.push(
        "(LOWER(p.product_name) LIKE ? OR LOWER(p.brand) LIKE ? OR LOWER(p.content) LIKE ? OR LOWER(p.ingredients_text) LIKE ?)"
      );
      params.push(likeQ, likeQ, likeQ, likeQ);
    }
    const whereSql = where.length > 0 ? `WHERE ${where.join(" AND ")}` : "";

    const rowsRes = await c.env.APP_DB.prepare(
      `SELECT p.*, u.full_name AS author_name, u.role AS author_role,
              (SELECT COUNT(*) FROM community_likes l WHERE l.post_id = p.id) AS likes_count,
              (SELECT COUNT(*) FROM community_comments c WHERE c.post_id = p.id AND c.status = 'visible') AS comments_count
       FROM community_posts p
       JOIN users u ON u.id = p.user_id
       ${whereSql}
       ORDER BY p.id DESC
       LIMIT ? OFFSET ?`
    )
      .bind(...params, limit, offset)
      .all<Record<string, unknown>>();

    const postIds = rowsRes.results.map((r) => Number(r.id));
    const likedIds = new Set<number>();
    if (postIds.length > 0) {
      const ph = postIds.map(() => "?").join(",");
      const likedRes = await c.env.APP_DB.prepare(
        `SELECT post_id FROM community_likes WHERE user_id = ? AND post_id IN (${ph})`
      )
        .bind(viewer.id, ...postIds)
        .all<{ post_id: number }>();
      for (const r of likedRes.results) likedIds.add(Number(r.post_id));
    }

    const posts = rowsRes.results.map((r) => serializePost(r, viewer, likedIds));
    return c.json({ success: true, count: posts.length, posts });
  });

  // Create post
  app.post("/api/v1/community/posts", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const viewer = auth.viewer;

    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const productName = String(body.product_name || "").trim();
    const brand = String(body.brand || "").trim();
    let verdict = String(body.verdict || "GREEN").trim().toUpperCase();
    if (!VALID_VERDICTS.has(verdict)) verdict = "GREEN";
    const ingredientsText = String(body.ingredients_text || "").trim();
    const content = String(body.content || "").trim();
    const imageUrl = sanitizeImageUrl(String(body.image_url || ""));
    const barcode = String(body.barcode || "").trim().slice(0, 64);

    if (!productName) return c.json({ success: false, message: "Product name is required." }, 400);

    const now = utcNowIso();
    const ins = await c.env.APP_DB.prepare(
      `INSERT INTO community_posts
       (user_id, product_name, brand, verdict, ingredients_text, content, image_url, barcode, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'visible', ?, ?)`
    )
      .bind(
        viewer.id,
        productName.slice(0, 180),
        brand.slice(0, 120),
        verdict,
        ingredientsText.slice(0, 2000),
        content.slice(0, 2000),
        imageUrl,
        barcode,
        now,
        now
      )
      .run();

    const postId = Number(ins.meta.last_row_id);
    const post = await fetchPostById(c.env.APP_DB, postId, viewer);
    return c.json({ success: true, post }, 201);
  });

  // Like / unlike post
  app.post("/api/v1/community/posts/:id/like", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const viewer = auth.viewer;
    const postId = Number(c.req.param("id"));

    const exists = await c.env.APP_DB.prepare("SELECT id, status FROM community_posts WHERE id = ?")
      .bind(postId)
      .first<{ id: number; status: string }>();
    if (!exists || (exists.status !== "visible" && viewer.role !== "admin")) {
      return c.json({ success: false, message: "Post not found." }, 404);
    }

    const already = await c.env.APP_DB.prepare("SELECT 1 FROM community_likes WHERE post_id = ? AND user_id = ?")
      .bind(postId, viewer.id)
      .first();

    let isLiked: boolean;
    if (already) {
      await c.env.APP_DB.prepare("DELETE FROM community_likes WHERE post_id = ? AND user_id = ?")
        .bind(postId, viewer.id)
        .run();
      isLiked = false;
    } else {
      await c.env.APP_DB.prepare("INSERT INTO community_likes (post_id, user_id, created_at) VALUES (?, ?, ?)")
        .bind(postId, viewer.id, utcNowIso())
        .run();
      isLiked = true;
    }

    const cntRow = await c.env.APP_DB.prepare("SELECT COUNT(*) AS c FROM community_likes WHERE post_id = ?")
      .bind(postId)
      .first<{ c: number }>();
    return c.json({ success: true, post_id: postId, is_liked: isLiked, likes_count: Number(cntRow?.c ?? 0) });
  });

  // Comments GET / POST
  app.get("/api/v1/community/posts/:id/comments", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const viewer = auth.viewer;
    const postId = Number(c.req.param("id"));

    const postRow = await c.env.APP_DB.prepare("SELECT id, status FROM community_posts WHERE id = ?")
      .bind(postId)
      .first<{ id: number; status: string }>();
    if (!postRow || (postRow.status !== "visible" && viewer.role !== "admin")) {
      return c.json({ success: false, message: "Post not found." }, 404);
    }

    const res = await c.env.APP_DB.prepare(
      `SELECT c.id, c.post_id, c.user_id, c.content, c.created_at,
              u.full_name AS author_name, u.role AS author_role
       FROM community_comments c
       JOIN users u ON u.id = c.user_id
       WHERE c.post_id = ? AND c.status = 'visible'
       ORDER BY c.id ASC`
    )
      .bind(postId)
      .all<Record<string, unknown>>();

    const isAdmin = viewer.role === "admin";
    const comments = res.results.map((r) => ({
      id: r.id,
      post_id: r.post_id,
      author_id: r.user_id,
      author_name: r.author_name,
      author_role: r.author_role,
      content: r.content,
      can_delete: isAdmin || Number(r.user_id) === Number(viewer.id),
      created_at: r.created_at,
    }));
    return c.json({ success: true, count: comments.length, comments });
  });

  app.post("/api/v1/community/posts/:id/comments", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const viewer = auth.viewer;
    const postId = Number(c.req.param("id"));

    const postRow = await c.env.APP_DB.prepare("SELECT id, status FROM community_posts WHERE id = ?")
      .bind(postId)
      .first<{ id: number; status: string }>();
    if (!postRow || (postRow.status !== "visible" && viewer.role !== "admin")) {
      return c.json({ success: false, message: "Post not found." }, 404);
    }

    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const content = String(body.content || "").trim();
    if (!content) return c.json({ success: false, message: "Comment content cannot be empty." }, 400);

    const now = utcNowIso();
    const ins = await c.env.APP_DB.prepare(
      "INSERT INTO community_comments (post_id, user_id, content, status, created_at) VALUES (?, ?, ?, 'visible', ?)"
    )
      .bind(postId, viewer.id, content.slice(0, 1000), now)
      .run();

    return c.json(
      {
        success: true,
        comment: {
          id: Number(ins.meta.last_row_id),
          post_id: postId,
          author_id: viewer.id,
          author_name: viewer.full_name,
          author_role: viewer.role,
          content: content.slice(0, 1000),
          can_delete: true,
          created_at: now,
        },
      },
      201
    );
  });

  // Delete post / comment
  app.post("/api/v1/community/posts/:id/delete", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const viewer = auth.viewer;
    const postId = Number(c.req.param("id"));

    const row = await c.env.APP_DB.prepare("SELECT id, user_id FROM community_posts WHERE id = ?")
      .bind(postId)
      .first<{ id: number; user_id: number }>();
    if (!row) return c.json({ success: false, message: "Post not found." }, 404);
    if (viewer.role !== "admin" && Number(row.user_id) !== Number(viewer.id)) {
      return c.json({ success: false, message: "Not allowed to delete this post." }, 403);
    }
    await c.env.APP_DB.prepare("DELETE FROM community_posts WHERE id = ?").bind(postId).run();
    return c.json({ success: true, deleted_post_id: postId });
  });

  app.post("/api/v1/community/comments/:id/delete", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const viewer = auth.viewer;
    const cmId = Number(c.req.param("id"));

    const row = await c.env.APP_DB.prepare("SELECT id, user_id FROM community_comments WHERE id = ?")
      .bind(cmId)
      .first<{ id: number; user_id: number }>();
    if (!row) return c.json({ success: false, message: "Comment not found." }, 404);
    if (viewer.role !== "admin" && Number(row.user_id) !== Number(viewer.id)) {
      return c.json({ success: false, message: "Not allowed to delete this comment." }, 403);
    }
    await c.env.APP_DB.prepare("DELETE FROM community_comments WHERE id = ?").bind(cmId).run();
    return c.json({ success: true, deleted_comment_id: cmId });
  });

  // Report content
  app.post("/api/v1/community/reports", async (c) => {
    const auth = await authenticateViewer(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const viewer = auth.viewer;

    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const postId = body.post_id ? Number(body.post_id) : null;
    const commentId = body.comment_id ? Number(body.comment_id) : null;
    const reason = String(body.reason || "").trim();
    if ((!postId && !commentId) || !reason) {
      return c.json({ success: false, message: "Target post/comment and reason are required." }, 400);
    }

    const ins = await c.env.APP_DB.prepare(
      "INSERT INTO community_reports (post_id, comment_id, reporter_id, reason, status, created_at) VALUES (?, ?, ?, ?, 'pending', ?)"
    )
      .bind(postId, commentId, viewer.id, reason.slice(0, 500), utcNowIso())
      .run();
    return c.json({ success: true, report_id: Number(ins.meta.last_row_id) }, 201);
  });

  // ===========================================================================
  // ADMIN ROUTES (Strictly server-side role === 'admin')
  // ===========================================================================
  app.get("/api/v1/admin/overview", async (c) => {
    const auth = await requireAdmin(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const [tu, au, bu, vp, hp, pr] = await Promise.all([
      c.env.APP_DB.prepare("SELECT COUNT(*) AS c FROM users").first<{ c: number }>(),
      c.env.APP_DB.prepare("SELECT COUNT(*) AS c FROM users WHERE role = 'admin'").first<{ c: number }>(),
      c.env.APP_DB.prepare("SELECT COUNT(*) AS c FROM users WHERE is_banned = 1").first<{ c: number }>(),
      c.env.APP_DB.prepare("SELECT COUNT(*) AS c FROM community_posts WHERE status = 'visible'").first<{ c: number }>(),
      c.env.APP_DB.prepare("SELECT COUNT(*) AS c FROM community_posts WHERE status = 'hidden'").first<{ c: number }>(),
      c.env.APP_DB.prepare("SELECT COUNT(*) AS c FROM community_reports WHERE status = 'pending'").first<{ c: number }>(),
    ]);

    return c.json({
      success: true,
      stats: {
        total_users: Number(tu?.c ?? 0),
        admin_users: Number(au?.c ?? 0),
        banned_users: Number(bu?.c ?? 0),
        visible_posts: Number(vp?.c ?? 0),
        hidden_posts: Number(hp?.c ?? 0),
        pending_reports: Number(pr?.c ?? 0),
      },
    });
  });

  app.post("/api/v1/admin/posts/:id/moderate", async (c) => {
    const auth = await requireAdmin(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const postId = Number(c.req.param("id"));
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const action = String(body.action || "").trim().toLowerCase();
    const reason = String(body.reason || "").trim().slice(0, 300);

    const exists = await c.env.APP_DB.prepare("SELECT id FROM community_posts WHERE id = ?").bind(postId).first();
    if (!exists) return c.json({ success: false, message: "Post not found." }, 404);

    if (action === "delete") {
      await c.env.APP_DB.prepare("DELETE FROM community_posts WHERE id = ?").bind(postId).run();
      return c.json({ success: true, action: "delete", post_id: postId });
    }
    if (action === "hide" || action === "unhide") {
      const newStatus = action === "hide" ? "hidden" : "visible";
      await c.env.APP_DB.prepare(
        "UPDATE community_posts SET status = ?, hidden_reason = ?, hidden_by = ?, updated_at = ? WHERE id = ?"
      )
        .bind(newStatus, action === "hide" ? reason : "", action === "hide" ? auth.viewer.id : null, utcNowIso(), postId)
        .run();
      return c.json({ success: true, action, post: await fetchPostById(c.env.APP_DB, postId, auth.viewer) });
    }
    return c.json({ success: false, message: "Invalid moderation action." }, 400);
  });

  app.get("/api/v1/admin/reports", async (c) => {
    const auth = await requireAdmin(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);

    const stFilter = (c.req.query("status") || "pending").trim().toLowerCase();
    const validFilter = ["pending", "resolved", "dismissed"].includes(stFilter);
    const whereSql = validFilter ? "WHERE r.status = ?" : "";
    const stmt = c.env.APP_DB.prepare(
      `SELECT r.*, u.full_name AS reporter_name, u.email AS reporter_email,
              p.product_name AS post_product_name, p.status AS post_status,
              pu.full_name AS post_author_name
       FROM community_reports r
       JOIN users u ON u.id = r.reporter_id
       LEFT JOIN community_posts p ON p.id = r.post_id
       LEFT JOIN users pu ON pu.id = p.user_id
       ${whereSql}
       ORDER BY r.id DESC
       LIMIT 100`
    );
    const res = validFilter ? await stmt.bind(stFilter).all() : await stmt.all();
    return c.json({ success: true, count: res.results.length, reports: res.results });
  });

  app.post("/api/v1/admin/reports/:id/resolve", async (c) => {
    const auth = await requireAdmin(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const repId = Number(c.req.param("id"));
    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const action = String(body.action || "dismiss").trim().toLowerCase();
    const note = String(body.note || "").trim().slice(0, 300);

    const rep = await c.env.APP_DB.prepare("SELECT * FROM community_reports WHERE id = ?")
      .bind(repId)
      .first<{ id: number; post_id: number | null; reason: string }>();
    if (!rep) return c.json({ success: false, message: "Report not found." }, 404);

    const now = utcNowIso();
    const finalStatus = action === "dismiss" ? "dismissed" : "resolved";
    if (action === "hide_post" && rep.post_id) {
      await c.env.APP_DB.prepare(
        "UPDATE community_posts SET status = 'hidden', hidden_reason = ?, hidden_by = ?, updated_at = ? WHERE id = ?"
      )
        .bind(note || rep.reason, auth.viewer.id, now, rep.post_id)
        .run();
    } else if (action === "delete_post" && rep.post_id) {
      await c.env.APP_DB.prepare("DELETE FROM community_posts WHERE id = ?").bind(rep.post_id).run();
    }

    await c.env.APP_DB.prepare(
      "UPDATE community_reports SET status = ?, resolved_by = ?, resolved_note = ?, resolved_at = ? WHERE id = ?"
    )
      .bind(finalStatus, auth.viewer.id, note, now, repId)
      .run();
    return c.json({ success: true, report_id: repId, status: finalStatus });
  });

  app.get("/api/v1/admin/users", async (c) => {
    const auth = await requireAdmin(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const res = await c.env.APP_DB.prepare(
      "SELECT id, full_name, email, role, is_verified, is_banned, created_at FROM users ORDER BY id ASC"
    ).all();
    return c.json({ success: true, users: res.results });
  });

  app.post("/api/v1/admin/users/:id/update", async (c) => {
    const auth = await requireAdmin(c.req.raw, c.env.APP_DB);
    if (!auth.viewer) return c.json(auth.errorBody!, auth.errorStatus!);
    const targetId = Number(c.req.param("id"));

    const target = await c.env.APP_DB.prepare("SELECT id, full_name, email, role, is_verified, is_banned FROM users WHERE id = ?")
      .bind(targetId)
      .first();
    if (!target) return c.json({ success: false, message: "User not found." }, 404);

    const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
    const newRole = body.role;
    const newBanned = body.is_banned;

    if (targetId === Number(auth.viewer.id)) {
      if ((newBanned !== undefined && Boolean(newBanned)) || (newRole !== undefined && String(newRole).trim().toLowerCase() !== "admin")) {
        return c.json({ success: false, message: "Administrators cannot ban or demote their own account." }, 400);
      }
    }

    if (newRole !== undefined) {
      const roleClean = String(newRole).trim().toLowerCase();
      if (roleClean !== "user" && roleClean !== "admin") {
        return c.json({ success: false, message: "Role must be 'user' or 'admin'." }, 400);
      }
      await c.env.APP_DB.prepare("UPDATE users SET role = ? WHERE id = ?").bind(roleClean, targetId).run();
    }

    if (newBanned !== undefined) {
      const banVal = Boolean(newBanned) ? 1 : 0;
      await c.env.APP_DB.prepare("UPDATE users SET is_banned = ? WHERE id = ?").bind(banVal, targetId).run();
      if (banVal === 1) {
        await c.env.APP_DB.prepare("DELETE FROM user_sessions WHERE user_id = ?").bind(targetId).run();
      }
    }

    const updated = await c.env.APP_DB.prepare(
      "SELECT id, full_name, email, role, is_verified, is_banned, created_at FROM users WHERE id = ?"
    )
      .bind(targetId)
      .first();
    return c.json({ success: true, user: updated });
  });
}

