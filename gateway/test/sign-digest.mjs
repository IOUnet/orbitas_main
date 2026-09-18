import { privateKeyToAccount } from "viem/accounts";

const [digest, privateKey] = process.argv.slice(2);
if (!/^0x[0-9a-fA-F]{64}$/.test(digest ?? "") || !/^0x[0-9a-fA-F]{64}$/.test(privateKey ?? "")) {
  console.error("usage: node test/sign-digest.mjs <bytes32-digest> <private-key>");
  process.exit(2);
}
const account = privateKeyToAccount(privateKey);
console.log(await account.sign({ hash: digest }));
