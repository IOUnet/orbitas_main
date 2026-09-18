import { randomUUID } from "node:crypto";
import {
  createPublicClient,
  createWalletClient,
  defineChain,
  encodeFunctionData,
  getAddress,
  http,
  recoverAddress
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { multilateralAbi, obligationAbi, passportAbi } from "./abi.mjs";
import {
  GatewayError,
  ZERO_HASH,
  bigintJson,
  bytes32Label,
  hashObject,
  hashText,
  minBigInt,
  normalizeBytes32,
  parseQuantity,
  parseUnixDate,
  resourceTypeNumber
} from "./utils.mjs";

function tupleField(value, key, index) {
  return value && typeof value === "object" && key in value ? value[key] : value[index];
}

function obligationJson(id, value, availableQuantity = null) {
  return bigintJson({
    id: String(id),
    issuer_passport_id: tupleField(value, "issuerPassportId", 0),
    beneficiary_passport_id: tupleField(value, "beneficiaryPassportId", 1),
    external_counterparty_hash: tupleField(value, "externalCounterpartyHash", 2),
    resource_type: tupleField(value, "resourceType", 3),
    resource_code: tupleField(value, "resourceCode", 4),
    unit_code: tupleField(value, "unitCode", 5),
    currency_code: tupleField(value, "currencyCode", 6),
    total_quantity: tupleField(value, "totalQuantity", 7),
    settled_quantity: tupleField(value, "settledQuantity", 8),
    cancelled_quantity: tupleField(value, "cancelledQuantity", 9),
    decimals: tupleField(value, "decimals", 10),
    due_date: tupleField(value, "dueDate", 11),
    properties_hash: tupleField(value, "propertiesHash", 12),
    properties_uri: tupleField(value, "propertiesURI", 13),
    source_ref_hash: tupleField(value, "sourceRefHash", 14),
    evidence_hash: tupleField(value, "evidenceHash", 15),
    metadata_hash: tupleField(value, "metadataHash", 16),
    metadata_uri: tupleField(value, "metadataURI", 17),
    quality_schema_hash: tupleField(value, "qualitySchemaHash", 18),
    status: tupleField(value, "status", 19),
    created_at: tupleField(value, "createdAt", 20),
    available_quantity: availableQuantity
  });
}

export class OrbitasProtocol {
  constructor(config) {
    this.config = config;
    this.account = privateKeyToAccount(config.relayerPrivateKey);
    this.chain = defineChain({
      id: config.chainId,
      name: "Orbitas",
      nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
      rpcUrls: { default: { http: [config.rpcUrl] } }
    });
    this.publicClient = createPublicClient({ chain: this.chain, transport: http(config.rpcUrl) });
    this.walletClient = createWalletClient({
      chain: this.chain,
      account: this.account,
      transport: http(config.rpcUrl)
    });
  }

  preparePassport(body) {
    const companyName = String(body.company_name ?? "").trim();
    const website = String(body.website ?? "").trim();
    if (!companyName || !website) {
      throw new GatewayError("INVALID_PASSPORT_PROFILE", "company_name and website are required", 400);
    }
    const metadata = {
      schema_version: "1.0",
      verification_level: "SELF_DECLARED",
      company_name: companyName,
      website
    };
    const metadataHash = hashObject(metadata);
    const metadataUri = String(body.metadata_uri ?? `urn:orbitas:passport:${metadataHash}`);
    const data = encodeFunctionData({
      abi: passportAbi,
      functionName: "registerPassport",
      args: [metadataHash, metadataUri]
    });
    return {
      chain_id: this.config.chainId,
      to: this.config.passportAddress,
      data,
      metadata_hash: metadataHash,
      metadata_uri: metadataUri,
      verification_level: "SELF_DECLARED"
    };
  }

  async getPassport(passportId) {
    const id = BigInt(passportId);
    const result = await this.publicClient.readContract({
      address: this.config.passportAddress,
      abi: passportAbi,
      functionName: "getPassport",
      args: [id]
    });
    return bigintJson({
      id: id.toString(),
      controller: result[0],
      metadata_hash: result[1],
      metadata_uri: result[2],
      status: result[3],
      created_at: result[4],
      updated_at: result[5],
      operator_epoch: result[6]
    });
  }

  async getObligation(obligationId) {
    const id = BigInt(obligationId);
    const [obligation, available] = await Promise.all([
      this.publicClient.readContract({
        address: this.config.obligationAddress,
        abi: obligationAbi,
        functionName: "getObligation",
        args: [id]
      }),
      this.publicClient.readContract({
        address: this.config.obligationAddress,
        abi: obligationAbi,
        functionName: "availableQuantity",
        args: [id]
      })
    ]);
    return obligationJson(id, obligation, available);
  }

  sourceRefHash(source) {
    const normalized = {
      system: String(source.system ?? ""),
      instance_id: String(source.instance_id ?? ""),
      company_id: String(source.company_id ?? ""),
      record_type: String(source.record_type ?? ""),
      record_id: String(source.record_id ?? ""),
      revision: String(source.revision ?? "")
    };
    for (const [key, value] of Object.entries(normalized)) {
      if (!value) throw new GatewayError("INVALID_SOURCE", `source.${key} is required`, 400);
    }
    return hashObject(normalized);
  }

  async issueObligation(body) {
    const sourceRefHash = this.sourceRefHash(body.source ?? {});
    const existing = await this.publicClient.readContract({
      address: this.config.obligationAddress,
      abi: obligationAbi,
      functionName: "obligationBySourceRef",
      args: [sourceRefHash]
    });
    if (existing > 0n) {
      return { obligation_id: existing.toString(), source_ref_hash: sourceRefHash, reused: true, tx_hash: null };
    }

    const parties = body.parties ?? {};
    const resource = body.resource ?? {};
    const issuerPassportId = BigInt(parties.issuer_passport_id ?? 0);
    const beneficiaryPassportId = BigInt(parties.beneficiary_passport_id ?? 0);
    if (issuerPassportId <= 0n) throw new GatewayError("INVALID_ISSUER", "parties.issuer_passport_id is required", 400);
    if (beneficiaryPassportId <= 0n && !parties.external_counterparty_ref) {
      throw new GatewayError("INVALID_BENEFICIARY", "beneficiary_passport_id or external_counterparty_ref is required", 400);
    }

    const decimals = Number(resource.decimals ?? 2);
    const quantity = parseQuantity(resource.quantity, decimals);
    if (quantity <= 0n) throw new GatewayError("INVALID_QUANTITY", "resource.quantity must be positive", 400);

    const evidenceHash = normalizeBytes32(body.evidence?.hash, body.evidence ?? { ref: "none" });
    const propertiesHash = normalizeBytes32(body.properties_hash, body.properties ?? {});
    const metadataHash = normalizeBytes32(body.metadata_hash, {
      source: body.source,
      parties,
      resource,
      metadata: body.metadata ?? {}
    });
    const qualitySchemaHash = normalizeBytes32(
      body.quality_schema_hash,
      body.quality_schema ?? { schema: "orbitas.quality.v1" }
    );

    const input = {
      issuerPassportId,
      beneficiaryPassportId,
      externalCounterpartyHash: beneficiaryPassportId > 0n
        ? ZERO_HASH
        : hashText(parties.external_counterparty_ref),
      resourceType: resourceTypeNumber(resource.type),
      resourceCode: bytes32Label(resource.code ?? resource.currency ?? resource.unit ?? "RESOURCE", "resource.code"),
      unitCode: bytes32Label(resource.unit ?? resource.currency ?? "UNIT", "resource.unit"),
      currencyCode: bytes32Label(resource.currency ?? "", "resource.currency"),
      quantity,
      decimals,
      dueDate: parseUnixDate(resource.due_date, "resource.due_date"),
      propertiesHash,
      propertiesURI: String(body.properties_uri ?? `urn:orbitas:properties:${propertiesHash}`),
      sourceRefHash,
      evidenceHash,
      metadataHash,
      metadataURI: String(body.metadata_uri ?? `urn:orbitas:metadata:${metadataHash}`),
      qualitySchemaHash
    };

    const simulation = await this.publicClient.simulateContract({
      address: this.config.obligationAddress,
      abi: obligationAbi,
      functionName: "issueObligation",
      args: [input],
      account: this.account
    });
    const txHash = await this.walletClient.writeContract(simulation.request);
    await this.publicClient.waitForTransactionReceipt({ hash: txHash });
    return {
      obligation_id: simulation.result.toString(),
      source_ref_hash: sourceRefHash,
      reused: false,
      tx_hash: txHash
    };
  }

  async listIndexedObligations(passportId, direction) {
    const id = String(BigInt(passportId));
    const field = direction === "incoming" ? "beneficiaryPassportId" : direction === "outgoing" ? "issuerPassportId" : null;
    if (!field) throw new GatewayError("INVALID_DIRECTION", "direction must be incoming or outgoing", 400);
    const query = `{ obligations(first: 200, orderBy: id, orderDirection: asc, where: { ${field}: "${id}" }) {
      id issuerPassportId beneficiaryPassportId resourceType resourceCode unitCode currencyCode totalQuantity settledQuantity cancelledQuantity lockedQuantity availableQuantity decimals dueDate sourceRefHash evidenceHash propertiesHash metadataHash qualitySchemaHash metadataURI propertiesURI status
    } _meta { block { number } hasIndexingErrors } }`;
    const response = await fetch(this.config.graphqlEndpoint, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ query }),
      signal: AbortSignal.timeout(5000)
    });
    if (!response.ok) throw new GatewayError("INDEX_UNAVAILABLE", `GraphQL HTTP ${response.status}`, 503);
    const payload = await response.json();
    if (payload.errors) throw new GatewayError("INDEX_QUERY_FAILED", payload.errors[0]?.message ?? "GraphQL query failed", 503);
    return payload.data;
  }

  async discoverPath(body) {
    const incomingId = BigInt(body.incoming_obligation_id);
    const outgoingId = BigInt(body.outgoing_obligation_id);
    const [incoming, outgoing, incomingAvailable, outgoingAvailable] = await Promise.all([
      this.publicClient.readContract({ address: this.config.obligationAddress, abi: obligationAbi, functionName: "getObligation", args: [incomingId] }),
      this.publicClient.readContract({ address: this.config.obligationAddress, abi: obligationAbi, functionName: "getObligation", args: [outgoingId] }),
      this.publicClient.readContract({ address: this.config.obligationAddress, abi: obligationAbi, functionName: "availableQuantity", args: [incomingId] }),
      this.publicClient.readContract({ address: this.config.obligationAddress, abi: obligationAbi, functionName: "availableQuantity", args: [outgoingId] })
    ]);

    const inIssuer = BigInt(tupleField(incoming, "issuerPassportId", 0));
    const inBeneficiary = BigInt(tupleField(incoming, "beneficiaryPassportId", 1));
    const outIssuer = BigInt(tupleField(outgoing, "issuerPassportId", 0));
    const outBeneficiary = BigInt(tupleField(outgoing, "beneficiaryPassportId", 1));
    const inStatus = Number(tupleField(incoming, "status", 19));
    const outStatus = Number(tupleField(outgoing, "status", 19));
    if (inStatus !== 1 || outStatus !== 1) throw new GatewayError("OBLIGATION_NOT_ACTIVE", "both obligations must be active", 409);
    if (inBeneficiary === 0n || outBeneficiary === 0n || inBeneficiary !== outIssuer || inIssuer === outBeneficiary) {
      throw new GatewayError("INVALID_PATH", "obligations do not form an onboarded A→B→C path", 409);
    }

    const compatibilityFields = [
      ["resourceType", 3],
      ["resourceCode", 4],
      ["unitCode", 5],
      ["currencyCode", 6],
      ["decimals", 10]
    ];
    for (const [key, index] of compatibilityFields) {
      if (String(tupleField(incoming, key, index)) !== String(tupleField(outgoing, key, index))) {
        throw new GatewayError("INCOMPATIBLE_OBLIGATIONS", `resource dimension mismatch: ${key}`, 409);
      }
    }

    let quantity = minBigInt(incomingAvailable, outgoingAvailable);
    if (body.max_quantity_base_units !== undefined) {
      const max = BigInt(body.max_quantity_base_units);
      if (max > 0n) quantity = minBigInt(quantity, max);
    }
    if (quantity <= 0n) throw new GatewayError("NO_AVAILABLE_QUANTITY", "path has no available quantity", 409);

    const ttl = Math.min(Math.max(Number(body.expires_in_seconds ?? 600), 60), 3600);
    const expiresAt = BigInt(Math.floor(Date.now() / 1000) + ttl);
    const salt = hashText(randomUUID());
    const order = {
      incomingObligationId: incomingId,
      outgoingObligationId: outgoingId,
      quantity,
      expiresAt,
      salt
    };
    const digest = await this.publicClient.readContract({
      address: this.config.multilateralAddress,
      abi: multilateralAbi,
      functionName: "pathDigest",
      args: [order]
    });
    const proposalId = hashObject({
      chain_id: this.config.chainId,
      multilateral_contract: this.config.multilateralAddress,
      incoming_obligation_id: incomingId.toString(),
      outgoing_obligation_id: outgoingId.toString(),
      quantity: quantity.toString(),
      expires_at: expiresAt.toString(),
      salt
    });
    const decimals = Number(tupleField(incoming, "decimals", 10));
    return {
      id: proposalId,
      state: "CANDIDATE",
      path: {
        payer_passport_id: inIssuer.toString(),
        intermediary_passport_id: inBeneficiary.toString(),
        receiver_passport_id: outBeneficiary.toString(),
        incoming_obligation_id: incomingId.toString(),
        outgoing_obligation_id: outgoingId.toString()
      },
      matched_quantity_base_units: quantity.toString(),
      decimals,
      expires_at: expiresAt.toString(),
      salt,
      path_digest: digest,
      required_approvals: [inIssuer.toString(), inBeneficiary.toString(), outBeneficiary.toString()]
    };
  }

  async verifyConsent(passportId, digest, signature) {
    const signer = getAddress(await recoverAddress({ hash: digest, signature }));
    const authorized = await this.publicClient.readContract({
      address: this.config.passportAddress,
      abi: passportAbi,
      functionName: "isAuthorized",
      args: [BigInt(passportId), signer, 8n]
    });
    if (!authorized) {
      throw new GatewayError("UNAUTHORIZED_CONSENT", `signature is not authorized for passport ${passportId}`, 403, { signer });
    }
    return signer;
  }

  orderFromProposal(proposal) {
    return {
      incomingObligationId: BigInt(proposal.path.incoming_obligation_id),
      outgoingObligationId: BigInt(proposal.path.outgoing_obligation_id),
      quantity: BigInt(proposal.matched_quantity_base_units),
      expiresAt: BigInt(proposal.expires_at),
      salt: proposal.salt
    };
  }

  async executeProposal(proposal, approvals) {
    const required = proposal.required_approvals.map(String);
    const byPassport = new Map(approvals.map((a) => [String(a.passport_id), a.signature]));
    for (const passportId of required) {
      if (!byPassport.has(passportId)) throw new GatewayError("MISSING_CONSENT", `missing approval for passport ${passportId}`, 409);
    }
    const order = this.orderFromProposal(proposal);
    const simulation = await this.publicClient.simulateContract({
      address: this.config.multilateralAddress,
      abi: multilateralAbi,
      functionName: "createPathInstruction",
      args: [
        order,
        byPassport.get(proposal.path.payer_passport_id),
        byPassport.get(proposal.path.intermediary_passport_id),
        byPassport.get(proposal.path.receiver_passport_id)
      ],
      account: this.account
    });
    const txHash = await this.walletClient.writeContract(simulation.request);
    await this.publicClient.waitForTransactionReceipt({ hash: txHash });
    return {
      id: simulation.result,
      proposal_id: proposal.id,
      state: "PENDING",
      tx_hash: txHash,
      payer_passport_id: proposal.path.payer_passport_id,
      intermediary_passport_id: proposal.path.intermediary_passport_id,
      receiver_passport_id: proposal.path.receiver_passport_id,
      incoming_obligation_id: proposal.path.incoming_obligation_id,
      outgoing_obligation_id: proposal.path.outgoing_obligation_id,
      quantity_base_units: proposal.matched_quantity_base_units,
      decimals: proposal.decimals,
      expires_at: proposal.expires_at
    };
  }

  async getSettlement(settlementId) {
    const value = await this.publicClient.readContract({
      address: this.config.multilateralAddress,
      abi: multilateralAbi,
      functionName: "getInstruction",
      args: [settlementId]
    });
    const names = ["NONE", "PENDING", "SETTLED", "EXPIRED"];
    return bigintJson({
      id: settlementId,
      incoming_obligation_id: tupleField(value, "incomingObligationId", 0),
      outgoing_obligation_id: tupleField(value, "outgoingObligationId", 1),
      payer_passport_id: tupleField(value, "payerPassportId", 2),
      intermediary_passport_id: tupleField(value, "intermediaryPassportId", 3),
      receiver_passport_id: tupleField(value, "receiverPassportId", 4),
      quantity_base_units: tupleField(value, "quantity", 5),
      decimals: tupleField(value, "decimals", 6),
      resource_type: tupleField(value, "resourceType", 7),
      resource_code: tupleField(value, "resourceCode", 8),
      unit_code: tupleField(value, "unitCode", 9),
      currency_code: tupleField(value, "currencyCode", 10),
      due_date: tupleField(value, "dueDate", 11),
      expires_at: tupleField(value, "expiresAt", 12),
      consent_proof_hash: tupleField(value, "consentProofHash", 13),
      fulfillment_evidence_hash: tupleField(value, "fulfillmentEvidenceHash", 14),
      status: names[Number(tupleField(value, "status", 15))] ?? "UNKNOWN"
    });
  }

  async prepareConfirmation(settlementId, body) {
    const evidenceHash = normalizeBytes32(body.fulfillment_evidence_hash, {
      evidence: body.fulfillment_evidence ?? "confirmed"
    });
    const deadline = body.deadline
      ? parseUnixDate(body.deadline, "deadline")
      : BigInt(Math.floor(Date.now() / 1000) + 600);
    const digest = await this.publicClient.readContract({
      address: this.config.multilateralAddress,
      abi: multilateralAbi,
      functionName: "confirmationDigest",
      args: [settlementId, evidenceHash, deadline]
    });
    return {
      settlement_id: settlementId,
      fulfillment_evidence_hash: evidenceHash,
      deadline: deadline.toString(),
      confirmation_digest: digest
    };
  }

  async confirmSettlement(settlementId, body) {
    const prepared = await this.prepareConfirmation(settlementId, body);
    const instruction = await this.getSettlement(settlementId);
    const intermediarySigner = await this.verifyConsent(
      instruction.intermediary_passport_id,
      prepared.confirmation_digest,
      body.intermediary_signature
    );
    const receiverSigner = await this.verifyConsent(
      instruction.receiver_passport_id,
      prepared.confirmation_digest,
      body.receiver_signature
    );
    const simulation = await this.publicClient.simulateContract({
      address: this.config.multilateralAddress,
      abi: multilateralAbi,
      functionName: "confirmPathSettlement",
      args: [
        settlementId,
        prepared.fulfillment_evidence_hash,
        BigInt(prepared.deadline),
        body.intermediary_signature,
        body.receiver_signature
      ],
      account: this.account
    });
    const txHash = await this.walletClient.writeContract(simulation.request);
    await this.publicClient.waitForTransactionReceipt({ hash: txHash });
    return {
      ...prepared,
      state: "SETTLED",
      tx_hash: txHash,
      intermediary_signer: intermediarySigner,
      receiver_signer: receiverSigner
    };
  }
}
