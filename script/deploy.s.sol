// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC4337Account} from "../src/Account.sol";
import { IEntryPoint } from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { Paymaster } from "../src/Paymaster.sol";

contract AccountScript is Script {
    ERC4337Account public account;

    function setUp() public {}

    address constant ENTRY_POINT_ADDRESS = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    address constant OWNER_ACCOUNT = 0xd5de8324D526A201672B30584e495C71BeBb3e9A;

    function run() public {
        vm.startBroadcast();

        account = new ERC4337Account(ENTRY_POINT_ADDRESS, OWNER_ACCOUNT);

        vm.stopBroadcast();
    }
}

contract PaymasterScript is Script {
    IEntryPoint constant entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

    function run() public {
        vm.startBroadcast();
        bytes4 epId = type(IEntryPoint).interfaceId;
        Paymaster paymaster = new Paymaster(entryPoint);
        vm.stopBroadcast();
    }
}

contract DepositToEntryPointScript is Script {
    IEntryPoint constant entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

    function run() public {
        vm.startBroadcast();
        entryPoint.depositTo{value: 0.1 ether}(0x9dCA2C8DF78752DeA4154B69659e0fc1454f9cB2);
        vm.stopBroadcast();
    }
}

contract DepositAndWhitelistScript is Script {
    IEntryPoint constant entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
    Paymaster constant paymaster = Paymaster(0x846d83E646B8e740bDe4F5f63C0849208817Cff9);

    function run() public {
        vm.startBroadcast();
        entryPoint.depositTo{value: 0.1 ether}(0x846d83E646B8e740bDe4F5f63C0849208817Cff9);
        paymaster.addAddress(0x9dCA2C8DF78752DeA4154B69659e0fc1454f9cB2);
        vm.stopBroadcast();
    }
}
