import { createServer } from "node:http";
import { createHmac, timingSafeEqual } from "node:crypto";

const port = Number(process.env.PORT ?? 4101);
const secret = process.env.WEBHOOK_SECRET ?? "fixture-secret";
const sourceSystem = process.env.SOURCE_SYSTEM ?? "fixture";
const events = [];
const seen = new Set();

function json(res, status, payload) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(payload));
}

function validSignature(timestamp, body, supplied) {
  if (!timestamp || !supplied) return false;
  const expected = Buffer.from(createHmac("sha256", secret).update(timestamp + "." + body).digest("hex"));
  const actual = Buffer.from(String(supplied));
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

createServer(async (req, res) => {
  const url = new URL(req.url, "http://fixture.local");
  if (req.method === "GET" && url.pathname === "/health") {
    return json(res, 200, { status: "ok", source_system: sourceSystem });
  }
  if (req.method === "GET" && url.pathname === "/events") {
    return json(res, 200, { source_system: sourceSystem, events });
  }
  if (req.method === "POST") {
    let raw = "";
    for await (const chunk of req) raw += chunk;
    const eventId = String(req.headers["x-orbitas-event-id"] ?? "");
    const timestamp = String(req.headers["x-orbitas-timestamp"] ?? "");
    const supplied = String(req.headers["x-orbitas-signature"] ?? "");
    const now = Math.floor(Date.now() / 1000);
    if (!eventId || !timestamp || Math.abs(now - Number(timestamp)) > 300) {
      return json(res, 401, { error: "stale_or_missing_event_headers" });
    }
    if (!validSignature(timestamp, raw, supplied)) {
      return json(res, 401, { error: "invalid_signature" });
    }
    if (seen.has(eventId)) return json(res, 200, { duplicate: true });
    seen.add(eventId);
    const payload = JSON.parse(raw);
    events.push(payload);
    return json(res, 200, { accepted: true, event_id: eventId });
  }
  return json(res, 404, { error: "not_found" });
}).listen(port, "0.0.0.0", () => {
  console.log(`${sourceSystem} fixture webhook listening on ${port}`);
});
