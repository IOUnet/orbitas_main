import pg from "pg";
const { Pool } = pg;

export class GatewayDb {
  constructor(connectionString) {
    this.pool = new Pool({ connectionString });
  }

  async init() {
    await this.pool.query(`
      CREATE SCHEMA IF NOT EXISTS orbitas_gateway;

      CREATE TABLE IF NOT EXISTS orbitas_gateway.participant_links (
        source_system text NOT NULL,
        source_instance_id text NOT NULL,
        source_company_id text NOT NULL,
        passport_id text NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (source_system, source_instance_id, source_company_id)
      );

      CREATE TABLE IF NOT EXISTS orbitas_gateway.idempotency (
        idempotency_key text PRIMARY KEY,
        operation text NOT NULL,
        status_code integer NOT NULL,
        response jsonb NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE IF NOT EXISTS orbitas_gateway.proposals (
        id text PRIMARY KEY,
        state text NOT NULL,
        data jsonb NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE IF NOT EXISTS orbitas_gateway.approvals (
        proposal_id text NOT NULL REFERENCES orbitas_gateway.proposals(id) ON DELETE CASCADE,
        passport_id text NOT NULL,
        signature text NOT NULL,
        signer text NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (proposal_id, passport_id)
      );

      CREATE TABLE IF NOT EXISTS orbitas_gateway.settlements (
        id text PRIMARY KEY,
        proposal_id text NOT NULL,
        state text NOT NULL,
        data jsonb NOT NULL,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE IF NOT EXISTS orbitas_gateway.webhook_subscriptions (
        id text PRIMARY KEY,
        source_system text NOT NULL,
        participant_id text NOT NULL,
        callback_url text NOT NULL,
        secret text NOT NULL,
        active boolean NOT NULL DEFAULT true,
        created_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE IF NOT EXISTS orbitas_gateway.outbound_events (
        event_id text PRIMARY KEY,
        event_type text NOT NULL,
        participant_id text NOT NULL,
        subscription_id text NOT NULL,
        payload jsonb NOT NULL,
        status text NOT NULL,
        attempts integer NOT NULL DEFAULT 0,
        last_error text,
        created_at timestamptz NOT NULL DEFAULT now(),
        delivered_at timestamptz
      );
    `);
  }

  async close() {
    await this.pool.end();
  }

  async getIdempotency(key) {
    const { rows } = await this.pool.query(
      "SELECT operation, status_code, response FROM orbitas_gateway.idempotency WHERE idempotency_key=$1",
      [key]
    );
    return rows[0] ?? null;
  }

  async putIdempotency(key, operation, statusCode, response) {
    await this.pool.query(
      `INSERT INTO orbitas_gateway.idempotency(idempotency_key, operation, status_code, response)
       VALUES ($1,$2,$3,$4::jsonb)
       ON CONFLICT (idempotency_key) DO NOTHING`,
      [key, operation, statusCode, JSON.stringify(response)]
    );
  }

  async linkParticipant(source, passportId) {
    const { rows } = await this.pool.query(
      `INSERT INTO orbitas_gateway.participant_links(source_system, source_instance_id, source_company_id, passport_id)
       VALUES ($1,$2,$3,$4)
       ON CONFLICT (source_system, source_instance_id, source_company_id)
       DO UPDATE SET passport_id=EXCLUDED.passport_id
       RETURNING *`,
      [source.system, source.instance_id, String(source.company_id), String(passportId)]
    );
    return rows[0];
  }

  async saveProposal(proposal) {
    await this.pool.query(
      `INSERT INTO orbitas_gateway.proposals(id,state,data)
       VALUES ($1,$2,$3::jsonb)
       ON CONFLICT (id) DO UPDATE SET state=EXCLUDED.state,data=EXCLUDED.data,updated_at=now()`,
      [proposal.id, proposal.state, JSON.stringify(proposal)]
    );
  }

