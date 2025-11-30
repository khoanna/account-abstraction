// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseAccount } from "account-abstraction/contracts/core/BaseAccount.sol";
import { IEntryPoint } from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS } from "account-abstraction/contracts/core/Helpers.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ERC4337Account is BaseAccount {
    IEntryPoint private immutable _i_entryPoint;
    address private immutable _i_owner;

    error Account__CallFailed();

    constructor(address entryPointAddress, address owner) {
        _i_entryPoint = IEntryPoint(entryPointAddress);
        _i_owner = owner;
    }

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal override returns (uint256) {
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address messageSigner = ECDSA.recover(digest, userOp.signature);
        if (messageSigner == _i_owner) {
            return SIG_VALIDATION_SUCCESS;
        } else {
            return SIG_VALIDATION_FAILED;
        }
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata funcCallData
    ) override external {
        _requireFromEntryPoint();
        (bool success, ) = dest.call{value: value}(funcCallData);
        if (!success) {
            revert Account__CallFailed();
        }
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _i_entryPoint;
    }

    function getOwner() public view returns (address) {
        return _i_owner;
    }

    receive() external payable {}

    fallback() external payable {}
}
