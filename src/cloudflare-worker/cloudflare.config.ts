export default {
  name: "nutriviet",
  main: "src/index.ts",
  compatibilityDate: "2026-11-22",
  observability: {
    enabled: true,
    traces: {
      enabled: true,
    },
  },
  placement: {
    mode: "smart",
  },
  d1Databases: [
    {
      binding: "APP_DB",
      databaseName: "nutriviet-app",
      databaseId: "dcdf8df6-7f4e-4efc-8e9c-0b94bdaf5894",
    },
    {
      binding: "FOODON_DB",
      databaseName: "nutriviet-foodon",
      databaseId: "357c1fdd-c26c-4771-a120-70e98bb24c74",
    },
  ],
  ai: {
    binding: "AI",
  },
  vars: {
    PUBLIC_BASE_URL: "https://nutriviet.nutriviet-api.workers.dev",
    AUTO_VERIFY_EMAIL: "false",
    EMAIL_FROM: "NutriViet <trienchill@mondk.com>",
  },
};

