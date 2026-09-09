// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

interface IMultidimensionalObligation {
    enum ResourceType { MONETARY, GOODS, SERVICE }
    enum ObligationStatus { NONE, ACTIVE, SETTLED, CANCELLED }

    struct ObligationView {
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

    function getObligation(uint256 obligationId) external view returns (ObligationView memory);
    function availableQuantity(uint256 obligationId) external view returns (uint256);
    function lockedQuantity(uint256 obligationId) external view returns (uint256);
    function lockForSettlement(uint256 obligationId, bytes32 settlementId, uint256 quantity, uint64 expiresAt) external;
    function releaseLock(uint256 obligationId, bytes32 settlementId) external;
    function settleLocked(uint256 obligationId, bytes32 settlementId, uint256 quantity, bytes32 fulfillmentEvidenceHash) external;
}
