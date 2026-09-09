import { BigInt } from "@graphprotocol/graph-ts";
import { ObligationIssued, ObligationLocked, ObligationLockReleased, ObligationSettled, ObligationCancelled, QualityObservationRecorded, QualityClaimCreated, QualityClaimResolved, QualityStakeSignalChanged } from "../generated/MultidimensionalObligation/MultidimensionalObligation";
import { Obligation, ObligationLock, QualityDimension, QualityObservationEvent, QualityClaim, QualityStakeSummary } from "../generated/schema";
import { eventId } from "./helpers";

function zero(): BigInt { return BigInt.zero(); }
function recompute(o: Obligation): void { o.availableQuantity = o.totalQuantity.minus(o.settledQuantity).minus(o.cancelledQuantity).minus(o.lockedQuantity); }

export function handleObligationIssued(e: ObligationIssued): void {
  let o = new Obligation(e.params.obligationId.toString());
  o.issuerPassportId = e.params.issuerPassportId;
  o.beneficiaryPassportId = e.params.beneficiaryPassportId;
  o.externalCounterpartyHash = e.params.externalCounterpartyHash;
  o.resourceType = e.params.resourceType;
  o.resourceCode = e.params.resourceCode;
  o.unitCode = e.params.unitCode;
  o.currencyCode = e.params.currencyCode;
  o.totalQuantity = e.params.totalQuantity;
  o.settledQuantity = zero(); o.cancelledQuantity = zero(); o.lockedQuantity = zero();
  o.decimals = e.params.decimals;
  o.dueDate = e.params.dueDate;
  o.sourceRefHash = e.params.sourceRefHash;
  o.evidenceHash = e.params.evidenceHash;
  o.propertiesHash = e.params.propertiesHash;
  o.metadataHash = e.params.metadataHash;
  o.qualitySchemaHash = e.params.qualitySchemaHash;
  o.metadataURI = e.params.metadataURI;
  o.propertiesURI = e.params.propertiesURI;
  o.status = 1;
  o.createdAt = e.block.timestamp;
  o.updatedAtBlock = e.block.number;
  recompute(o); o.save();
}

export function handleObligationLocked(e: ObligationLocked): void {
  let id = e.params.obligationId.toString()+":"+e.params.settlementId.toHexString();
  let l = new ObligationLock(id); l.obligationId=e.params.obligationId; l.settlementId=e.params.settlementId; l.quantity=e.params.quantity; l.expiresAt=e.params.expiresAt; l.active=true; l.save();
  let o=Obligation.load(e.params.obligationId.toString()); if(o!=null){o.lockedQuantity=o.lockedQuantity.plus(e.params.quantity);o.updatedAtBlock=e.block.number;recompute(o);o.save();}
}

export function handleObligationLockReleased(e: ObligationLockReleased): void {
  let id=e.params.obligationId.toString()+":"+e.params.settlementId.toHexString(); let l=ObligationLock.load(id); if(l!=null){l.active=false;l.save();}
  let o=Obligation.load(e.params.obligationId.toString()); if(o!=null){o.lockedQuantity=o.lockedQuantity.minus(e.params.quantity);o.updatedAtBlock=e.block.number;recompute(o);o.save();}
}

export function handleObligationSettled(e: ObligationSettled): void {
  let id=e.params.obligationId.toString()+":"+e.params.settlementId.toHexString(); let l=ObligationLock.load(id); if(l!=null){l.quantity=l.quantity.minus(e.params.quantity);if(l.quantity.equals(zero()))l.active=false;l.save();}
  let o=Obligation.load(e.params.obligationId.toString()); if(o!=null){o.lockedQuantity=o.lockedQuantity.minus(e.params.quantity);o.settledQuantity=o.settledQuantity.plus(e.params.quantity);if(e.params.remainingQuantity.equals(zero()))o.status=2;o.updatedAtBlock=e.block.number;recompute(o);o.save();}
}

export function handleObligationCancelled(e: ObligationCancelled): void { let o=Obligation.load(e.params.obligationId.toString()); if(o!=null){o.cancelledQuantity=e.params.cancelledQuantity;o.settledQuantity=e.params.settledQuantity;o.status=3;o.updatedAtBlock=e.block.number;recompute(o);o.save();} }

export function handleQualityObservationRecorded(e: QualityObservationRecorded): void {
  let key=e.params.obligationId.toString()+":"+e.params.qualityKey.toHexString(); let q=new QualityDimension(key); q.obligationId=e.params.obligationId;q.qualityKey=e.params.qualityKey;q.encodedValue=e.params.encodedValue;q.decimals=e.params.decimals;q.sourceType=e.params.sourceType;q.evidenceHash=e.params.evidenceHash;q.observedAt=e.params.observedAt;q.validUntil=e.params.validUntil;q.observationCount=e.params.observationCount;q.confidencePpm=e.params.confidencePpm;q.updatedAtBlock=e.block.number;q.save();
  let h=new QualityObservationEvent(eventId(e));h.obligationId=e.params.obligationId;h.qualityKey=e.params.qualityKey;h.encodedValue=e.params.encodedValue;h.decimals=e.params.decimals;h.sourceType=e.params.sourceType;h.evidenceHash=e.params.evidenceHash;h.observedAt=e.params.observedAt;h.validUntil=e.params.validUntil;h.observationCount=e.params.observationCount;h.confidencePpm=e.params.confidencePpm;h.blockNumber=e.block.number;h.transactionHash=e.transaction.hash;h.save();
}

export function handleQualityClaimCreated(e: QualityClaimCreated): void { let c=new QualityClaim(e.params.claimId.toHexString());c.obligationId=e.params.obligationId;c.qualityKey=e.params.qualityKey;c.operator=e.params.operator;c.threshold=e.params.threshold;c.decimals=e.params.decimals;c.contextHash=e.params.contextHash;c.validUntil=e.params.validUntil;c.evidenceHash=e.params.evidenceHash;c.resolved=false;c.save(); }
export function handleQualityClaimResolved(e: QualityClaimResolved): void { let c=QualityClaim.load(e.params.claimId.toHexString());if(c!=null){c.resolved=true;c.resolution=e.params.resolution;c.evidenceHash=e.params.evidenceHash;c.save();} }
export function handleQualityStakeSignalChanged(e: QualityStakeSignalChanged): void { let id=e.params.claimId.toHexString()+":"+e.params.collateralToken.toHexString();let s=QualityStakeSummary.load(id);if(s==null){s=new QualityStakeSummary(id);s.claimId=e.params.claimId;s.collateralToken=e.params.collateralToken;}s.forAmount=e.params.newForAmount;s.againstAmount=e.params.newAgainstAmount;s.updatedAtBlock=e.block.number;s.save(); }
