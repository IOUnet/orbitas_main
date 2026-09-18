import test from "node:test";
import assert from "node:assert/strict";
import { hashObject, parseQuantity, stableStringify } from "../src/utils.mjs";

test("stableStringify is key-order independent", () => {
  assert.equal(stableStringify({ b: 2, a: 1 }), stableStringify({ a: 1, b: 2 }));
  assert.equal(hashObject({ b: 2, a: 1 }), hashObject({ a: 1, b: 2 }));
});

test("fixed-point quantities are deterministic", () => {
  assert.equal(parseQuantity("100.00", 2), 10000n);
  assert.equal(parseQuantity("0.01", 2), 1n);
});
