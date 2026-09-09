// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParticipantPassport} from "./interfaces/IParticipantPassport.sol";
import {IMultidimensionalObligation} from "./interfaces/IMultidimensionalObligation.sol";
import {OrbitasPermissions} from "./libraries/OrbitasPermissions.sol";

/// @title MultilateralClearing
/// @notice Path-enabled A→B→C clearing with a redirect settlement instruction A→C.
/// @dev This contract does not automatically novate source obligations. It locks matched tranches until redirect fulfillment is confirmed or expires.
contract MultilateralClearing is EIP712, ReentrancyGuard {
    bytes32 private constant PATH_TYPEHASH = keccak256(
        "PathOrder(uint256 incomingObligationId,uint256 outgoingObligationId,uint256 quantity,uint64 expiresAt,bytes32 salt)"
    );
    bytes32 private constant CONFIRM_TYPEHASH =
        keccak256("SettlementConfirmation(bytes32 settlementId,bytes32 fulfillmentEvidenceHash,uint64 deadline)");

    enum InstructionStatus {
        NONE,
        PENDING,
        SETTLED,
        EXPIRED
    }

    struct PathOrder {
        uint256 incomingObligationId;
        uint256 outgoingObligationId;
        uint256 quantity;
        uint64 expiresAt;
        bytes32 salt;
    }

    struct Instruction {
        uint256 incomingObligationId;
        uint256 outgoingObligationId;
        uint256 payerPassportId;
        uint256 intermediaryPassportId;
        uint256 receiverPassportId;
        uint256 quantity;
        uint8 decimals;
        IMultidimensionalObligation.ResourceType resourceType;
        bytes32 resourceCode;
        bytes32 unitCode;
        bytes32 currencyCode;
        uint64 dueDate;
        uint64 expiresAt;
        bytes32 consentProofHash;
        bytes32 fulfillmentEvidenceHash;
        InstructionStatus status;
    }

    error Expired();
    error InvalidPath();
    error IncompatibleObligations();
    error InvalidQuantity();
    error UnauthorizedConsent(uint256 passportId, address signer);
    error InstructionExists(bytes32 settlementId);
    error InstructionNotPending(bytes32 settlementId);

    IParticipantPassport public immutable passports;
    IMultidimensionalObligation public immutable obligations;
    mapping(bytes32 => Instruction) private _instructions;

    event SettlementInstructionCreated(
        bytes32 indexed settlementId,
        uint256 indexed payerPassportId,
        uint256 indexed receiverPassportId,
        uint256 intermediaryPassportId,
        uint256 incomingObligationId,
        uint256 outgoingObligationId,
        uint256 quantity,
        uint64 dueDate,
        uint64 expiresAt,
        bytes32 consentProofHash
    );
    event SettlementInstructionStatusChanged(
        bytes32 indexed settlementId, InstructionStatus status, bytes32 fulfillmentEvidenceHash
    );

    constructor(address passportRegistry, address obligationRegistry) EIP712("OrbitasMultilateralClearing", "1") {
        passports = IParticipantPassport(passportRegistry);
        obligations = IMultidimensionalObligation(obligationRegistry);
    }

    /// @notice Create a local A→B→C redirect instruction after A/B/C consent. Same resource dimension only in this MVP contract.
    function createPathInstruction(
        PathOrder calldata order,
        bytes calldata payerSig,
        bytes calldata intermediarySig,
        bytes calldata receiverSig
    ) external nonReentrant returns (bytes32 settlementId) {
        if (block.timestamp > order.expiresAt) revert Expired();
        if (order.quantity == 0) revert InvalidQuantity();

        IMultidimensionalObligation.ObligationView memory incoming =
            obligations.getObligation(order.incomingObligationId);
        IMultidimensionalObligation.ObligationView memory outgoing =
            obligations.getObligation(order.outgoingObligationId);

        uint256 payer = incoming.issuerPassportId;
        uint256 intermediary = incoming.beneficiaryPassportId;
        uint256 receiver = outgoing.beneficiaryPassportId;
        if (
            payer == 0 || intermediary == 0 || receiver == 0 || outgoing.issuerPassportId != intermediary
                || payer == receiver
        ) revert InvalidPath();
        if (!_compatible(incoming, outgoing)) revert IncompatibleObligations();
        if (
            order.quantity > obligations.availableQuantity(order.incomingObligationId)
                || order.quantity > obligations.availableQuantity(order.outgoingObligationId)
        ) revert InvalidQuantity();

        bytes32 digest = _pathDigest(order);
        _checkConsent(payer, ECDSA.recover(digest, payerSig));
        _checkConsent(intermediary, ECDSA.recover(digest, intermediarySig));
        _checkConsent(receiver, ECDSA.recover(digest, receiverSig));

        settlementId = keccak256(abi.encode(block.chainid, address(this), order));
        if (_instructions[settlementId].status != InstructionStatus.NONE) revert InstructionExists(settlementId);
        uint64 dueDate = incoming.dueDate < outgoing.dueDate ? incoming.dueDate : outgoing.dueDate;
        bytes32 consentProofHash = keccak256(abi.encode(digest, payerSig, intermediarySig, receiverSig));

        obligations.lockForSettlement(order.incomingObligationId, settlementId, order.quantity, order.expiresAt);
        obligations.lockForSettlement(order.outgoingObligationId, settlementId, order.quantity, order.expiresAt);

        _instructions[settlementId] = Instruction({
            incomingObligationId: order.incomingObligationId,
            outgoingObligationId: order.outgoingObligationId,
            payerPassportId: payer,
            intermediaryPassportId: intermediary,
            receiverPassportId: receiver,
            quantity: order.quantity,
            decimals: incoming.decimals,
            resourceType: incoming.resourceType,
            resourceCode: incoming.resourceCode,
            unitCode: incoming.unitCode,
            currencyCode: incoming.currencyCode,
            dueDate: dueDate,
            expiresAt: order.expiresAt,
            consentProofHash: consentProofHash,
            fulfillmentEvidenceHash: bytes32(0),
            status: InstructionStatus.PENDING
        });

        emit SettlementInstructionCreated(
            settlementId,
            payer,
            receiver,
            intermediary,
            order.incomingObligationId,
            order.outgoingObligationId,
            order.quantity,
            dueDate,
            order.expiresAt,
            consentProofHash
        );
    }

    /// @notice Confirm redirect fulfillment. Receiver and intermediary both acknowledge that the matched source tranches may be discharged.
    function confirmPathSettlement(
        bytes32 settlementId,
        bytes32 fulfillmentEvidenceHash,
        uint64 confirmationDeadline,
        bytes calldata intermediarySig,
        bytes calldata receiverSig
    ) external nonReentrant {
        Instruction storage i = _instructions[settlementId];
        if (i.status != InstructionStatus.PENDING) revert InstructionNotPending(settlementId);
        if (block.timestamp > i.expiresAt || block.timestamp > confirmationDeadline) revert Expired();
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(CONFIRM_TYPEHASH, settlementId, fulfillmentEvidenceHash, confirmationDeadline))
        );
        _checkConsent(i.intermediaryPassportId, ECDSA.recover(digest, intermediarySig));
        _checkConsent(i.receiverPassportId, ECDSA.recover(digest, receiverSig));

        i.status = InstructionStatus.SETTLED;
        i.fulfillmentEvidenceHash = fulfillmentEvidenceHash;
        obligations.settleLocked(i.incomingObligationId, settlementId, i.quantity, fulfillmentEvidenceHash);
        obligations.settleLocked(i.outgoingObligationId, settlementId, i.quantity, fulfillmentEvidenceHash);
        emit SettlementInstructionStatusChanged(settlementId, InstructionStatus.SETTLED, fulfillmentEvidenceHash);
    }

    /// @notice Release locks after instruction expiry. Anyone may clean up an expired instruction.
    function expirePathSettlement(bytes32 settlementId) external nonReentrant {
        Instruction storage i = _instructions[settlementId];
        if (i.status != InstructionStatus.PENDING) revert InstructionNotPending(settlementId);
        if (block.timestamp <= i.expiresAt) revert Expired();
        i.status = InstructionStatus.EXPIRED;
        obligations.releaseLock(i.incomingObligationId, settlementId);
        obligations.releaseLock(i.outgoingObligationId, settlementId);
        emit SettlementInstructionStatusChanged(settlementId, InstructionStatus.EXPIRED, bytes32(0));
    }

    function getInstruction(bytes32 settlementId) external view returns (Instruction memory) {
        return _instructions[settlementId];
    }

    function pathDigest(PathOrder calldata order) external view returns (bytes32) {
        return _pathDigest(order);
    }

    function confirmationDigest(bytes32 settlementId, bytes32 fulfillmentEvidenceHash, uint64 deadline)
        external
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(keccak256(abi.encode(CONFIRM_TYPEHASH, settlementId, fulfillmentEvidenceHash, deadline)));
    }

    function _pathDigest(PathOrder calldata order) private view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    PATH_TYPEHASH,
                    order.incomingObligationId,
                    order.outgoingObligationId,
                    order.quantity,
                    order.expiresAt,
                    order.salt
                )
            )
        );
    }

    function _compatible(
        IMultidimensionalObligation.ObligationView memory a,
        IMultidimensionalObligation.ObligationView memory b
    ) private pure returns (bool) {
        return a.resourceType == b.resourceType && a.resourceCode == b.resourceCode && a.unitCode == b.unitCode
            && a.currencyCode == b.currencyCode && a.decimals == b.decimals;
    }

    function _checkConsent(uint256 passportId, address signer) private view {
        if (!passports.isAuthorized(passportId, signer, OrbitasPermissions.CONFIRM_SETTLEMENT)) {
            revert UnauthorizedConsent(passportId, signer);
        }
    }
}
