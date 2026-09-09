// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {ParticipantPassport} from "../src/ParticipantPassport.sol";
import {MultidimensionalObligation} from "../src/MultidimensionalObligation.sol";
import {MultilateralClearing} from "../src/MultilateralClearing.sol";

contract MultilateralClearingTest is Test {
    ParticipantPassport internal passports;
    MultidimensionalObligation internal obligations;
    MultilateralClearing internal clearing;

    uint256 internal constant A_PK = 0xA11CE;
    uint256 internal constant B_PK = 0xB0B;
    uint256 internal constant C_PK = 0xCAFE;

    address internal a;
    address internal b;
    address internal c;
    uint256 internal aId;
    uint256 internal bId;
    uint256 internal cId;

    function setUp() public {
        a = vm.addr(A_PK);
        b = vm.addr(B_PK);
        c = vm.addr(C_PK);

        passports = new ParticipantPassport(address(this));
        obligations = new MultidimensionalObligation(address(passports), address(this));
        clearing = new MultilateralClearing(address(passports), address(obligations));
        obligations.grantRole(obligations.SETTLEMENT_ROLE(), address(clearing));

        vm.prank(a);
        aId = passports.registerPassport(keccak256("a"), "ipfs://a");
        vm.prank(b);
        bId = passports.registerPassport(keccak256("b"), "ipfs://b");
        vm.prank(c);
        cId = passports.registerPassport(keccak256("c"), "ipfs://c");
    }

    function _issue(address issuer, uint256 issuerId, uint256 beneficiaryId, uint256 quantity, uint64 dueDate, bytes32 sourceRef)
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
            dueDate: dueDate,
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

    function _createPath(uint256 incoming, uint256 outgoing, uint256 quantity, uint64 expiry)
        internal
        returns (bytes32 settlementId)
    {
        MultilateralClearing.PathOrder memory order = MultilateralClearing.PathOrder({
            incomingObligationId: incoming,
            outgoingObligationId: outgoing,
            quantity: quantity,
            expiresAt: expiry,
            salt: keccak256(abi.encode(incoming, outgoing, quantity, expiry))
        });
        bytes32 digest = clearing.pathDigest(order);
        settlementId = clearing.createPathInstruction(
            order,
            _sign(A_PK, digest),
            _sign(B_PK, digest),
            _sign(C_PK, digest)
        );
    }

    function test_openPathRedirectAndSettlement() public {
        uint64 dueAB = uint64(block.timestamp + 10 days);
        uint64 dueBC = uint64(block.timestamp + 20 days);
        uint256 aToB = _issue(a, aId, bId, 100_00, dueAB, keccak256("ab"));
        uint256 bToC = _issue(b, bId, cId, 80_00, dueBC, keccak256("bc"));

        bytes32 settlementId = _createPath(aToB, bToC, 80_00, uint64(block.timestamp + 2 days));
        MultilateralClearing.Instruction memory instruction = clearing.getInstruction(settlementId);

        assertEq(instruction.payerPassportId, aId);
        assertEq(instruction.intermediaryPassportId, bId);
        assertEq(instruction.receiverPassportId, cId);
        assertEq(instruction.quantity, 80_00);
        assertEq(instruction.dueDate, dueAB);
        assertEq(obligations.lockedQuantity(aToB), 80_00);
        assertEq(obligations.lockedQuantity(bToC), 80_00);

        bytes32 evidence = keccak256("bank-or-fulfillment-evidence");
        uint64 confirmDeadline = uint64(block.timestamp + 1 days);
        bytes32 confirmDigest = clearing.confirmationDigest(settlementId, evidence, confirmDeadline);
        clearing.confirmPathSettlement(
            settlementId,
            evidence,
            confirmDeadline,
            _sign(B_PK, confirmDigest),
            _sign(C_PK, confirmDigest)
        );

        assertEq(obligations.availableQuantity(aToB), 20_00);
        assertEq(obligations.availableQuantity(bToC), 0);
        assertEq(obligations.lockedQuantity(aToB), 0);
        assertEq(obligations.lockedQuantity(bToC), 0);
        assertEq(uint256(clearing.getInstruction(settlementId).status), uint256(MultilateralClearing.InstructionStatus.SETTLED));
    }

    function test_expiryReleasesBothLocks() public {
        uint256 aToB = _issue(a, aId, bId, 100_00, uint64(block.timestamp + 10 days), keccak256("ab-exp"));
        uint256 bToC = _issue(b, bId, cId, 80_00, uint64(block.timestamp + 10 days), keccak256("bc-exp"));
        uint64 expiry = uint64(block.timestamp + 1 hours);
        bytes32 settlementId = _createPath(aToB, bToC, 50_00, expiry);

        vm.warp(uint256(expiry) + 1);
        clearing.expirePathSettlement(settlementId);

        assertEq(obligations.lockedQuantity(aToB), 0);
        assertEq(obligations.lockedQuantity(bToC), 0);
        assertEq(obligations.availableQuantity(aToB), 100_00);
        assertEq(obligations.availableQuantity(bToC), 80_00);
    }
}
