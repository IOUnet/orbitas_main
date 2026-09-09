// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IParticipantPassport} from "./interfaces/IParticipantPassport.sol";
import {OrbitasPermissions} from "./libraries/OrbitasPermissions.sol";

/// @title MultidimensionalObligation
/// @notice On-chain tokenized obligation registry. Token identity is `obligationId`; quantity is integer/fixed-decimal.
/// @dev Conceptual token model is T=(R,Q,S): resource/properties, quality observations/claims, stake/guarantee signals.
contract MultidimensionalObligation is AccessControl, Pausable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SETTLEMENT_ROLE = keccak256("SETTLEMENT_ROLE");
    bytes32 public constant QUALITY_ATTESTOR_ROLE = keccak256("QUALITY_ATTESTOR_ROLE");
    bytes32 public constant GUARANTEE_REGISTRY_ROLE = keccak256("GUARANTEE_REGISTRY_ROLE");

    enum ResourceType {
        MONETARY,
        GOODS,
        SERVICE
    }
    enum ObligationStatus {
        NONE,
        ACTIVE,
        SETTLED,
        CANCELLED
    }
    enum QualityValueType {
        UINT,
        INT,
        BOOL,
        ENUM_HASH
    }
    enum ComparisonOperator {
        EQ,
        NE,
        GT,
        GTE,
        LT,
        LTE
    }
    enum StakeSide {
        FOR,
        AGAINST
    }

    struct Obligation {
        uint256 issuerPassportId;
        uint256 beneficiaryPassportId;
        bytes32 externalCounterpartyHash;
        ResourceType resourceType;
        bytes32 resourceCode;
        bytes32 unitCode;
        bytes32 currencyCode;
        uint256 totalQuantity;
        uint256 settledQuantity;
        uint256 cancelledQuantity;
        uint8 decimals;
        uint64 dueDate;
        bytes32 propertiesHash;
        string propertiesURI;
        bytes32 sourceRefHash;
        bytes32 evidenceHash;
        bytes32 metadataHash;
        string metadataURI;
        bytes32 qualitySchemaHash;
        ObligationStatus status;
        uint64 createdAt;
    }

    struct IssueInput {
        uint256 issuerPassportId;
        uint256 beneficiaryPassportId;
        bytes32 externalCounterpartyHash;
        ResourceType resourceType;
        bytes32 resourceCode;
        bytes32 unitCode;
        bytes32 currencyCode;
        uint256 quantity;
        uint8 decimals;
        uint64 dueDate;
        bytes32 propertiesHash;
        string propertiesURI;
        bytes32 sourceRefHash;
        bytes32 evidenceHash;
        bytes32 metadataHash;
        string metadataURI;
        bytes32 qualitySchemaHash;
    }

    struct Lock {
        uint256 quantity;
        uint64 expiresAt;
    }

    struct QualityObservation {
        QualityValueType valueType;
        bytes32 encodedValue;
        uint8 decimals;
        bytes32 sourceType;
        bytes32 evidenceHash;
        uint64 observedAt;
        uint64 validUntil;
        uint32 observationCount;
        uint32 confidencePpm;
    }

    struct QualityClaim {
        uint256 obligationId;
        bytes32 qualityKey;
        ComparisonOperator operator;
        int256 threshold;
        uint8 decimals;
        bytes32 contextHash;
        uint64 validUntil;
        bytes32 evidenceHash;
        bytes32 resolution;
        bool resolved;
    }

    struct StakeSummary {
        uint256 forAmount;
        uint256 againstAmount;
    }

    error ZeroAddress();
    error InvalidQuantity();
    error InvalidEvidence();
    error InvalidCounterparty();
    error DuplicateSourceRef(bytes32 sourceRefHash, uint256 existingObligationId);
    error UnauthorizedParticipant(uint256 passportId, address actor, uint256 permission);
    error ObligationNotActive(uint256 obligationId);
    error InsufficientAvailable(uint256 obligationId, uint256 requested, uint256 available);
    error LockExists(uint256 obligationId, bytes32 settlementId);
    error LockNotFound(uint256 obligationId, bytes32 settlementId);
    error LockExpired(uint256 obligationId, bytes32 settlementId);
    error LockStillActive(uint256 obligationId, bytes32 settlementId);
    error ActiveLocksExist(uint256 obligationId);
    error InvalidConfidence(uint32 confidencePpm);
    error ClaimExists(bytes32 claimId);
    error ClaimNotFound(bytes32 claimId);
    error ClaimAlreadyResolved(bytes32 claimId);

    IParticipantPassport public immutable passportRegistry;
    uint256 private _nextObligationId = 1;

    mapping(uint256 => Obligation) private _obligations;
    mapping(bytes32 => uint256) public obligationBySourceRef;
    mapping(uint256 => uint256) private _totalLocked;
    mapping(uint256 => mapping(bytes32 => Lock)) private _locks;

    mapping(uint256 => mapping(bytes32 => QualityObservation)) private _qualityObservations;
    mapping(bytes32 => QualityClaim) private _qualityClaims;
    mapping(bytes32 => mapping(address => StakeSummary)) private _stakeSummaries;

    event ObligationIssued(
        uint256 indexed obligationId,
        uint256 indexed issuerPassportId,
        uint256 indexed beneficiaryPassportId,
        bytes32 externalCounterpartyHash,
        ResourceType resourceType,
        bytes32 resourceCode,
        bytes32 unitCode,
        bytes32 currencyCode,
        uint256 totalQuantity,
        uint8 decimals,
        uint64 dueDate,
        bytes32 sourceRefHash,
        bytes32 evidenceHash,
        bytes32 propertiesHash,
        bytes32 metadataHash,
        bytes32 qualitySchemaHash,
        string metadataURI,
        string propertiesURI
    );
    event ObligationLocked(
        uint256 indexed obligationId, bytes32 indexed settlementId, uint256 quantity, uint64 expiresAt
    );
    event ObligationLockReleased(uint256 indexed obligationId, bytes32 indexed settlementId, uint256 quantity);
    event ObligationSettled(
        uint256 indexed obligationId,
        bytes32 indexed settlementId,
        uint256 quantity,
        uint256 remainingQuantity,
        bytes32 fulfillmentEvidenceHash
    );
    event ObligationCancelled(uint256 indexed obligationId, uint256 cancelledQuantity, uint256 settledQuantity);
    event ObligationMetadataUpdated(uint256 indexed obligationId, bytes32 oldHash, bytes32 newHash, string newURI);
    event QualityObservationRecorded(
        uint256 indexed obligationId,
        bytes32 indexed qualityKey,
        bytes32 encodedValue,
        uint8 decimals,
        bytes32 sourceType,
        bytes32 evidenceHash,
        uint64 observedAt,
        uint64 validUntil,
        uint32 observationCount,
        uint32 confidencePpm
    );
    event QualityClaimCreated(
        bytes32 indexed claimId,
        uint256 indexed obligationId,
        bytes32 indexed qualityKey,
        ComparisonOperator operator,
        int256 threshold,
        uint8 decimals,
        bytes32 contextHash,
        uint64 validUntil,
        bytes32 evidenceHash
    );
    event QualityClaimResolved(bytes32 indexed claimId, bytes32 resolution, bytes32 evidenceHash);
    event QualityStakeSignalChanged(
        bytes32 indexed claimId,
        uint256 indexed stakerPassportId,
        address indexed collateralToken,
        StakeSide side,
        uint256 amount,
        uint256 newForAmount,
        uint256 newAgainstAmount,
        address sourceRegistry
    );

    constructor(address passportRegistry_, address admin) {
        if (passportRegistry_ == address(0) || admin == address(0)) revert ZeroAddress();
        passportRegistry = IParticipantPassport(passportRegistry_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function issueObligation(IssueInput calldata input) external whenNotPaused returns (uint256 obligationId) {
        if (
            !passportRegistry.isActive(input.issuerPassportId)
                || !passportRegistry.isAuthorized(
                    input.issuerPassportId, msg.sender, OrbitasPermissions.ISSUE_OBLIGATION
                )
        ) {
            revert UnauthorizedParticipant(input.issuerPassportId, msg.sender, OrbitasPermissions.ISSUE_OBLIGATION);
        }
        if (input.quantity == 0) revert InvalidQuantity();
        if (input.sourceRefHash == bytes32(0) || input.evidenceHash == bytes32(0) || input.propertiesHash == bytes32(0))
        {
            revert InvalidEvidence();
        }
        if (input.beneficiaryPassportId == 0 && input.externalCounterpartyHash == bytes32(0)) {
            revert InvalidCounterparty();
        }
        if (input.beneficiaryPassportId != 0 && !passportRegistry.isActive(input.beneficiaryPassportId)) {
            revert InvalidCounterparty();
        }
        uint256 existing = obligationBySourceRef[input.sourceRefHash];
        if (existing != 0) revert DuplicateSourceRef(input.sourceRefHash, existing);

        obligationId = _nextObligationId++;
        _obligations[obligationId] = Obligation({
            issuerPassportId: input.issuerPassportId,
            beneficiaryPassportId: input.beneficiaryPassportId,
            externalCounterpartyHash: input.externalCounterpartyHash,
            resourceType: input.resourceType,
            resourceCode: input.resourceCode,
            unitCode: input.unitCode,
            currencyCode: input.currencyCode,
            totalQuantity: input.quantity,
            settledQuantity: 0,
            cancelledQuantity: 0,
            decimals: input.decimals,
            dueDate: input.dueDate,
            propertiesHash: input.propertiesHash,
            propertiesURI: input.propertiesURI,
            sourceRefHash: input.sourceRefHash,
            evidenceHash: input.evidenceHash,
            metadataHash: input.metadataHash,
            metadataURI: input.metadataURI,
            qualitySchemaHash: input.qualitySchemaHash,
            status: ObligationStatus.ACTIVE,
            createdAt: uint64(block.timestamp)
        });
        obligationBySourceRef[input.sourceRefHash] = obligationId;
        emit ObligationIssued(
            obligationId,
            input.issuerPassportId,
            input.beneficiaryPassportId,
            input.externalCounterpartyHash,
            input.resourceType,
            input.resourceCode,
            input.unitCode,
            input.currencyCode,
            input.quantity,
            input.decimals,
            input.dueDate,
            input.sourceRefHash,
            input.evidenceHash,
            input.propertiesHash,
            input.metadataHash,
            input.qualitySchemaHash,
            input.metadataURI,
            input.propertiesURI
        );
    }

    function updateMetadata(uint256 obligationId, bytes32 metadataHash, string calldata metadataURI)
        external
        whenNotPaused
    {
        Obligation storage o = _requireActive(obligationId);
        if (!passportRegistry.isAuthorized(
                o.issuerPassportId, msg.sender, OrbitasPermissions.UPDATE_OBLIGATION_METADATA
            )) {
            revert UnauthorizedParticipant(
                o.issuerPassportId, msg.sender, OrbitasPermissions.UPDATE_OBLIGATION_METADATA
            );
        }
        bytes32 oldHash = o.metadataHash;
        o.metadataHash = metadataHash;
        o.metadataURI = metadataURI;
        emit ObligationMetadataUpdated(obligationId, oldHash, metadataHash, metadataURI);
    }

    function lockForSettlement(uint256 obligationId, bytes32 settlementId, uint256 quantity, uint64 expiresAt)
        external
        onlyRole(SETTLEMENT_ROLE)
        whenNotPaused
    {
        _requireActive(obligationId);
        if (quantity == 0 || settlementId == bytes32(0) || expiresAt <= block.timestamp) revert InvalidQuantity();
        if (_locks[obligationId][settlementId].quantity != 0) revert LockExists(obligationId, settlementId);
        uint256 available = availableQuantity(obligationId);
        if (quantity > available) revert InsufficientAvailable(obligationId, quantity, available);
        _locks[obligationId][settlementId] = Lock(quantity, expiresAt);
        _totalLocked[obligationId] += quantity;
        emit ObligationLocked(obligationId, settlementId, quantity, expiresAt);
    }

    function releaseLock(uint256 obligationId, bytes32 settlementId) external onlyRole(SETTLEMENT_ROLE) {
        Lock memory l = _locks[obligationId][settlementId];
        if (l.quantity == 0) revert LockNotFound(obligationId, settlementId);
        delete _locks[obligationId][settlementId];
        _totalLocked[obligationId] -= l.quantity;
        emit ObligationLockReleased(obligationId, settlementId, l.quantity);
    }

    function settleLocked(uint256 obligationId, bytes32 settlementId, uint256 quantity, bytes32 fulfillmentEvidenceHash)
        external
        onlyRole(SETTLEMENT_ROLE)
        whenNotPaused
    {
        Obligation storage o = _requireActive(obligationId);
        Lock storage l = _locks[obligationId][settlementId];
        if (l.quantity == 0) revert LockNotFound(obligationId, settlementId);
        if (block.timestamp > l.expiresAt) revert LockExpired(obligationId, settlementId);
        if (quantity == 0 || quantity > l.quantity) revert InvalidQuantity();

        l.quantity -= quantity;
        _totalLocked[obligationId] -= quantity;
        if (l.quantity == 0) delete _locks[obligationId][settlementId];
        o.settledQuantity += quantity;
        if (outstandingQuantity(obligationId) == 0) o.status = ObligationStatus.SETTLED;
        emit ObligationSettled(
            obligationId, settlementId, quantity, outstandingQuantity(obligationId), fulfillmentEvidenceHash
        );
    }

    function cancelResidual(uint256 obligationId) external whenNotPaused {
        Obligation storage o = _requireActive(obligationId);
        if (!passportRegistry.isAuthorized(
                o.issuerPassportId, msg.sender, OrbitasPermissions.UPDATE_OBLIGATION_METADATA
            )) {
            revert UnauthorizedParticipant(
                o.issuerPassportId, msg.sender, OrbitasPermissions.UPDATE_OBLIGATION_METADATA
            );
        }
        if (_totalLocked[obligationId] != 0) revert ActiveLocksExist(obligationId);
        uint256 residual = outstandingQuantity(obligationId);
        o.cancelledQuantity += residual;
        o.status = ObligationStatus.CANCELLED;
        emit ObligationCancelled(obligationId, o.cancelledQuantity, o.settledQuantity);
    }

    /// @notice Record an evidence-derived quality observation. Stake is not allowed to mutate this value.
    function recordQualityObservation(
        uint256 obligationId,
        bytes32 qualityKey,
        QualityValueType valueType,
        bytes32 encodedValue,
        uint8 decimals,
        bytes32 sourceType,
        bytes32 evidenceHash,
        uint64 validUntil,
        uint32 observationCount,
        uint32 confidencePpm
    ) external whenNotPaused {
        Obligation storage o = _requireActive(obligationId);
        bool issuerAuthorized = passportRegistry.isAuthorized(
            o.issuerPassportId, msg.sender, OrbitasPermissions.UPDATE_OBLIGATION_METADATA
        );
        if (!issuerAuthorized && !hasRole(QUALITY_ATTESTOR_ROLE, msg.sender)) {
            revert UnauthorizedParticipant(
                o.issuerPassportId, msg.sender, OrbitasPermissions.UPDATE_OBLIGATION_METADATA
            );
        }
        if (confidencePpm > 1_000_000) revert InvalidConfidence(confidencePpm);
        uint64 nowTs = uint64(block.timestamp);
        _qualityObservations[obligationId][qualityKey] = QualityObservation(
            valueType,
            encodedValue,
            decimals,
            sourceType,
            evidenceHash,
            nowTs,
            validUntil,
            observationCount,
            confidencePpm
        );
        emit QualityObservationRecorded(
            obligationId,
            qualityKey,
            encodedValue,
            decimals,
            sourceType,
            evidenceHash,
            nowTs,
            validUntil,
            observationCount,
            confidencePpm
        );
    }

    function createQualityClaim(
        uint256 obligationId,
        bytes32 qualityKey,
        ComparisonOperator operator,
        int256 threshold,
        uint8 decimals,
        bytes32 contextHash,
        uint64 validUntil,
        bytes32 evidenceHash,
        bytes32 salt
    ) external whenNotPaused returns (bytes32 claimId) {
        Obligation storage o = _requireActive(obligationId);
        if (!passportRegistry.isAuthorized(
                o.issuerPassportId, msg.sender, OrbitasPermissions.UPDATE_OBLIGATION_METADATA
            )) {
            revert UnauthorizedParticipant(
                o.issuerPassportId, msg.sender, OrbitasPermissions.UPDATE_OBLIGATION_METADATA
            );
        }
        claimId = keccak256(
            abi.encode(
                block.chainid,
                address(this),
                obligationId,
                qualityKey,
                operator,
                threshold,
                decimals,
                contextHash,
                validUntil,
                salt
            )
        );
        if (_qualityClaims[claimId].obligationId != 0) revert ClaimExists(claimId);
        _qualityClaims[claimId] = QualityClaim(
            obligationId,
            qualityKey,
            operator,
            threshold,
            decimals,
            contextHash,
            validUntil,
            evidenceHash,
            bytes32(0),
            false
        );
        emit QualityClaimCreated(
            claimId, obligationId, qualityKey, operator, threshold, decimals, contextHash, validUntil, evidenceHash
        );
    }

    function resolveQualityClaim(bytes32 claimId, bytes32 resolution, bytes32 evidenceHash)
        external
        onlyRole(QUALITY_ATTESTOR_ROLE)
        whenNotPaused
    {
        QualityClaim storage c = _qualityClaims[claimId];
        if (c.obligationId == 0) revert ClaimNotFound(claimId);
        if (c.resolved) revert ClaimAlreadyResolved(claimId);
        c.resolved = true;
        c.resolution = resolution;
        emit QualityClaimResolved(claimId, resolution, evidenceHash);
    }

    /// @notice Hook for a separately approved guarantee registry. This records S without custody/slashing logic here.
    function recordQualityStakeSignal(
        bytes32 claimId,
        uint256 stakerPassportId,
        address collateralToken,
        StakeSide side,
        uint256 amount
    ) external onlyRole(GUARANTEE_REGISTRY_ROLE) whenNotPaused {
        if (_qualityClaims[claimId].obligationId == 0) revert ClaimNotFound(claimId);
        StakeSummary storage s = _stakeSummaries[claimId][collateralToken];
        if (side == StakeSide.FOR) s.forAmount = amount;
        else s.againstAmount = amount;
        emit QualityStakeSignalChanged(
            claimId, stakerPassportId, collateralToken, side, amount, s.forAmount, s.againstAmount, msg.sender
        );
    }

    function getObligation(uint256 obligationId) external view returns (Obligation memory) {
        return _obligations[obligationId];
    }

    function getQualityObservation(uint256 obligationId, bytes32 qualityKey)
        external
        view
        returns (QualityObservation memory)
    {
        return _qualityObservations[obligationId][qualityKey];
    }

    function getQualityClaim(bytes32 claimId) external view returns (QualityClaim memory) {
        return _qualityClaims[claimId];
    }

    function getStakeSummary(bytes32 claimId, address collateralToken) external view returns (StakeSummary memory) {
        return _stakeSummaries[claimId][collateralToken];
    }

    function lockedQuantity(uint256 obligationId) external view returns (uint256) {
        return _totalLocked[obligationId];
    }

    function outstandingQuantity(uint256 obligationId) public view returns (uint256) {
        Obligation storage o = _obligations[obligationId];
        return o.totalQuantity - o.settledQuantity - o.cancelledQuantity;
    }

    function availableQuantity(uint256 obligationId) public view returns (uint256) {
        return outstandingQuantity(obligationId) - _totalLocked[obligationId];
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _requireActive(uint256 obligationId) private view returns (Obligation storage o) {
        o = _obligations[obligationId];
        if (o.status != ObligationStatus.ACTIVE) revert ObligationNotActive(obligationId);
    }
}
