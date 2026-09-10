// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {ParticipantPassport} from "../src/ParticipantPassport.sol";
import {MultidimensionalObligation} from "../src/MultidimensionalObligation.sol";

contract MultidimensionalObligationTest is Test {
    ParticipantPassport p;
    MultidimensionalObligation o;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    uint256 aliceId;
    uint256 bobId;

    function setUp() public {
        p = new ParticipantPassport(address(this));
        o = new MultidimensionalObligation(address(p), address(this));
        vm.prank(alice);
        aliceId = p.registerPassport(keccak256("a"), "ipfs://a");
        vm.prank(bob);
        bobId = p.registerPassport(keccak256("b"), "ipfs://b");
    }

    function _input(bytes32 source) internal view returns (MultidimensionalObligation.IssueInput memory x) {
        x = MultidimensionalObligation.IssueInput({
            issuerPassportId: aliceId,
            beneficiaryPassportId: bobId,
            externalCounterpartyHash: bytes32(0),
            resourceType: MultidimensionalObligation.ResourceType.MONETARY,
            resourceCode: bytes32("BRL"),
            unitCode: bytes32("BRL"),
            currencyCode: bytes32("BRL"),
            quantity: 100_00,
            decimals: 2,
            dueDate: uint64(block.timestamp + 30 days),
            propertiesHash: keccak256("props"),
            propertiesURI: "ipfs://props",
            sourceRefHash: source,
            evidenceHash: keccak256("evidence"),
            metadataHash: keccak256("metadata"),
            metadataURI: "ipfs://metadata",
            qualitySchemaHash: keccak256("quality-v1")
        });
    }

    function test_issueAndQualityObservation() public {
        vm.prank(alice);
        uint256 id = o.issueObligation(_input(keccak256("source-1")));
        assertEq(o.availableQuantity(id), 100_00);
        vm.prank(alice);
        o.recordQualityObservation(
            id,
            keccak256("delivery.on_time"),
            MultidimensionalObligation.QualityValueType.UINT,
            bytes32(uint256(930_000)),
            6,
            bytes32("ERP"),
            keccak256("quality-evidence"),
            uint64(block.timestamp + 30 days),
            183,
            970_000
        );
        MultidimensionalObligation.QualityObservation memory q =
            o.getQualityObservation(id, keccak256("delivery.on_time"));
        assertEq(uint256(q.encodedValue), 930_000);
        assertEq(q.confidencePpm, 970_000);
    }

    function test_duplicateSourceReverts() public {
        bytes32 src = keccak256("same");
        vm.prank(alice);
        o.issueObligation(_input(src));
        vm.prank(alice);
        vm.expectRevert();
        o.issueObligation(_input(src));
    }
}
