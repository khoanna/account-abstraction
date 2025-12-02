import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";

import {ERC4337Account} from "../src/Account.sol";
import {PackedUserOperation} from "account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { EntryPoint } from "account-abstraction/contracts/core/EntryPoint.sol";
import {Paymaster} from "../src/Paymaster.sol";
import { SIG_VALIDATION_SUCCESS } from "account-abstraction/contracts/core/Helpers.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract BaseSetup is Test {
    Vm internal constant VM = Vm(VM_ADDRESS);

    ERC4337Account internal account;
    EntryPoint internal entryPoint;
    Paymaster internal paymaster;

    uint256 internal _ownerKey=10;
    address internal _ownerAddress = VM.addr(_ownerKey);

    uint256 internal _aliceKey=1;
    address internal _aliceAddress = VM.addr(_aliceKey);

    uint256 internal _bobKey=2;
    address internal _bobAddress = VM.addr(_bobKey);

    function setUp() public {
        entryPoint = new EntryPoint();
        account = new ERC4337Account(address(entryPoint), _aliceAddress);
        
        VM.prank(_ownerAddress);
        paymaster = new Paymaster(entryPoint);
        VM.stopPrank();

        VM.deal(address(account), 10 ether);
    }
}

contract PaymasterTest is BaseSetup {
    function testAddAndRemoveWhitelist() public {
        bool isWhitelisted = paymaster.checkWhitelist(address(account));
        assertEq(isWhitelisted, false);

        VM.prank(_ownerAddress);
        paymaster.addAddress(address(account));

        isWhitelisted = paymaster.checkWhitelist(address(account));
        assertEq(isWhitelisted, true);

        VM.prank(_ownerAddress);
        paymaster.removeAddress(address(account));

        isWhitelisted = paymaster.checkWhitelist(address(account));
        assertEq(isWhitelisted, false);
    }

    function testValidatePaymasterUserOp() public {
        VM.prank(_ownerAddress);
        paymaster.addAddress(address(account));
        VM.stopPrank();

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

        VM.prank(address(entryPoint));
        (bytes memory context, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, userOpHash, 1000000);
        VM.stopPrank();

        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }
}