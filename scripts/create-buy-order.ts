import { Wallet, providers, constants } from "ethers";
import { Seaport } from "@opensea/seaport-js";
import * as dotenv from 'dotenv';
import { decrypt } from './encryption'; // Your encryption utility

// Load environment variables
dotenv.config();

async function main() {
    // --- USER INPUTS ---
    const RPC_URL = `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`;
    
    // Decrypt sensitive data
    const PRIVATE_KEY = decrypt(process.env.ENCRYPTED_PRIVATE_KEY);
    const NFT_CONTRACT_ADDRESS = process.env.NFT_CONTRACT_ADDRESS;
    const NFT_ID = process.env.NFT_ID;
    // Convert ETH amount to wei (0.000001 ETH = 1000000000000 wei)
    const OFFER_AMOUNT = "0.00000000001";

    // Validate environment variables
    if (!PRIVATE_KEY) {
        throw new Error("WALLET_PRIVATE_KEY is not set in .env file");
    }
    if (!process.env.ALCHEMY_API_KEY) {
        throw new Error("ALCHEMY_API_KEY is not set in .env file");
    }
    if (!NFT_CONTRACT_ADDRESS) {
        throw new Error("NFT_CONTRACT_ADDRESS is not set in .env file");
    }
    if (!NFT_ID) {
        throw new Error("NFT_ID is not set in .env file");
    }
    // -------------------

    // Set up provider and signer
    const provider = new providers.JsonRpcProvider(RPC_URL);
    const wallet = new Wallet(PRIVATE_KEY, provider);

    // Initialize Seaport with ethers v5 Wallet (Signer)
    const seaport = new Seaport(wallet);

    // Build the order (buy order: offer ETH, want NFT)
    const offer = [
        {
            itemType: 0, // NATIVE (ETH)
            token: constants.AddressZero,
            amount: OFFER_AMOUNT,
        },
    ];
    const consideration = [
        {
            itemType: 2, // ERC721
            token: NFT_CONTRACT_ADDRESS,
            identifier: NFT_ID,
            recipient: wallet.address,
            amount: "1",
        },
    ];

    try {
        const { executeAllActions } = await seaport.createOrder({
            offer,
            consideration,
            endTime: (Math.floor(Date.now() / 1000) + 86400).toString(), // 24 hours from now
        });

        const order = await executeAllActions();
        console.log("Order created successfully!");
        console.log("Order object:", order);
    } catch (error) {
        console.error("Error creating order:", error);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 