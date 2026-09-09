// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ParticipantPassport} from "../src/ParticipantPassport.sol";
import {MultidimensionalObligation} from "../src/MultidimensionalObligation.sol";
import {OrbitasPermissions} from "../src/libraries/OrbitasPermissions.sol";

contract ObligationHandler {
    MultidimensionalObligation public immutable obligations;
    uint256 public immutable obligationId;

    bytes32 public activeSettlementId;
    uint256 public activeLockQuantity;
    uint256 private nonce;

    constructor(MultidimensionalObligation obligations_, uint256 obligationId_) {
        obligations = obligations_;
        obligationId = obligationId_;
    }

    function lock(uint256 rawQuantity) external {
        if (activeLockQuantity != 0) return;
        MultidimensionalObligation.Obligation memory o = obligations.getObligation(obligationId);
        if (o.status != MultidimensionalObligation.ObligationStatus.ACTIVE) return;
        uint256 available = obligations.availableQuantity(obligationId);
        if (available == 0) return;

        uint256 quantity = _bound(rawQuantity, 1, available);
        bytes32 sid = keccak256(abi.encode(address(this), ++nonce));
        obligations.lockForSettlement(obligationId, sid, quantity, uint64(block.timestamp + 365 days));
        activeSettlementId = sid;
        activeLockQuantity = quantity;
    }

    function settle(uint256 rawQuantity) external {
        if (activeLockQuantity == 0) return;
        uint256 quantity = _bound(rawQuantity, 1, activeLockQuantity);
        obligations.settleLocked(obligationId, activeSettlementId, quantity, keccak256("invariant-evidence"));
        activeLockQuantity -= quantity;
        if (activeLockQuantity == 0) activeSettlementId = bytes32(0);
    }

    function release() external {
        if (activeLockQuantity == 0) return;
        obligations.releaseLock(obligationId, activeSettlementId);
        activeSettlementId = bytes32(0);
        activeLockQuantity = 0;
    }

    function cancelResidual() external {
        if (activeLockQuantity != 0) return;
        MultidimensionalObligation.Obligation memory o = obligations.getObligation(obligationId);
        if (o.status != MultidimensionalObligation.ObligationStatus.ACTIVE) return;
        obligations.cancelResidual(obligationId);
    }

    function _bound(uint256 x, uint256 minValue, uint256 maxValue) private pure returns (uint256) {
        if (minValue == maxValue) return minValue;
        return minValue + (x % (maxValue - minValue + 1));
    }
}

contract ObligationInvariantTest is StdInvariant, Test {
    ParticipantPassport internal passports;
    MultidimensionalObligation internal obligations;
    ObligationHandler internal handler;

    uint256 internal constant ALICE_PK = 0xA11CE;
    address internal alice;
    uint256 internal aliceId;
    uint256 internal bobId;
    uint256 internal obligationId;

    function setUp() public {
        alice = vm.addr(ALICE_PK);
        address bob = vm.addr(0xB0B);

        passports = new ParticipantPassport(address(this));
        obligations = new MultidimensionalObligation(address(passports), address(this));

        vm.prank(alice);
        aliceId = passports.registerPassport(keccak256("alice"), "ipfs://alice");
        vm.prank(bob);
        bobId = passports.registerPassport(keccak256("bob"), "ipfs://bob");

        MultidimensionalObligation.IssueInput memory input = MultidimensionalObligation.IssueInput({
            issuerPassportId: aliceId,
            beneficiaryPassportId: bobId,
            externalCounterpartyHash: bytes32(0),
            resourceType: MultidimensionalObligation.ResourceType.MONETARY,
            resourceCode: bytes32("BRL"),
            unitCode: bytes32("BRL"),
            currencyCode: bytes32("BRL"),
            quantity: 1_000_000,
            decimals: 2,
            dueDate: uint64(block.timestamp + 365 days),
            propertiesHash: keccak256("props"),
            propertiesURI: "ipfs://props",
            sourceRefHash: keccak256("invariant-source"),
            evidenceHash: keccak256("evidence"),
            metadataHash: keccak256("metadata"),
            metadataURI: "ipfs://metadata",
            qualitySchemaHash: keccak256("quality-v1")
        });
        vm.prank(alice);
        obligationId = obligations.issueObligation(input);

        handler = new ObligationHandler(obligations, obligationId);
        obligations.grantRole(obligations.SETTLEMENT_ROLE(), address(handler));
        vm.prank(alice);
        passports.setOperatorPermissions(aliceId, address(handler), OrbitasPermissions.UPDATE_OBLIGATION_METADATA);

        targetContract(address(handler));
    }

    function invariant_conservationOfQuantity() public view {
        MultidimensionalObligation.Obligation memory o = obligations.getObligation(obligationId);
        uint256 locked = obligations.lockedQuantity(obligationId);
        assertLe(o.settledQuantity + o.cancelledQuantity + locked, o.totalQuantity);
        assertEq(obligations.outstandingQuantity(obligationId), o.totalQuantity - o.settledQuantity - o.cancelledQuantity);
        assertEq(obligations.availableQuantity(obligationId) + locked, obligations.outstandingQuantity(obligationId));
    }
}