  async getProposal(id) {
    const { rows } = await this.pool.query(
      "SELECT state,data FROM orbitas_gateway.proposals WHERE id=$1",
      [id]
    );
    if (!rows[0]) return null;
    return { ...rows[0].data, state: rows[0].state };
  }

  async setProposalState(id, state) {
    const { rows } = await this.pool.query(
      "UPDATE orbitas_gateway.proposals SET state=$2, updated_at=now() WHERE id=$1 RETURNING data",
      [id, state]
    );
    if (!rows[0]) return null;
    const data = { ...rows[0].data, state };
    await this.pool.query(
      "UPDATE orbitas_gateway.proposals SET data=$2::jsonb WHERE id=$1",
      [id, JSON.stringify(data)]
    );
    return data;
  }

  async saveApproval(proposalId, passportId, signature, signer) {
    await this.pool.query(
      `INSERT INTO orbitas_gateway.approvals(proposal_id,passport_id,signature,signer)
       VALUES ($1,$2,$3,$4)
       ON CONFLICT (proposal_id,passport_id)
       DO UPDATE SET signature=EXCLUDED.signature, signer=EXCLUDED.signer`,
      [proposalId, String(passportId), signature, signer]
    );
  }

  async listApprovals(proposalId) {
    const { rows } = await this.pool.query(
      "SELECT passport_id,signature,signer FROM orbitas_gateway.approvals WHERE proposal_id=$1 ORDER BY passport_id",
      [proposalId]
    );
    return rows;
  }

  async saveSettlement(settlement) {
    await this.pool.query(
      `INSERT INTO orbitas_gateway.settlements(id,proposal_id,state,data)
       VALUES ($1,$2,$3,$4::jsonb)
       ON CONFLICT (id) DO UPDATE SET state=EXCLUDED.state,data=EXCLUDED.data,updated_at=now()`,
      [settlement.id, settlement.proposal_id, settlement.state, JSON.stringify(settlement)]
    );
  }

  async getSettlement(id) {
    const { rows } = await this.pool.query(
      "SELECT state,data FROM orbitas_gateway.settlements WHERE id=$1",
      [id]
    );
    if (!rows[0]) return null;
    return { ...rows[0].data, state: rows[0].state };
  }

  async addWebhookSubscription(subscription) {
    const { rows } = await this.pool.query(
      `INSERT INTO orbitas_gateway.webhook_subscriptions(id,source_system,participant_id,callback_url,secret)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (id) DO UPDATE SET callback_url=EXCLUDED.callback_url,secret=EXCLUDED.secret,active=true
       RETURNING id,source_system,participant_id,callback_url,active`,
      [subscription.id, subscription.source_system, String(subscription.participant_id), subscription.callback_url, subscription.secret]
    );
    return rows[0];
  }

  async getWebhookSubscriptions(participantIds) {
    const ids = [...new Set(participantIds.map(String))];
    if (ids.length === 0) return [];
    const { rows } = await this.pool.query(
      "SELECT * FROM orbitas_gateway.webhook_subscriptions WHERE active=true AND participant_id = ANY($1::text[])",
      [ids]
    );
    return rows;
  }

  async saveOutboundEvent(event) {
    await this.pool.query(
      `INSERT INTO orbitas_gateway.outbound_events(event_id,event_type,participant_id,subscription_id,payload,status,attempts,last_error,delivered_at)
       VALUES ($1,$2,$3,$4,$5::jsonb,$6,$7,$8,$9)
       ON CONFLICT (event_id) DO UPDATE SET status=EXCLUDED.status,attempts=EXCLUDED.attempts,last_error=EXCLUDED.last_error,delivered_at=EXCLUDED.delivered_at`,
      [event.event_id,event.event_type,String(event.participant_id),event.subscription_id,JSON.stringify(event.payload),event.status,event.attempts,event.last_error ?? null,event.delivered_at ?? null]
    );
  }
}
