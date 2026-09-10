// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Test} from "forge-std/Test.sol";
import {ParticipantPassport} from "../src/ParticipantPassport.sol";

contract ParticipantPassportTest is Test {
    ParticipantPassport p;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        p = new ParticipantPassport(address(this));
    }

    function test_permissionlessRegisterAndRotate() public {
        vm.prank(alice);
        uint256 id = p.registerPassport(keccak256("alice"), "ipfs://alice");
        assertEq(id, 1);
        assertEq(p.passportOf(alice), 1);
        vm.prank(alice);
        p.rotateController(id, bob);
        assertEq(p.passportOf(alice), 0);
        assertEq(p.passportOf(bob), id);
    }

    function test_duplicateControllerReverts() public {
        vm.startPrank(alice);
        p.registerPassport(keccak256("a"), "ipfs://a");
        vm.expectRevert();
        p.registerPassport(keccak256("b"), "ipfs://b");
        vm.stopPrank();
    }
}
