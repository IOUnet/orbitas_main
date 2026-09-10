// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Script} from "forge-std/Script.sol";
import {ParticipantPassport} from "../src/ParticipantPassport.sol";
import {MultidimensionalObligation} from "../src/MultidimensionalObligation.sol";

/// @notice Seed deterministic local-only participants and obligations for Anvil/Graph/MCP smoke tests.
contract LocalSeed is Script {
    function run() external {
        ParticipantPassport passports = ParticipantPassport(vm.envAddress("PASSPORT_ADDRESS"));
        MultidimensionalObligation obligations = MultidimensionalObligation(vm.envAddress("OBLIGATION_ADDRESS"));

        uint256 alicePk = vm.envUint("ALICE_PK");
        uint256 bobPk = vm.envUint("BOB_PK");
        uint256 carolPk = vm.envUint("CAROL_PK");

        uint256 aliceId = _register(passports, alicePk, "Alice Manufacturing", "alice.example");
        uint256 bobId = _register(passports, bobPk, "Bob Components", "bob.example");
        uint256 carolId = _register(passports, carolPk, "Carol Logistics", "carol.example");

        _issueMoney(obligations, alicePk, aliceId, bobId, 100_00, "local:A-B:100");
        _issueMoney(obligations, bobPk, bobId, carolId, 80_00, "local:B-C:80");
        _issueMoney(obligations, bobPk, bobId, aliceId, 40_00, "local:B-A:40");
        _issueMoney(obligations, carolPk, carolId, aliceId, 25_00, "local:C-A:25");
    }

    function _register(ParticipantPassport passports, uint256 pk, string memory company, string memory host)
        private
        returns (uint256 passportId)
    {
        vm.startBroadcast(pk);
        passportId = passports.registerPassport(
            keccak256(abi.encode(company, host)), string.concat("ipfs://orbitas-local/passports/", host)
        );
        vm.stopBroadcast();
    }

    function _issueMoney(
        MultidimensionalObligation obligations,
        uint256 pk,
        uint256 issuer,
        uint256 beneficiary,
        uint256 quantity,
        string memory sourceTag
    ) private {
        bytes32 sourceRef = keccak256(bytes(sourceTag));
        MultidimensionalObligation.IssueInput memory input = MultidimensionalObligation.IssueInput({
            issuerPassportId: issuer,
            beneficiaryPassportId: beneficiary,
            externalCounterpartyHash: bytes32(0),
            resourceType: MultidimensionalObligation.ResourceType.MONETARY,
            resourceCode: bytes32("BRL"),
            unitCode: bytes32("BRL"),
            currencyCode: bytes32("BRL"),
            quantity: quantity,
            decimals: 2,
            dueDate: uint64(block.timestamp + 30 days),
            propertiesHash: keccak256(abi.encode("monetary", "BRL", quantity)),
            propertiesURI: string.concat("ipfs://orbitas-local/properties/", sourceTag),
            sourceRefHash: sourceRef,
            evidenceHash: keccak256(abi.encode("evidence", sourceTag)),
            metadataHash: keccak256(abi.encode("metadata", sourceTag)),
            metadataURI: string.concat("ipfs://orbitas-local/metadata/", sourceTag),
            qualitySchemaHash: keccak256("orbitas.local.quality.v1")
        });

        vm.startBroadcast(pk);
        obligations.issueObligation(input);
        vm.stopBroadcast();
    }
}
