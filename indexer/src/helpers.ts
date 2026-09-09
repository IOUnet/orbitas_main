import { Bytes, ethereum } from "@graphprotocol/graph-ts";

export function eventId(event: ethereum.Event): Bytes {
  return event.transaction.hash.concatI32(event.logIndex.toI32());
}

export function id2(a: Bytes, b: Bytes): string {
  return a.toHexString() + ":" + b.toHexString();
}
