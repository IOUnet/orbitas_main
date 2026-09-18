import { createServer } from "node:http";
import { timingSafeEqual, randomUUID } from "node:crypto";
import { GatewayDb } from "./db.mjs";
import { OrbitasProtocol } from "./protocol.mjs";
import { WebhookDispatcher } from "./webhooks.mjs";
import { GatewayError, bigintJson, hashText } from "./utils.mjs";

const config = {
  port: Number(process.env.PORT ?? 3100),
  apiToken: process.env.ORBITAS_API_TOKEN ?? "orbitas-local-token",
  databaseUrl: process.env.DATABASE_URL ?? "postgresql://graph-node:let-me-in@127.0.0.1:5432/graph-node",
  rpcUrl: process.env.RPC_URL ?? "http://127.0.0.1:8545",
  graphqlEndpoint: process.env.GRAPHQL_ENDPOINT ?? "http://127.0.0.1:8000/subgraphs/name/orbitas/local",
  chainId: Number(process.env.CHAIN_ID ?? 31337),
  passportAddress: process.env.PASSPORT_ADDRESS,
  obligationAddress: process.env.OBLIGATION_ADDRESS,
  multilateralAddress: process.env.MULTILATERAL_ADDRESS,
  relayerPrivateKey: process.env.RELAYER_PRIVATE_KEY
};

for (const key of ["passportAddress", "obligationAddress", "multilateralAddress", "relayerPrivateKey"]) {
  if (!config[key]) throw new Error(`Missing required environment variable for ${key}`);
}

const db = new GatewayDb(config.databaseUrl);
await db.init();
const protocol = new OrbitasProtocol(config);
const webhooks = new WebhookDispatcher(db);

function json(res, status, payload, headers = {}) {
  const body = JSON.stringify(bigintJson(payload));
  res.writeHead(status, { "content-type": "application/json; charset=utf-8", ...headers });
  res.end(body);
}

async function readJson(req) {
  let body = "";
  for await (const chunk of req) {
    body += chunk;
    if (body.length > 1_000_000) throw new GatewayError("PAYLOAD_TOO_LARGE", "request body exceeds 1 MB", 413);
  }
  if (!body) return {};
  try {
    return JSON.parse(body);
  } catch {
    throw new GatewayError("INVALID_JSON", "request body must be valid JSON", 400);
  }
}

function requireAuth(req) {
  const expected = Buffer.from(`Bearer ${config.apiToken}`);
  const actual = Buffer.from(String(req.headers.authorization ?? ""));
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) {
    throw new GatewayError("UNAUTHORIZED", "missing or invalid bearer token", 401);
  }
}

async function idempotent(req, operation, handler) {
  const key = String(req.headers["idempotency-key"] ?? "").trim();
  if (!key) throw new GatewayError("IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key header is required", 400);
  const cached = await db.getIdempotency(key);
  if (cached) {
    if (cached.operation !== operation) {
      throw new GatewayError("IDEMPOTENCY_KEY_REUSED", "Idempotency-Key was already used for another operation", 409);
    }
    return { status: cached.status_code, body: cached.response, replayed: true };
  }
  const result = await handler();
  await db.putIdempotency(key, operation, result.status, result.body);
  return { ...result, replayed: false };
}

function proposalParticipants(proposal) {
  return [
    proposal.path.payer_passport_id,
    proposal.path.intermediary_passport_id,
    proposal.path.receiver_passport_id
  ];
}

