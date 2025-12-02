const ethers = require("ethers");
const dotenv = require("dotenv");
const {ENTRY_POINT_ABI, ACCOUNT_ABI, PAYMASTER_ABI} = require("./ABI");
dotenv.config();

const BUNDLER_URL = process.env.BUNDLER_URL;
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "";
const PROVIDER = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL, {
  name: "sepolia",
  chainId: 11155111,
});

const ENTRY_POINT_ADDRESS = "0x0000000071727De22E5E9d8BAf0edAc6f37da032";
const PAYMASTER_ADDRESS = "0x846d83E646B8e740bDe4F5f63C0849208817Cff9";
const ERC4337_ACCOUNT = "0x9dCA2C8DF78752DeA4154B69659e0fc1454f9cB2";

async function checkBalance(address) {
  const entryPoint = new ethers.Contract(
    ENTRY_POINT_ADDRESS,
    ENTRY_POINT_ABI,
    PROVIDER
  );
  const depositInfo = await entryPoint.balanceOf(address);
  console.log("🏦 EntryPoint balance:", ethers.formatEther(depositInfo), "ETH");
  const balance = await PROVIDER.getBalance(address);
  console.log("👛 Account balance:", ethers.formatEther(balance), "ETH");
}

async function stakeForPaymaster() {
  const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL, {
    chainId: 11155111,
    name: "sepolia",
  });
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const paymaster = new ethers.Contract(
    PAYMASTER_ADDRESS,
    PAYMASTER_ABI,
    wallet
  );

  console.log("🚀 Staking for Paymaster:", PAYMASTER_ADDRESS);
  console.log("Executor:", wallet.address);

  const stakeAmount = ethers.parseEther("0.1"); 
  const delaySeconds = 86400; 

  console.log(`⏳ Sending Stake transaction...`);
  console.log(`   - Amount: ${ethers.formatEther(stakeAmount)} ETH`);
  console.log(`   - Delay: ${delaySeconds} seconds`);


  const tx = await paymaster.addStake(delaySeconds, {
    value: stakeAmount,
  });

  console.log("Transaction sent:", tx.hash);
  await tx.wait();

  console.log("✅ Stake successful!");
}

async function main() {
  if (!process.env.PRIVATE_KEY) {
    throw new Error("Missing PRIVATE_KEY in .env");
  }
  if (!BUNDLER_URL) {
    throw new Error("Missing BUNDLER_URL in .env");
  }

  // === Initialize contracts and wallet ===
  const owner = new ethers.Wallet(process.env.PRIVATE_KEY, PROVIDER);
  const entryPoint = new ethers.Contract(
    ENTRY_POINT_ADDRESS,
    ENTRY_POINT_ABI,
    PROVIDER
  );
  const account = new ethers.Contract(ERC4337_ACCOUNT, ACCOUNT_ABI, PROVIDER);
  // ======================================

  // === Build UserOperation ===

  const dest = "0x828e4c8e2d006c3653faf887b9444e9d219ce174";
  const value = ethers.parseEther("0.01");
  const func = "0x";

  const callData = account.interface.encodeFunctionData("execute", [
    dest,
    value,
    func,
  ]);

  const nonce = await entryPoint.getNonce(ERC4337_ACCOUNT, 0n);
  const verificationGasLimit = 60000n;
  const callGasLimit = 200000n;
  const preVerificationGas = 50000n;
  const maxPriorityFeePerGas = 5_000_000_000n;
  const maxFeePerGas = 50_000_000_000n;

  const paymasterAddress = PAYMASTER_ADDRESS;
  const paymasterVerificationGasLimit = 20000n;
  const paymasterPostOpGasLimit = 0n;
  const paymasterData = "0x";

  const accountGasLimits = ethers.solidityPacked(
    ["uint128", "uint128"],
    [verificationGasLimit, callGasLimit]
  );

  const gasFees = ethers.solidityPacked(
    ["uint128", "uint128"],
    [maxPriorityFeePerGas, maxFeePerGas]
  );

  const packedPaymasterAndData = ethers.solidityPacked(
    ["address", "uint128", "uint128", "bytes"],
    [
      paymasterAddress,
      paymasterVerificationGasLimit,
      paymasterPostOpGasLimit,
      paymasterData,
    ]
  );

  const packedUserOpForHash = {
    sender: ERC4337_ACCOUNT,
    nonce: nonce,

    initCode: "0x",

    callData: callData,

    accountGasLimits: accountGasLimits,

    preVerificationGas: preVerificationGas,

    gasFees: gasFees,

    paymasterAndData: packedPaymasterAndData,
    signature: "0x",
  };

  const userOpHash = await entryPoint.getUserOpHash(packedUserOpForHash);
  console.log("userOpHash:", userOpHash);
  const signature = await owner.signMessage(ethers.getBytes(userOpHash));

  const userOpForRpc = {
    sender: ERC4337_ACCOUNT,
    nonce: ethers.toBeHex(nonce),

    callData: callData,

    callGasLimit: ethers.toBeHex(callGasLimit),
    verificationGasLimit: ethers.toBeHex(verificationGasLimit),

    preVerificationGas: ethers.toBeHex(preVerificationGas),

    maxFeePerGas: ethers.toBeHex(maxFeePerGas),
    maxPriorityFeePerGas: ethers.toBeHex(maxPriorityFeePerGas),

    paymaster: PAYMASTER_ADDRESS,
    paymasterVerificationGasLimit: ethers.toBeHex(
      paymasterVerificationGasLimit
    ),
    paymasterPostOpGasLimit: ethers.toBeHex(paymasterPostOpGasLimit),
    paymasterData: paymasterData,

    signature: signature,
  };
  // ======================================

  const jsonRpcPayload = {
    jsonrpc: "2.0",
    id: 1,
    method: "eth_sendUserOperation",
    params: [userOpForRpc, ENTRY_POINT_ADDRESS],
  };

  const response = await fetch(BUNDLER_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(jsonRpcPayload),
  });

  const result = await response.json();

  if (result.error) {
    console.error("❌ Bundler error:", result.error);
  } else {
    console.log("✅ userOperationHash:", result.result);
  }
}

checkBalance(ERC4337_ACCOUNT).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// stakeForPaymaster().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });

// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });
