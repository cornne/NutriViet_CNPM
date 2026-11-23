import { Hono } from "hono";
import { cors } from "hono/cors";
import { registerAuthAndProfileRoutes } from "./auth_profile";
import { registerCommunityAndAdminRoutes } from "./community";
import { isEmailProviderConfigured } from "./email";
import { D1FoodOnEngine, splitRawIngredients } from "./foodon";
import { registerOcrRoutes } from "./ocr_proxy";
import type { Env } from "./types";

const app = new Hono<{ Bindings: Env }>();

// Global CORS (matches NutriViet Flutter Mobile + Web Explorer)
app.use(
  "*",
  cors({
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "X-Requested-With", "X-Auth-Token", "X-PaddleOCR-Token"],
  })
);

// Health & Root Info
app.get("/health", async (c) => {
  return c.json({
    status: "healthy",
    service: "NutriViet Cloudflare Workers API",
    runtime: "cloudflare-workers-d1",
    version: "2.0.0",
    foodon_hybrid: true,
    ocr_proxy: Boolean(c.env.PADDLEOCR_VL_TOKEN?.trim()),
    email_verification:
      isEmailProviderConfigured(c.env) &&
      String(c.env.AUTO_VERIFY_EMAIL || "").toLowerCase() !== "true",
  });
});

app.get("/", (c) => c.redirect("/foodon-graph"));

// Interactive FoodOn Graph Visualizer (served from D1 static_pages with Edge caching)
app.get("/foodon-graph", async (c) => {
  const row = await c.env.APP_DB.prepare("SELECT html FROM static_pages WHERE slug = 'foodon-graph'")
    .first<{ html: string }>();
  if (!row) return c.text("foodon-graph page not seeded", 404);
  return new Response(row.html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
});

// FoodOn Official Pure-English Ontology REST API
app.get("/api/v1/foodon/graph", async (c) => {
  const eng = new D1FoodOnEngine(c.env.FOODON_DB);
  const siblingsRaw = (c.req.query("siblings") || "1").trim().toLowerCase();
  const res = await eng.getGraphNeighborhood({
    curie: c.req.query("curie") || "",
    allergen: c.req.query("allergen") || "",
    ancestorHops: Number(c.req.query("ancestor_hops") || 10),
    childDepth: c.req.query("child_depth") !== undefined ? Number(c.req.query("child_depth")) : 2,
    maxChildren: Number(c.req.query("max_children") || 24),
    includeSiblings: !["0", "false", "no"].includes(siblingsRaw),
  });
  return c.json(res, res.success ? 200 : 404);
});

app.get("/api/v1/foodon/graph/expand", async (c) => {
  const eng = new D1FoodOnEngine(c.env.FOODON_DB);
  const res = await eng.expandGraphNode(
    c.req.query("curie") || "",
    Number(c.req.query("limit") || 24),
    Number(c.req.query("offset") || 0)
  );
  return c.json(res, res.success ? 200 : 404);
});

app.get("/api/v1/foodon/graph/path", async (c) => {
  const eng = new D1FoodOnEngine(c.env.FOODON_DB);
  const res = await eng.findOntologyPath(c.req.query("from") || "", c.req.query("to") || "");
  return c.json(res, res.success ? 200 : 404);
});

app.get("/api/v1/foodon/allergy-lookup", async (c) => {
  const eng = new D1FoodOnEngine(c.env.FOODON_DB);
  const res = await eng.searchAllergyFoods(c.req.query("q") || "", Number(c.req.query("limit") || 12));
  return c.json(res);
});

app.get("/api/v1/foodon/additives", async (c) => {
  const eng = new D1FoodOnEngine(c.env.FOODON_DB);
  const res = await eng.listAdditives(c.req.query("q") || "", Number(c.req.query("limit") || 60));
  return c.json(res);
});

app.get("/api/v1/foodon/category", async (c) => {
  const eng = new D1FoodOnEngine(c.env.FOODON_DB);
  const als = (c.req.query("allergens") || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const res = await eng.getCategoryConcepts(
    c.req.query("category") || "sugar",
    als,
    Number(c.req.query("limit") || 20)
  );
  return c.json(res);
});

app.get("/api/v1/foodon/search", async (c) => {
  const eng = new D1FoodOnEngine(c.env.FOODON_DB);
  const res = await eng.searchConcepts(
    c.req.query("q") || "",
    c.req.query("lang") || "all",
    c.req.query("allergen") || "",
    Number(c.req.query("limit") || 30)
  );
  return c.json(res);
});

app.post("/api/v1/foodon/evaluate", async (c) => {
  const eng = new D1FoodOnEngine(c.env.FOODON_DB);
  const body = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const rawText = String(body.raw_text || "").trim();
  let ingredients: string[] = [];
  if (Array.isArray(body.ingredients)) {
    ingredients = body.ingredients.map((x) => String(x || "").trim()).filter(Boolean);
  } else if (typeof body.ingredients === "string" && body.ingredients.trim()) {
    ingredients = splitRawIngredients(body.ingredients);
  } else if (rawText) {
    ingredients = splitRawIngredients(rawText);
  }

  const allergens = Array.isArray(body.allergens)
    ? (body.allergens as Array<string | Record<string, unknown>>)
    : [];
  const chronics = Array.isArray(body.chronics)
    ? body.chronics.map((x) => String(x || "").trim()).filter(Boolean)
    : [];

  const res = await eng.evaluatePackagingLabel(ingredients, allergens, chronics);
  return c.json(res);
});

// Register Auth, Profile, Scan History, Community, Admin RBAC, and PaddleOCR-VL-1.6 Proxy
registerAuthAndProfileRoutes(app);
registerCommunityAndAdminRoutes(app);
registerOcrRoutes(app);

app.notFound((c) => c.json({ error: "Endpoint Not Found", path: new URL(c.req.url).pathname }, 404));

app.onError((err, c) => {
  console.error(JSON.stringify({ level: "error", path: c.req.path, message: err.message }));
  return c.json({ success: false, message: `Server Error: ${err.message}` }, 500);
});

export default app;
