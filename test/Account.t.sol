// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ERC4337Account} from "../src/Account.sol";
import {PackedUserOperation} from "account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { EntryPoint } from "account-abstraction/contracts/core/EntryPoint.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SIG_VALIDATION_SUCCESS } from "account-abstraction/contracts/core/Helpers.sol";

contract AccountWithExposedValidateSignature is ERC4337Account {
    constructor(address entryPointAddress, address owner) ERC4337Account(entryPointAddress, owner) {}

    function validateSignatureExposed(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external view returns (uint256) {
        return _validateSignature(userOp, userOpHash);
    }
}

contract BaseSetup is Test {
    Vm internal constant VM = Vm(VM_ADDRESS);

    AccountWithExposedValidateSignature internal account;
    EntryPoint internal entryPoint;

    uint256 internal _aliceKey=1;
    address internal _aliceAddress = VM.addr(_aliceKey);

    uint256 internal _bobKey=2;
    address internal _bobAddress = VM.addr(_bobKey);

    function setUp() public {
        entryPoint = new EntryPoint();
        account = new AccountWithExposedValidateSignature(address(entryPoint), _aliceAddress);
        VM.deal(address(account), 10 ether);
    }
}

contract AccountTest is BaseSetup {
    function testStateVariable() public {
        address owner = account.getOwner();
        address entryPointAddress = address(account.entryPoint());

        assertEq(owner, _aliceAddress);
        assertEq(entryPointAddress, address(entryPoint));
    }

    function testExecuteFunction() public {
        uint256 bobInitialBalance = address(_bobAddress).balance;

        address dest = _bobAddress;
        uint256 value = 1 ether;
        bytes memory funcCallData = "";

        VM.prank(address(entryPoint));
        account.execute(dest, value, funcCallData);

        uint256 bobFinalBalance = address(_bobAddress).balance;
        assertEq(bobFinalBalance, bobInitialBalance + value);

        uint256 accountFinalBalance = address(account).balance;
        assertEq(accountFinalBalance, 9 ether);
    }

    function testSignatureValidation() public {
        PackedUserOperation memory userOp = PackedUserOperation({
            sender: address(account),
            nonce: 1,
            initCode: hex"",
            callData: hex"",
            accountGasLimits: hex"",
            preVerificationGas: type(uint64).max,
            gasFees: hex"",
            paymasterAndData: hex"",
            signature: hex""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        bytes32 formattedUserOpHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        (uint8 v, bytes32 r, bytes32 s) = VM.sign(
            _aliceKey,
            formattedUserOpHash
        );

        userOp.signature = abi.encodePacked(r, s, v);

        uint256 validationResult = account.validateSignatureExposed(userOp, userOpHash);
        assertEq(validationResult, SIG_VALIDATION_SUCCESS);
    }
}
