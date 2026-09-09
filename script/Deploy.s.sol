// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import {Script} from "forge-std/Script.sol";
import {ParticipantPassport} from "../src/ParticipantPassport.sol";
import {MultidimensionalObligation} from "../src/MultidimensionalObligation.sol";
import {BilateralExchange} from "../src/BilateralExchange.sol";
import {MultilateralClearing} from "../src/MultilateralClearing.sol";

contract Deploy is Script {
    function run() external returns (ParticipantPassport passports, MultidimensionalObligation obligations, BilateralExchange bilateral, MultilateralClearing multilateral) {
        address admin = vm.envAddress("ORBITAS_ADMIN");
        vm.startBroadcast();
        passports = new ParticipantPassport(admin);
        obligations = new MultidimensionalObligation(address(passports), admin);
        bilateral = new BilateralExchange(address(passports), address(obligations));
        multilateral = new MultilateralClearing(address(passports), address(obligations));
        obligations.grantRole(obligations.SETTLEMENT_ROLE(), address(bilateral));
        obligations.grantRole(obligations.SETTLEMENT_ROLE(), address(multilateral));
        vm.stopBroadcast();
    }
}
