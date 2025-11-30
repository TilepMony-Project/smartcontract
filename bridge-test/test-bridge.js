const { createWalletClient, createPublicClient, http, parseEther, parseUnits } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { mantleSepoliaTestnet } = require('viem/chains');
const dotenv = require('dotenv');
const fs = require('fs');
const path = require('path');

// Load environment variables from .env file in this directory
dotenv.config();

// Configuration
const RPC_URL = process.env.RPC_URL || 'https://rpc.sepolia.mantle.xyz';
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const BRIDGE_LAYER_ADDRESS = process.env.BRIDGE_LAYER_ADDRESS;
const AXELAR_ADAPTER_ADDRESS = process.env.AXELAR_ADAPTER_ADDRESS;
const TOKEN_ADDRESS = process.env.TOKEN_ADDRESS; // Fallback or specific override
const MIDRX_ADDRESS = process.env.MIDRX_ADDRESS;
const MUSDT_ADDRESS = process.env.MUSDT_ADDRESS;
const MUSDC_ADDRESS = process.env.MUSDC_ADDRESS;

if (!PRIVATE_KEY) {
    console.error('Error: PRIVATE_KEY not found in .env');
    console.error('Please create a .env file in this folder with PRIVATE_KEY, BRIDGE_LAYER_ADDRESS, etc.');
    process.exit(1);
}

if (!BRIDGE_LAYER_ADDRESS) {
    console.error('Error: BRIDGE_LAYER_ADDRESS not found in .env');
    process.exit(1);
}

const account = privateKeyToAccount(PRIVATE_KEY);

const client = createWalletClient({
    account,
    chain: mantleSepoliaTestnet,
    transport: http(RPC_URL),
});

const publicClient = createPublicClient({
    chain: mantleSepoliaTestnet,
    transport: http(RPC_URL),
});

// Load ABIs from the parent directory's out folder
const bridgeLayerArtifactPath = path.join(__dirname, '../out/BridgeLayer.sol/BridgeLayer.json');

if (!fs.existsSync(bridgeLayerArtifactPath)) {
    console.error(`Error: ABI not found at ${bridgeLayerArtifactPath}`);
    console.error('Make sure you have compiled the smart contracts with "forge build"');
    process.exit(1);
}

const bridgeLayerArtifact = JSON.parse(fs.readFileSync(bridgeLayerArtifactPath, 'utf8'));
const bridgeLayerAbi = bridgeLayerArtifact.abi;

const erc20Abi = [
    {
        name: 'approve',
        type: 'function',
        stateMutability: 'nonpayable',
        inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }],
        outputs: [{ name: '', type: 'bool' }]
    },
    {
        name: 'allowance',
        type: 'function',
        stateMutability: 'view',
        inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }],
        outputs: [{ name: '', type: 'uint256' }]
    }
];

async function main() {
    console.log(`Running test with account: ${account.address}`);
    console.log(`BridgeLayer Address: ${BRIDGE_LAYER_ADDRESS}`);

    // Determine which token to use
    const tokenArg = process.argv[2] ? process.argv[2].toUpperCase() : 'MIDRX';
    let targetTokenAddress;
    let decimals = 18;

    if (tokenArg === 'MIDRX') {
        targetTokenAddress = MIDRX_ADDRESS;
        decimals = 18;
    } else if (tokenArg === 'MUSDT') {
        targetTokenAddress = MUSDT_ADDRESS;
        decimals = 6;
    } else if (tokenArg === 'MUSDC') {
        targetTokenAddress = MUSDC_ADDRESS;
        decimals = 6;
    } else {
        // Fallback if user passes something else or relies on TOKEN_ADDRESS
        targetTokenAddress = TOKEN_ADDRESS;
        // We assume 18 if unknown, or maybe we should fetch it. For now default to 18.
    }

    if (!targetTokenAddress) {
        console.log(`No address found for ${tokenArg} (and TOKEN_ADDRESS not set).`);
        console.log("Please set MIDRX_ADDRESS, MUSDT_ADDRESS, MUSDC_ADDRESS, or TOKEN_ADDRESS in .env");
        return;
    }

    console.log(`Testing with Token: ${tokenArg} (${targetTokenAddress}) Decimals: ${decimals}`);

    const amount = parseUnits('1000', decimals); 
    const dstChainId = 84532; // Base Sepolia
    const recipient = account.address; // Send to self
    const extraData = '0x'; // Empty bytes

    // 1. Approve Token
    console.log(`Checking allowance for ${targetTokenAddress}...`);
    const allowance = await publicClient.readContract({
        address: targetTokenAddress,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [account.address, BRIDGE_LAYER_ADDRESS]
    });

    if (allowance < amount) {
        console.log(`Approving token ${targetTokenAddress}...`);
        try {
            const hashApprove = await client.writeContract({
                address: targetTokenAddress,
                abi: erc20Abi,
                functionName: 'approve',
                args: [BRIDGE_LAYER_ADDRESS, amount],
            });
            console.log(`Approve Tx Hash: ${hashApprove}`);
            await publicClient.waitForTransactionReceipt({ hash: hashApprove });
            console.log("Token approved.");
        } catch (error) {
            console.error("Approval failed:", error);
            return;
        }
    } else {
        console.log("Token already approved.");
    }

    // 2. Call Bridge
    console.log("Calling bridge...");
    try {
        const hashBridge = await client.writeContract({
            address: BRIDGE_LAYER_ADDRESS,
            abi: bridgeLayerAbi,
            functionName: 'bridge',
            args: [targetTokenAddress, amount, BigInt(dstChainId), recipient, extraData],
            value: parseEther('0.01') // Pay some native gas
        });
        console.log(`Bridge Tx Hash: ${hashBridge}`);
        
        const receipt = await publicClient.waitForTransactionReceipt({ hash: hashBridge });
        console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
        console.log(`Status: ${receipt.status}`);
    } catch (error) {
        console.error("Bridge call failed:", error);
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