async function handle(req, res) {
  const url = new URL(req.url, "http://gateway.local");
  if (req.method === "GET" && url.pathname === "/health") {
    return json(res, 200, { status: "ok", service: "orbitas-gateway", version: "v1" });
  }

  if (req.method === "GET" && url.pathname === "/v1/openapi") {
    return json(res, 200, { openapi: "/gateway/openapi.yaml", version: "1.0.0" });
  }

  const passportMatch = url.pathname.match(/^\/v1\/passports\/(\d+)$/);
  if (req.method === "GET" && passportMatch) {
    return json(res, 200, await protocol.getPassport(passportMatch[1]));
  }

  const obligationMatch = url.pathname.match(/^\/v1\/obligations\/(\d+)$/);
  if (req.method === "GET" && obligationMatch) {
    return json(res, 200, await protocol.getObligation(obligationMatch[1]));
  }

  if (req.method === "GET" && url.pathname === "/v1/obligations") {
    const participantId = url.searchParams.get("passport_id");
    const direction = url.searchParams.get("direction");
    if (!participantId || !direction) throw new GatewayError("MISSING_QUERY", "passport_id and direction are required", 400);
    return json(res, 200, await protocol.listIndexedObligations(participantId, direction));
  }

  const proposalMatch = url.pathname.match(/^\/v1\/proposals\/(0x[0-9a-fA-F]{64})$/);
  if (req.method === "GET" && proposalMatch) {
    const proposal = await db.getProposal(proposalMatch[1]);
    if (!proposal) throw new GatewayError("NOT_FOUND", "proposal not found", 404);
    const approvals = await db.listApprovals(proposal.id);
    return json(res, 200, { ...proposal, approvals });
  }

  const settlementMatch = url.pathname.match(/^\/v1\/settlements\/(0x[0-9a-fA-F]{64})$/);
  if (req.method === "GET" && settlementMatch) {
    return json(res, 200, await protocol.getSettlement(settlementMatch[1]));
  }

  if (req.method !== "POST") throw new GatewayError("NOT_FOUND", "route not found", 404);
  requireAuth(req);
  const body = await readJson(req);

  if (url.pathname === "/v1/passports/prepare") {
    return json(res, 200, protocol.preparePassport(body));
  }

  if (url.pathname === "/v1/passports/link") {
    const result = await idempotent(req, "passport.link", async () => {
      const passport = await protocol.getPassport(body.passport_id);
      if (Number(passport.status) !== 1) throw new GatewayError("PASSPORT_NOT_ACTIVE", "passport is not active", 409);
      const source = body.source ?? {};
      for (const field of ["system", "instance_id", "company_id"]) {
        if (source[field] === undefined || source[field] === "") throw new GatewayError("INVALID_SOURCE", `source.${field} is required`, 400);
      }
      const link = await db.linkParticipant(source, body.passport_id);
      return { status: 200, body: { passport, link } };
    });
    return json(res, result.status, { ...result.body, idempotency_replayed: result.replayed });
  }

  if (url.pathname === "/v1/obligations") {
    const result = await idempotent(req, "obligation.publish", async () => {
      const published = await protocol.issueObligation(body);
      return { status: published.reused ? 200 : 201, body: published };
    });
    return json(res, result.status, { ...result.body, idempotency_replayed: result.replayed });
  }

  if (url.pathname === "/v1/clearing/discover") {
    const result = await idempotent(req, "clearing.discover", async () => {
      const proposal = await protocol.discoverPath(body);
      await db.saveProposal(proposal);
      await webhooks.emit("clearing.proposal.upsert", proposalParticipants(proposal), proposal);
      return { status: 201, body: proposal };
    });
    return json(res, result.status, { ...result.body, idempotency_replayed: result.replayed });
  }

  const approveMatch = url.pathname.match(/^\/v1\/proposals\/(0x[0-9a-fA-F]{64})\/approve$/);
  if (approveMatch) {
    const proposal = await db.getProposal(approveMatch[1]);
    if (!proposal) throw new GatewayError("NOT_FOUND", "proposal not found", 404);
    if (!proposal.required_approvals.includes(String(body.passport_id))) {
      throw new GatewayError("NOT_REQUIRED_PARTICIPANT", "passport is not a required approver for this proposal", 409);
    }
    const signer = await protocol.verifyConsent(body.passport_id, proposal.path_digest, body.signature);
    await db.saveApproval(proposal.id, body.passport_id, body.signature, signer);
    const approvals = await db.listApprovals(proposal.id);
    const approvedSet = new Set(approvals.map((a) => String(a.passport_id)));
    const complete = proposal.required_approvals.every((id) => approvedSet.has(String(id)));
    if (complete) await db.setProposalState(proposal.id, "APPROVED");
    return json(res, 200, { proposal_id: proposal.id, state: complete ? "APPROVED" : "AWAITING_APPROVALS", signer, approvals });
  }

  const rejectMatch = url.pathname.match(/^\/v1\/proposals\/(0x[0-9a-fA-F]{64})\/reject$/);
  if (rejectMatch) {
    const proposal = await db.getProposal(rejectMatch[1]);
    if (!proposal) throw new GatewayError("NOT_FOUND", "proposal not found", 404);
    if (!proposal.required_approvals.includes(String(body.passport_id))) {
      throw new GatewayError("NOT_REQUIRED_PARTICIPANT", "passport is not a participant in this proposal", 409);
    }
    await db.setProposalState(proposal.id, "REJECTED");
    return json(res, 200, { proposal_id: proposal.id, state: "REJECTED" });
  }

  const executeMatch = url.pathname.match(/^\/v1\/proposals\/(0x[0-9a-fA-F]{64})\/execute$/);
  if (executeMatch) {
    const result = await idempotent(req, "proposal.execute", async () => {
      const proposal = await db.getProposal(executeMatch[1]);
      if (!proposal) throw new GatewayError("NOT_FOUND", "proposal not found", 404);
      if (proposal.state !== "APPROVED") throw new GatewayError("PROPOSAL_NOT_APPROVED", "proposal requires all approvals", 409);
      const approvals = await db.listApprovals(proposal.id);
      const settlement = await protocol.executeProposal(proposal, approvals);
      await db.saveSettlement(settlement);
      await db.setProposalState(proposal.id, "EXECUTED");
      await webhooks.emit("settlement.instruction.upsert", proposalParticipants(proposal), settlement);
      return { status: 201, body: settlement };
    });
    return json(res, result.status, { ...result.body, idempotency_replayed: result.replayed });
  }

  const prepareConfirmationMatch = url.pathname.match(/^\/v1\/settlements\/(0x[0-9a-fA-F]{64})\/prepare-confirmation$/);
  if (prepareConfirmationMatch) {
    return json(res, 200, await protocol.prepareConfirmation(prepareConfirmationMatch[1], body));
  }

  const confirmMatch = url.pathname.match(/^\/v1\/settlements\/(0x[0-9a-fA-F]{64})\/confirm$/);
  if (confirmMatch) {
    const result = await idempotent(req, "settlement.confirm", async () => {
      const confirmed = await protocol.confirmSettlement(confirmMatch[1], body);
      const stored = await db.getSettlement(confirmMatch[1]);
      const settlement = { ...(stored ?? { id: confirmMatch[1], proposal_id: body.proposal_id ?? "unknown" }), ...confirmed, state: "SETTLED" };
      await db.saveSettlement(settlement);
      const chainState = await protocol.getSettlement(confirmMatch[1]);
      const participants = [chainState.payer_passport_id, chainState.intermediary_passport_id, chainState.receiver_passport_id];
      await webhooks.emit("settlement.settled", participants, { ...settlement, chain_state: chainState });
      return { status: 200, body: { ...settlement, chain_state: chainState } };
    });
    return json(res, result.status, { ...result.body, idempotency_replayed: result.replayed });
  }

  if (url.pathname === "/v1/webhooks/subscriptions") {
    const result = await idempotent(req, "webhook.subscription.create", async () => {
      if (!body.source_system || !body.participant_id || !body.callback_url || !body.secret) {
        throw new GatewayError("INVALID_SUBSCRIPTION", "source_system, participant_id, callback_url and secret are required", 400);
      }
      const id = body.id ?? hashText(`${body.source_system}|${body.participant_id}|${body.callback_url}`);
      const subscription = await db.addWebhookSubscription({ id, ...body });
      return { status: 201, body: subscription };
    });
    return json(res, result.status, { ...result.body, idempotency_replayed: result.replayed });
  }

  throw new GatewayError("NOT_FOUND", "route not found", 404);
}

const server = createServer(async (req, res) => {
  try {
    await handle(req, res);
  } catch (error) {
    const known = error instanceof GatewayError;
    const status = known ? error.status : 500;
    const payload = {
      error: {
        code: known ? error.code : "INTERNAL_ERROR",
        message: known ? error.message : "internal gateway error",
        ...(known && error.details ? { details: error.details } : {}),
        request_id: String(req.headers["x-request-id"] ?? randomUUID())
      }
    };
    if (!known) console.error(error);
    json(res, status, payload);
  }
});

server.listen(config.port, "0.0.0.0", () => {
  console.log(`Orbitas Gateway v1 listening on 0.0.0.0:${config.port}`);
});

async function shutdown() {
  server.close();
  await db.close();
  process.exit(0);
}
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
