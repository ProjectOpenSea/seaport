import { Wallet, providers, constants } from "ethers";
import { Seaport } from "@opensea/seaport-js";
import * as dotenv from 'dotenv';
import { decrypt } from './utils/encryption'; // Updated import path
import { useSeaport } from './interact-with-seaport';

// Load environment variables
dotenv.config();

async function main() {
    // --- USER INPUTS ---
    const RPC_URL = `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`;
    
    // Decrypt sensitive data
    const encryptedPrivateKey = process.env.ENCRYPTED_PRIVATE_KEY;
    if (!encryptedPrivateKey) {
        throw new Error("ENCRYPTED_PRIVATE_KEY is not set in .env file");
    }
    const PRIVATE_KEY = decrypt(encryptedPrivateKey);
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
    const seaport = new Seaport(wallet as any); // Type assertion to fix type mismatch

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

    function validateOrderInput(offer: any[], consideration: any[]) {
        if (!offer.length || !consideration.length) {
            throw new Error("Offer and consideration must not be empty");
        }
        // Add more validation...
    }

    async function withRetry<T>(operation: () => Promise<T>, maxRetries: number = 3) {
        let lastError;
        for (let i = 0; i < maxRetries; i++) {
            try {
                return await operation();
            } catch (error) {
                lastError = error;
                await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
            }
        }
        throw lastError;
    }

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

export function SeaportOrderComponent() {
    const { 
        createOrder, 
        cancelOrder, 
        fulfillOrder, 
        getOrderStatus,
        orderStatus,
        isLoading,
        error,
        isReady 
    } = useSeaport();

    const handleCreateOrder = async () => {
        try {
            const offer = [
                {
                    itemType: 0, // NATIVE (ETH)
                    token: ethers.constants.AddressZero,
                    amount: "1000000000000000000", // 1 ETH
                },
            ];

            const consideration = [
                {
                    itemType: 2, // ERC721
                    token: process.env.NEXT_PUBLIC_NFT_CONTRACT_ADDRESS,
                    identifier: process.env.NEXT_PUBLIC_NFT_ID,
                    recipient: wallet.address,
                    amount: "1",
                },
            ];

            const { order, orderHash } = await createOrder(offer, consideration);
            console.log('Order created:', order);
            console.log('Order hash:', orderHash);
        } catch (err) {
            console.error('Failed to create order:', err);
        }
    };

    if (!isReady) {
        return <div>Connecting to wallet...</div>;
    }

    return (
        <div>
            <button onClick={handleCreateOrder} disabled={isLoading}>
                {isLoading ? 'Creating Order...' : 'Create Order'}
            </button>
            {error && <div className="error">{error}</div>}
            {orderStatus && (
                <div>
                    <h3>Order Status</h3>
                    <pre>{JSON.stringify(orderStatus, null, 2)}</pre>
                </div>
            )}
        </div>
    );
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 