// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {ParticipantPassport} from "../src/ParticipantPassport.sol";
import {MultidimensionalObligation} from "../src/MultidimensionalObligation.sol";
import {BilateralExchange} from "../src/BilateralExchange.sol";

contract BilateralExchangeTest is Test {
    ParticipantPassport internal passports;
    MultidimensionalObligation internal obligations;
    BilateralExchange internal exchange;

    uint256 internal constant ALICE_PK = 0xA11CE;
    uint256 internal constant BOB_PK = 0xB0B;
    address internal alice;
    address internal bob;
    uint256 internal aliceId;
    uint256 internal bobId;

    function setUp() public {
        alice = vm.addr(ALICE_PK);
        bob = vm.addr(BOB_PK);

        passports = new ParticipantPassport(address(this));
        obligations = new MultidimensionalObligation(address(passports), address(this));
        exchange = new BilateralExchange(address(passports), address(obligations));
        obligations.grantRole(obligations.SETTLEMENT_ROLE(), address(exchange));

        vm.prank(alice);
        aliceId = passports.registerPassport(keccak256("alice"), "ipfs://alice");
        vm.prank(bob);
        bobId = passports.registerPassport(keccak256("bob"), "ipfs://bob");
    }

    function _issue(address issuer, uint256 issuerId, uint256 beneficiaryId, uint256 quantity, bytes32 sourceRef)
        internal
        returns (uint256)
    {
        MultidimensionalObligation.IssueInput memory input = MultidimensionalObligation.IssueInput({
            issuerPassportId: issuerId,
            beneficiaryPassportId: beneficiaryId,
            externalCounterpartyHash: bytes32(0),
            resourceType: MultidimensionalObligation.ResourceType.MONETARY,
            resourceCode: bytes32("BRL"),
            unitCode: bytes32("BRL"),
            currencyCode: bytes32("BRL"),
            quantity: quantity,
            decimals: 2,
            dueDate: uint64(block.timestamp + 30 days),
            propertiesHash: keccak256(abi.encode("money", sourceRef)),
            propertiesURI: "ipfs://properties",
            sourceRefHash: sourceRef,
            evidenceHash: keccak256(abi.encode("evidence", sourceRef)),
            metadataHash: keccak256(abi.encode("metadata", sourceRef)),
            metadataURI: "ipfs://metadata",
            qualitySchemaHash: keccak256("quality-v1")
        });
        vm.prank(issuer);
        return obligations.issueObligation(input);
    }

    function _sign(uint256 pk, bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_atomicReciprocalOffset() public {
        uint256 aToB = _issue(alice, aliceId, bobId, 100_00, keccak256("a-b"));
        uint256 bToA = _issue(bob, bobId, aliceId, 60_00, keccak256("b-a"));

        BilateralExchange.BilateralOrder memory order = BilateralExchange.BilateralOrder({
            leftObligationId: aToB,
            rightObligationId: bToA,
            quantity: 60_00,
            deadline: uint64(block.timestamp + 1 days),
            salt: keccak256("bilateral-1")
        });

        bytes32 digest = exchange.orderDigest(order);
        bytes memory aliceSig = _sign(ALICE_PK, digest);
        bytes memory bobSig = _sign(BOB_PK, digest);

        bytes32 exchangeId = exchange.settle(order, aliceSig, bobSig);

        assertTrue(exchange.executed(exchangeId));
        assertEq(obligations.availableQuantity(aToB), 40_00);
        assertEq(obligations.availableQuantity(bToA), 0);
        assertEq(obligations.lockedQuantity(aToB), 0);
        assertEq(obligations.lockedQuantity(bToA), 0);
    }

    function test_rejectsReplay() public {
        uint256 aToB = _issue(alice, aliceId, bobId, 100_00, keccak256("a-b-replay"));
        uint256 bToA = _issue(bob, bobId, aliceId, 100_00, keccak256("b-a-replay"));
        BilateralExchange.BilateralOrder memory order = BilateralExchange.BilateralOrder({
            leftObligationId: aToB,
            rightObligationId: bToA,
            quantity: 50_00,
            deadline: uint64(block.timestamp + 1 days),
            salt: keccak256("replay")
        });
        bytes32 digest = exchange.orderDigest(order);
        bytes memory aliceSig = _sign(ALICE_PK, digest);
        bytes memory bobSig = _sign(BOB_PK, digest);
        exchange.settle(order, aliceSig, bobSig);
        vm.expectRevert();
        exchange.settle(order, aliceSig, bobSig);
    }
}
