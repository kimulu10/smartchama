const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const { createApp } = require("../app");

function createQueryResult({ empty = true, docs = [] } = {}) {
  return { empty, docs, size: docs.length };
}

function createMockDb({ memberExists = false, transaction = null } = {}) {
  const membersQuery = {
    where() {
      return this;
    },
    limit() {
      return this;
    },
    async get() {
      return createQueryResult({ empty: !memberExists });
    },
  };

  const transactionQuery = {
    where() {
      return this;
    },
    limit() {
      return this;
    },
    async get() {
      if (!transaction) {
        return createQueryResult({ empty: true });
      }
      return createQueryResult({
        empty: false,
        docs: [
          {
            id: "tx-1",
            data: () => transaction,
            ref: { update: async () => {} },
          },
        ],
      });
    },
  };

  return {
    collection(name) {
      if (name === "mpesa_transactions") {
        return transactionQuery;
      }

      return {
        doc() {
          return {
            collection() {
              return {
                doc() {
                  return {
                    collection(subName) {
                      if (subName === "members") {
                        return membersQuery;
                      }
                      return membersQuery;
                    },
                    set: async () => {},
                  };
                },
                set: async () => {},
              };
            },
            set: async () => {},
          };
        },
        where() {
          return transactionQuery;
        },
        add: async () => ({ id: "generated-id" }),
      };
    },
  };
}

function createMockAdmin({ uid = "user-1", validToken = "valid-token" } = {}) {
  return {
    auth: () => ({
      verifyIdToken: async (token) => {
        if (token !== validToken) {
          throw new Error("invalid token");
        }
        return { uid };
      },
    }),
  };
}

function createTestApp(overrides = {}) {
  return createApp({
    db: overrides.db || createMockDb(),
    admin: overrides.admin || createMockAdmin(),
    getAccessToken: overrides.getAccessToken || (async () => "mpesa-token"),
    consumerKey: "key",
    consumerSecret: "secret",
    shortCode: "174379",
    passKey: "pass",
    callbackURL: "https://example.com/callback",
    mpesaBaseUrl: "https://sandbox.safaricom.co.ke",
    mpesaEnv: "sandbox",
  });
}

async function sendRequest(app, method, path, { headers = {}, body } = {}) {
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const { port } = server.address();

  try {
    const payload = body ? JSON.stringify(body) : undefined;
    const response = await fetch(`http://127.0.0.1:${port}${path}`, {
      method,
      headers: {
        ...(payload ? { "Content-Type": "application/json" } : {}),
        ...headers,
      },
      body: payload,
    });

    const text = await response.text();
    return {
      status: response.status,
      body: text ? JSON.parse(text) : {},
    };
  } finally {
    await new Promise((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
  }
}

test("GET /health returns minimal payload", async () => {
  const app = createTestApp();
  const response = await sendRequest(app, "GET", "/health");

  assert.equal(response.status, 200);
  assert.equal(response.body.ok, true);
  assert.equal(response.body.env, "sandbox");
  assert.equal(response.body.callbackURL, undefined);
  assert.equal(response.body.shortCode, undefined);
});

test("POST /stkpush rejects missing auth token", async () => {
  const app = createTestApp();
  const response = await sendRequest(app, "POST", "/stkpush", {
    body: {
      phone: "254712345678",
      amount: 100,
      userId: "user-1",
      organizationId: "org-1",
      chamaId: "chama-1",
      type: "contribution",
    },
  });

  assert.equal(response.status, 401);
  assert.equal(response.body.success, false);
});

test("POST /stkpush rejects mismatched userId", async () => {
  const app = createTestApp();
  const response = await sendRequest(app, "POST", "/stkpush", {
    headers: { Authorization: "Bearer valid-token" },
    body: {
      phone: "254712345678",
      amount: 100,
      userId: "someone-else",
      organizationId: "org-1",
      chamaId: "chama-1",
      type: "contribution",
    },
  });

  assert.equal(response.status, 403);
  assert.match(response.body.error, /userId must match/i);
});

test("POST /stkpush rejects non-members", async () => {
  const app = createTestApp({
    db: createMockDb({ memberExists: false }),
  });

  const response = await sendRequest(app, "POST", "/stkpush", {
    headers: { Authorization: "Bearer valid-token" },
    body: {
      phone: "254712345678",
      amount: 100,
      userId: "user-1",
      organizationId: "org-1",
      chamaId: "chama-1",
      type: "contribution",
    },
  });

  assert.equal(response.status, 403);
  assert.match(response.body.error, /not a member/i);
});

test("GET /transaction-status rejects missing auth token", async () => {
  const app = createTestApp();
  const response = await sendRequest(app, "GET", "/transaction-status/checkout-123");

  assert.equal(response.status, 401);
});

test("GET /transaction-status rejects foreign transactions", async () => {
  const app = createTestApp({
    db: createMockDb({
      transaction: {
        userId: "other-user",
        status: "pending",
      },
    }),
  });

  const response = await sendRequest(app, "GET", "/transaction-status/checkout-123", {
    headers: { Authorization: "Bearer valid-token" },
  });

  assert.equal(response.status, 403);
});

test("POST /callback accepts Safaricom webhook without auth", async () => {
  const app = createTestApp();
  const response = await sendRequest(app, "POST", "/callback", {
    body: { Body: { stkCallback: null } },
  });

  assert.equal(response.status, 200);
  assert.equal(response.body.ResultCode, 0);
});
