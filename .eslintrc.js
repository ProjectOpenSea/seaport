module.exports = {
  env: {
    browser: false,
    es2021: true,
    mocha: true,
    node: true,
  },
  plugins: ["@typescript-eslint", "import"],
  extends: [
    "standard",
    "plugin:prettier/recommended",
    "eslint:recommended",
    "plugin:import/recommended",
    "plugin:import/typescript",
  ],
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: 12,
    project: "./tsconfig.json",
  },
  rules: {
    "@typescript-eslint/consistent-type-imports": "error",
    "@typescript-eslint/prefer-nullish-coalescing": "error",
    camelcase: ["error", { allow: ["(.*)__factory"] }],
    "import/order": [
      "error",
      {
        alphabetize: {
          order: "asc",
        },
        groups: [
          "object",
          ["builtin", "external"],
          "parent",
          "sibling",
          "index",
          "type",
        ],
        "newlines-between": "always",
      },
    ],
    "object-shorthand": "error",
    "prefer-const": "error",
    "sort-imports": ["error", { ignoreDeclarationSort: true }],
  },
  overrides: [
    {
      files: ["test/**/*.spec.ts"],
      rules: {
        "no-unused-expressions": "off",
      },
    },
  ],
};
