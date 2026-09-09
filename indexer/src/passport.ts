import { BigInt } from "@graphprotocol/graph-ts";
import { PassportRegistered, PassportMetadataUpdated, PassportControllerChanged, PassportDeactivated } from "../generated/ParticipantPassport/ParticipantPassport";
import { Participant, PassportEvent } from "../generated/schema";
import { eventId } from "./helpers";

export function handlePassportRegistered(e: PassportRegistered): void {
  let p = new Participant(e.params.passportId.toString());
  p.controller = e.params.controller;
  p.metadataHash = e.params.metadataHash;
  p.metadataURI = e.params.metadataURI;
  p.status = 1;
  p.createdAt = e.block.timestamp;
  p.updatedAt = e.block.timestamp;
  p.save();

  let ev = new PassportEvent(eventId(e));
  ev.passportId = e.params.passportId;
  ev.eventType = "REGISTERED";
  ev.controller = e.params.controller;
  ev.metadataHash = e.params.metadataHash;
  ev.metadataURI = e.params.metadataURI;
  ev.blockNumber = e.block.number;
  ev.blockTimestamp = e.block.timestamp;
  ev.transactionHash = e.transaction.hash;
  ev.save();
}

export function handlePassportMetadataUpdated(e: PassportMetadataUpdated): void {
  let p = Participant.load(e.params.passportId.toString());
  if (p != null) { p.metadataHash = e.params.newHash; p.metadataURI = e.params.newURI; p.updatedAt = e.block.timestamp; p.save(); }
}

export function handlePassportControllerChanged(e: PassportControllerChanged): void {
  let p = Participant.load(e.params.passportId.toString());
  if (p != null) { p.controller = e.params.newController; p.updatedAt = e.block.timestamp; p.save(); }
}

export function handlePassportDeactivated(e: PassportDeactivated): void {
  let p = Participant.load(e.params.passportId.toString());
  if (p != null) { p.status = 2; p.updatedAt = e.block.timestamp; p.save(); }
}
