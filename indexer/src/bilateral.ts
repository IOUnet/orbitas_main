import { BilateralExchangeSettled } from "../generated/BilateralExchange/BilateralExchange";
import { BilateralSettlement } from "../generated/schema";
import { eventId } from "./helpers";
export function handleBilateralExchangeSettled(e: BilateralExchangeSettled): void { let s=new BilateralSettlement(eventId(e));s.exchangeId=e.params.exchangeId;s.leftObligationId=e.params.leftObligationId;s.rightObligationId=e.params.rightObligationId;s.quantity=e.params.quantity;s.leftPassportId=e.params.leftPassportId;s.rightPassportId=e.params.rightPassportId;s.blockNumber=e.block.number;s.transactionHash=e.transaction.hash;s.save(); }
