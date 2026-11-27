export interface WorkersAiBinding {
  run(model: string, input: Record<string, unknown>): Promise<unknown>;
}

export interface Env {
  APP_DB: D1Database;
  FOODON_DB: D1Database;
  AI?: WorkersAiBinding;
  PUBLIC_BASE_URL?: string;
  AUTO_VERIFY_EMAIL?: string;
  PADDLEOCR_VL_TOKEN?: string;
  RESEND_API_KEY?: string;
  BREVO_API_KEY?: string;
  EMAIL_FROM?: string;
}

export interface UserRow {
  id: number;
  full_name: string;
  email: string;
  password_hash: string;
  salt: string;
  is_verified: number;
  verification_token: string | null;
  reset_token: string | null;
  role: string;
  is_banned: number;
  created_at: string;
}

export interface ViewerUser {
  id: number;
  full_name: string;
  email: string;
  is_verified: number;
  role: string;
  is_banned: number;
}

export interface FoodOnConceptRow {
  curie: string;
  label_en: string;
  label_low: string;
  parent_curie: string;
  parent_label_en: string;
  definition_en: string;
  food_type: string;
  allergen_codes: string;
  chronic_codes: string;
  ecodes: string;
  child_count: number;
  has_tags: number;
}

