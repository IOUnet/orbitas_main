// Canonical Orbitas Gateway v1 shared DTOs.
// This file is intentionally dependency-free so ERP adapter generators can consume it.

export type ResourceType = "MONETARY" | "GOODS" | "SERVICE";

export interface ERPSource {
  system: string;
  instance_id: string;
  company_id: string;
  record_type: string;
  record_id: string;
  revision: string;
}

export interface ObligationParties {
  issuer_passport_id: string;
  beneficiary_passport_id?: string;
  external_counterparty_ref?: string;
}

export interface Resource {
  type: ResourceType;
  code: string;
  unit: string;
  currency?: string;
  quantity: string;
  decimals: number;
  due_date: string;
}

export interface ObligationPublishRequest {
  source: ERPSource;
  parties: ObligationParties;
  resource: Resource;
  properties?: Record<string, unknown>;
  properties_hash?: string;
  properties_uri?: string;
  evidence: { hash?: string; ref?: string };
  metadata?: Record<string, unknown>;
  metadata_hash?: string;
  metadata_uri?: string;
  quality_schema?: Record<string, unknown>;
  quality_schema_hash?: string;
}

export interface ClearingProposal {
  id: string;
  state: "CANDIDATE" | "AWAITING_APPROVALS" | "APPROVED" | "REJECTED" | "EXECUTED";
  path: {
    payer_passport_id: string;
    intermediary_passport_id: string;
    receiver_passport_id: string;
    incoming_obligation_id: string;
    outgoing_obligation_id: string;
  };
  matched_quantity_base_units: string;
  decimals: number;
  expires_at: string;
  salt: string;
  path_digest: string;
  required_approvals: string[];
}
