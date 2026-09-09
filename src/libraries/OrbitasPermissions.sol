// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

library OrbitasPermissions {
    uint256 internal constant ISSUE_OBLIGATION = 1 << 0;
    uint256 internal constant UPDATE_OBLIGATION_METADATA = 1 << 1;
    uint256 internal constant PROPOSE_SETTLEMENT = 1 << 2;
    uint256 internal constant CONFIRM_SETTLEMENT = 1 << 3;
}
