// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BasePaymaster} from "account-abstraction/contracts/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "account-abstraction/contracts/core/Helpers.sol";

contract Paymaster is BasePaymaster {
    mapping(address => bool) private _whitelist;

    constructor(IEntryPoint entryPoint) BasePaymaster(entryPoint, msg.sender) {}

    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        internal
        view
        override
        returns (bytes memory context, uint256 validationData)
    {
        (userOpHash, maxCost);
        address user = userOp.sender;

        context = hex"";

        if (_whitelist[user]) {
            validationData = SIG_VALIDATION_SUCCESS;
            return (context, validationData);
        } else {
            validationData = SIG_VALIDATION_FAILED;
            return (context, validationData);
        }
    }

    function addAddress(address user) external onlyOwner {
        _whitelist[user] = true;
    }

    function removeAddress(address user) external onlyOwner {
        _whitelist[user] = false;
    }

    function checkWhitelist(address user) external view returns (bool) {
        return _whitelist[user];
    }
}
