import {
  keccak256,
  parseUnits,
  stringToHex,
  toBytes,
  zeroHash
} from "viem";

export const ZERO_HASH = zeroHash;

export function stableStringify(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return "[" + value.map(stableStringify).join(",") + "]";
  const keys = Object.keys(value).sort();
  return "{" + keys.map((key) => JSON.stringify(key) + ":" + stableStringify(value[key])).join(",") + "}";
}

export function hashObject(value) {
  return keccak256(toBytes(stableStringify(value)));
}

export function hashText(value) {
  return keccak256(toBytes(String(value)));
}

export function bytes32Label(value, fieldName = "code") {
  const text = String(value ?? "");
  if (!text) return ZERO_HASH;
  if (Buffer.byteLength(text, "utf8") > 32) {
    throw new GatewayError("INVALID_FIELD", `${fieldName} must be at most 32 UTF-8 bytes`, 400);
  }
  return stringToHex(text, { size: 32 });
}

export function resourceTypeNumber(value) {
  const key = String(value ?? "").toUpperCase();
  if (key === "MONETARY") return 0;
  if (key === "GOODS") return 1;
  if (key === "SERVICE") return 2;
  throw new GatewayError("INVALID_RESOURCE_TYPE", "resource.type must be MONETARY, GOODS or SERVICE", 400);
}

export function parseQuantity(value, decimals) {
  const d = Number(decimals);
  if (!Number.isInteger(d) || d < 0 || d > 18) {
    throw new GatewayError("INVALID_DECIMALS", "resource.decimals must be an integer between 0 and 18", 400);
  }
  try {
    return parseUnits(String(value), d);
  } catch {
    throw new GatewayError("INVALID_QUANTITY", "resource.quantity is not a valid fixed-point amount", 400);
  }
}

export function parseUnixDate(value, fieldName) {
  if (typeof value === "number" && Number.isSafeInteger(value) && value > 0) return BigInt(value);
  if (typeof value === "string" && /^\d+$/.test(value)) return BigInt(value);
  const millis = Date.parse(String(value ?? ""));
  if (!Number.isFinite(millis)) {
    throw new GatewayError("INVALID_DATE", `${fieldName} must be an RFC3339 timestamp or unix seconds`, 400);
  }
  return BigInt(Math.floor(millis / 1000));
}

export function normalizeBytes32(value, fallback) {
  if (typeof value === "string" && /^0x[0-9a-fA-F]{64}$/.test(value)) return value;
  return hashObject(fallback);
}

export function bigintJson(value) {
  return JSON.parse(JSON.stringify(value, (_, v) => typeof v === "bigint" ? v.toString() : v));
}

export function minBigInt(a, b) {
  return a < b ? a : b;
}

export class GatewayError extends Error {
  constructor(code, message, status = 400, details = undefined) {
    super(message);
    this.name = "GatewayError";
    this.code = code;
    this.status = status;
    this.details = details;
  }
}
