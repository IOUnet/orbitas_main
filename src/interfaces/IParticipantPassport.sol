// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @notice Read-only participant passport interface consumed by Orbitas protocol contracts.
interface IParticipantPassport {
    function getPassport(uint256 passportId) external view returns (
        address controller,
        bytes32 metadataHash,
        string memory metadataURI,
        uint8 status,
        uint64 createdAt,
        uint64 updatedAt,
        uint64 operatorEpoch
    );

    function passportOf(address controller) external view returns (uint256);
    function isActive(uint256 passportId) external view returns (bool);
    function isAuthorized(uint256 passportId, address actor, uint256 permission) external view returns (bool);
}
