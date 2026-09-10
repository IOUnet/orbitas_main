// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title ParticipantPassport
/// @notice Permissionless SELF_DECLARED company passport registry for Orbitas participants.
contract ParticipantPassport is AccessControl, Pausable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    enum PassportStatus {
        NONE,
        ACTIVE,
        DEACTIVATED
    }

    struct Passport {
        address controller;
        bytes32 metadataHash;
        string metadataURI;
        PassportStatus status;
        uint64 createdAt;
        uint64 updatedAt;
        uint64 operatorEpoch;
    }

    struct OperatorGrant {
        uint64 epoch;
        uint256 permissions;
    }

    error ZeroAddress();
    error EmptyMetadata();
    error ControllerAlreadyRegistered(address controller);
    error PassportNotActive(uint256 passportId);
    error NotPassportController(uint256 passportId, address caller);

    uint256 private _nextPassportId = 1;
    mapping(uint256 => Passport) private _passports;
    mapping(address => uint256) private _passportOfController;
    mapping(uint256 => mapping(address => OperatorGrant)) private _operatorGrants;

    event PassportRegistered(
        uint256 indexed passportId, address indexed controller, bytes32 metadataHash, string metadataURI
    );
    event PassportMetadataUpdated(uint256 indexed passportId, bytes32 oldHash, bytes32 newHash, string newURI);
    event PassportControllerChanged(
        uint256 indexed passportId, address indexed oldController, address indexed newController
    );
    event PassportOperatorPermissionsChanged(
        uint256 indexed passportId, address indexed operator, uint256 permissions, uint64 epoch
    );
    event PassportDeactivated(uint256 indexed passportId);

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /// @notice Self-register a participant passport. Profile verification level is SELF_DECLARED off-chain metadata.
    function registerPassport(bytes32 metadataHash, string calldata metadataURI)
        external
        whenNotPaused
        returns (uint256 passportId)
    {
        if (metadataHash == bytes32(0) || bytes(metadataURI).length == 0) revert EmptyMetadata();
        if (_passportOfController[msg.sender] != 0) revert ControllerAlreadyRegistered(msg.sender);

        passportId = _nextPassportId++;
        uint64 nowTs = uint64(block.timestamp);
        _passports[passportId] = Passport({
            controller: msg.sender,
            metadataHash: metadataHash,
            metadataURI: metadataURI,
            status: PassportStatus.ACTIVE,
            createdAt: nowTs,
            updatedAt: nowTs,
            operatorEpoch: 1
        });
        _passportOfController[msg.sender] = passportId;
        emit PassportRegistered(passportId, msg.sender, metadataHash, metadataURI);
    }

    function updateMetadata(uint256 passportId, bytes32 metadataHash, string calldata metadataURI)
        external
        whenNotPaused
    {
        Passport storage p = _requireController(passportId);
        if (metadataHash == bytes32(0) || bytes(metadataURI).length == 0) revert EmptyMetadata();
        bytes32 oldHash = p.metadataHash;
        p.metadataHash = metadataHash;
        p.metadataURI = metadataURI;
        p.updatedAt = uint64(block.timestamp);
        emit PassportMetadataUpdated(passportId, oldHash, metadataHash, metadataURI);
    }

    /// @notice Rotate participant controller. Operator epoch increments, invalidating all prior grants without enumeration.
    function rotateController(uint256 passportId, address newController) external whenNotPaused {
        if (newController == address(0)) revert ZeroAddress();
        Passport storage p = _requireController(passportId);
        if (_passportOfController[newController] != 0) revert ControllerAlreadyRegistered(newController);
        address old = p.controller;
        _passportOfController[old] = 0;
        _passportOfController[newController] = passportId;
        p.controller = newController;
        p.operatorEpoch += 1;
        p.updatedAt = uint64(block.timestamp);
        emit PassportControllerChanged(passportId, old, newController);
    }

    function setOperatorPermissions(uint256 passportId, address operator, uint256 permissions) external whenNotPaused {
        if (operator == address(0)) revert ZeroAddress();
        Passport storage p = _requireController(passportId);
        _operatorGrants[passportId][operator] = OperatorGrant({epoch: p.operatorEpoch, permissions: permissions});
        emit PassportOperatorPermissionsChanged(passportId, operator, permissions, p.operatorEpoch);
    }

    function deactivatePassport(uint256 passportId) external whenNotPaused {
        Passport storage p = _requireController(passportId);
        p.status = PassportStatus.DEACTIVATED;
        p.updatedAt = uint64(block.timestamp);
        _passportOfController[p.controller] = 0;
        emit PassportDeactivated(passportId);
    }

    function passportOf(address controller) external view returns (uint256) {
        return _passportOfController[controller];
    }

    function isActive(uint256 passportId) public view returns (bool) {
        return _passports[passportId].status == PassportStatus.ACTIVE;
    }

    function isAuthorized(uint256 passportId, address actor, uint256 permission) external view returns (bool) {
        Passport storage p = _passports[passportId];
        if (p.status != PassportStatus.ACTIVE) return false;
        if (actor == p.controller) return true;
        OperatorGrant storage g = _operatorGrants[passportId][actor];
        return g.epoch == p.operatorEpoch && (g.permissions & permission) == permission;
    }

    function getPassport(uint256 passportId)
        external
        view
        returns (
            address controller,
            bytes32 metadataHash,
            string memory metadataURI,
            PassportStatus status,
            uint64 createdAt,
            uint64 updatedAt,
            uint64 operatorEpoch
        )
    {
        Passport storage p = _passports[passportId];
        return (p.controller, p.metadataHash, p.metadataURI, p.status, p.createdAt, p.updatedAt, p.operatorEpoch);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _requireController(uint256 passportId) private view returns (Passport storage p) {
        p = _passports[passportId];
        if (p.status != PassportStatus.ACTIVE) revert PassportNotActive(passportId);
        if (p.controller != msg.sender) revert NotPassportController(passportId, msg.sender);
    }
}
