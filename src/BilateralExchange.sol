// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParticipantPassport} from "./interfaces/IParticipantPassport.sol";
import {IMultidimensionalObligation} from "./interfaces/IMultidimensionalObligation.sol";
import {OrbitasPermissions} from "./libraries/OrbitasPermissions.sol";

/// @title BilateralExchange
/// @notice Atomic reciprocal offset for compatible Orbitas obligations between exactly two participants.
contract BilateralExchange is EIP712, ReentrancyGuard {
    using ECDSA for bytes32;

    bytes32 private constant ORDER_TYPEHASH = keccak256("BilateralOrder(uint256 leftObligationId,uint256 rightObligationId,uint256 quantity,uint64 deadline,bytes32 salt)");

    struct BilateralOrder {
        uint256 leftObligationId;
        uint256 rightObligationId;
        uint256 quantity;
        uint64 deadline;
        bytes32 salt;
    }

    error Expired();
    error InvalidPair();
    error IncompatibleObligations();
    error InvalidQuantity();
    error UnauthorizedConsent(uint256 passportId, address signer);
    error AlreadyExecuted(bytes32 exchangeId);

    IParticipantPassport public immutable passports;
    IMultidimensionalObligation public immutable obligations;
    mapping(bytes32 => bool) public executed;

    event BilateralExchangeSettled(bytes32 indexed exchangeId, uint256 indexed leftObligationId, uint256 indexed rightObligationId, uint256 quantity, uint256 leftPassportId, uint256 rightPassportId);

    constructor(address passportRegistry, address obligationRegistry) EIP712("OrbitasBilateralExchange", "1") {
        passports = IParticipantPassport(passportRegistry);
        obligations = IMultidimensionalObligation(obligationRegistry);
    }

    function settle(BilateralOrder calldata order, bytes calldata leftSignature, bytes calldata rightSignature) external nonReentrant returns (bytes32 exchangeId) {
        if (block.timestamp > order.deadline) revert Expired();
        if (order.quantity == 0) revert InvalidQuantity();
        exchangeId = keccak256(abi.encode(block.chainid, address(this), order));
        if (executed[exchangeId]) revert AlreadyExecuted(exchangeId);

        IMultidimensionalObligation.ObligationView memory left = obligations.getObligation(order.leftObligationId);
        IMultidimensionalObligation.ObligationView memory right = obligations.getObligation(order.rightObligationId);

        if (left.issuerPassportId == 0 || right.issuerPassportId == 0 || left.issuerPassportId != right.beneficiaryPassportId || right.issuerPassportId != left.beneficiaryPassportId) revert InvalidPair();
        if (!_compatible(left, right)) revert IncompatibleObligations();
        if (order.quantity > obligations.availableQuantity(order.leftObligationId) || order.quantity > obligations.availableQuantity(order.rightObligationId)) revert InvalidQuantity();

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(ORDER_TYPEHASH, order.leftObligationId, order.rightObligationId, order.quantity, order.deadline, order.salt)));
        _checkConsent(left.issuerPassportId, ECDSA.recover(digest, leftSignature));
        _checkConsent(right.issuerPassportId, ECDSA.recover(digest, rightSignature));

        executed[exchangeId] = true;
        obligations.lockForSettlement(order.leftObligationId, exchangeId, order.quantity, order.deadline);
        obligations.lockForSettlement(order.rightObligationId, exchangeId, order.quantity, order.deadline);
        obligations.settleLocked(order.leftObligationId, exchangeId, order.quantity, exchangeId);
        obligations.settleLocked(order.rightObligationId, exchangeId, order.quantity, exchangeId);

        emit BilateralExchangeSettled(exchangeId, order.leftObligationId, order.rightObligationId, order.quantity, left.issuerPassportId, right.issuerPassportId);
    }

    function orderDigest(BilateralOrder calldata order) external view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(ORDER_TYPEHASH, order.leftObligationId, order.rightObligationId, order.quantity, order.deadline, order.salt)));
    }

    function _compatible(IMultidimensionalObligation.ObligationView memory a, IMultidimensionalObligation.ObligationView memory b) private pure returns (bool) {
        return a.resourceType == b.resourceType && a.resourceCode == b.resourceCode && a.unitCode == b.unitCode && a.currencyCode == b.currencyCode && a.decimals == b.decimals;
    }

    function _checkConsent(uint256 passportId, address signer) private view {
        if (!passports.isAuthorized(passportId, signer, OrbitasPermissions.CONFIRM_SETTLEMENT)) revert UnauthorizedConsent(passportId, signer);
    }
}
