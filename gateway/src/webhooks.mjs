import { createHmac, randomUUID } from "node:crypto";

function signature(secret, timestamp, body) {
  return createHmac("sha256", secret).update(timestamp + "." + body).digest("hex");
}

export class WebhookDispatcher {
  constructor(db) {
    this.db = db;
  }

  async emit(eventType, participantIds, data) {
    const subscriptions = await this.db.getWebhookSubscriptions(participantIds);
    const results = [];
    for (const sub of subscriptions) {
      const eventId = randomUUID();
      const payload = {
        id: eventId,
        type: eventType,
        occurred_at: new Date().toISOString(),
        participant_id: String(sub.participant_id),
        data
      };
      const body = JSON.stringify(payload);
      const timestamp = String(Math.floor(Date.now() / 1000));
      let status = "failed";
      let lastError = null;
      let deliveredAt = null;
      try {
        const response = await fetch(sub.callback_url, {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-orbitas-event-id": eventId,
            "x-orbitas-timestamp": timestamp,
            "x-orbitas-signature": signature(sub.secret, timestamp, body)
          },
          body,
          signal: AbortSignal.timeout(5000)
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        status = "delivered";
        deliveredAt = new Date();
      } catch (error) {
        lastError = error instanceof Error ? error.message : String(error);
      }
      await this.db.saveOutboundEvent({
        event_id: eventId,
        event_type: eventType,
        participant_id: sub.participant_id,
        subscription_id: sub.id,
        payload,
        status,
        attempts: 1,
        last_error: lastError,
        delivered_at: deliveredAt
      });
      results.push({ subscription_id: sub.id, event_id: eventId, status, error: lastError });
    }
    return results;
  }
}
