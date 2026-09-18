import { parseAbi } from "viem";

export const passportAbi = parseAbi([
  "function getPassport(uint256 passportId) view returns (address controller, bytes32 metadataHash, string metadataURI, uint8 status, uint64 createdAt, uint64 updatedAt, uint64 operatorEpoch)",
  "function passportOf(address controller) view returns (uint256)",
  "function isAuthorized(uint256 passportId, address actor, uint256 permission) view returns (bool)",
  "function registerPassport(bytes32 metadataHash, string metadataURI) returns (uint256 passportId)"
]);

export const obligationAbi = parseAbi([
  "function obligationBySourceRef(bytes32 sourceRefHash) view returns (uint256)",
  "function availableQuantity(uint256 obligationId) view returns (uint256)",
  "function issueObligation((uint256 issuerPassportId,uint256 beneficiaryPassportId,bytes32 externalCounterpartyHash,uint8 resourceType,bytes32 resourceCode,bytes32 unitCode,bytes32 currencyCode,uint256 quantity,uint8 decimals,uint64 dueDate,bytes32 propertiesHash,string propertiesURI,bytes32 sourceRefHash,bytes32 evidenceHash,bytes32 metadataHash,string metadataURI,bytes32 qualitySchemaHash) input) returns (uint256 obligationId)",
  "function getObligation(uint256 obligationId) view returns ((uint256 issuerPassportId,uint256 beneficiaryPassportId,bytes32 externalCounterpartyHash,uint8 resourceType,bytes32 resourceCode,bytes32 unitCode,bytes32 currencyCode,uint256 totalQuantity,uint256 settledQuantity,uint256 cancelledQuantity,uint8 decimals,uint64 dueDate,bytes32 propertiesHash,string propertiesURI,bytes32 sourceRefHash,bytes32 evidenceHash,bytes32 metadataHash,string metadataURI,bytes32 qualitySchemaHash,uint8 status,uint64 createdAt) obligation)"
]);

export const multilateralAbi = parseAbi([
  "function pathDigest((uint256 incomingObligationId,uint256 outgoingObligationId,uint256 quantity,uint64 expiresAt,bytes32 salt) order) view returns (bytes32)",
  "function createPathInstruction((uint256 incomingObligationId,uint256 outgoingObligationId,uint256 quantity,uint64 expiresAt,bytes32 salt) order,bytes payerSig,bytes intermediarySig,bytes receiverSig) returns (bytes32 settlementId)",
  "function confirmationDigest(bytes32 settlementId,bytes32 fulfillmentEvidenceHash,uint64 deadline) view returns (bytes32)",
  "function confirmPathSettlement(bytes32 settlementId,bytes32 fulfillmentEvidenceHash,uint64 confirmationDeadline,bytes intermediarySig,bytes receiverSig)",
  "function getInstruction(bytes32 settlementId) view returns ((uint256 incomingObligationId,uint256 outgoingObligationId,uint256 payerPassportId,uint256 intermediaryPassportId,uint256 receiverPassportId,uint256 quantity,uint8 decimals,uint8 resourceType,bytes32 resourceCode,bytes32 unitCode,bytes32 currencyCode,uint64 dueDate,uint64 expiresAt,bytes32 consentProofHash,bytes32 fulfillmentEvidenceHash,uint8 status) instruction)"
]);
