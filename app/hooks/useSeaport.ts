import { ethers } from "ethers";
import { Seaport } from "@opensea/seaport-js";
import { usePrivy } from '@privy-io/react-auth';
import { useCallback, useEffect, useState } from 'react';

// Constants for Base Mainnet
const SEAPORT_ADDRESS = "0x00000000000001ad428e4906aE43D8F9852d0dD6"; // Seaport 1.6 on Base
const ALCHEMY_API_URL = "https://base-mainnet.g.alchemy.com/v2";

// Utility functions
function validateOrderInput(offer: any[], consideration: any[]) {
    if (!offer.length || !consideration.length) {
        throw new Error("Offer and consideration must not be empty");
    }
    
    // Validate offer
    for (const item of offer) {
        if (!item.itemType || !item.token || !item.amount) {
            throw new Error("Invalid offer item: missing required fields");
        }
        if (item.amount === "0") {
            throw new Error("Invalid offer amount: cannot be zero");
        }
    }

    // Validate consideration
    for (const item of consideration) {
        if (!item.itemType || !item.token || !item.amount || !item.recipient) {
            throw new Error("Invalid consideration item: missing required fields");
        }
        if (item.amount === "0") {
            throw new Error("Invalid consideration amount: cannot be zero");
        }
    }
}

async function withRetry<T>(operation: () => Promise<T>, maxRetries: number = 3): Promise<T> {
    let lastError;
    for (let i = 0; i < maxRetries; i++) {
        try {
            return await operation();
        } catch (error) {
            lastError = error;
            console.log(`Attempt ${i + 1} failed, retrying...`);
            await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
        }
    }
    throw lastError;
}

// Custom hook for Seaport interactions
export function useSeaport() {
    const { user, ready, authenticated } = usePrivy();
    const [seaport, setSeaport] = useState<Seaport | null>(null);
    const [seaportContract, setSeaportContract] = useState<ethers.Contract | null>(null);
    const [orderStatus, setOrderStatus] = useState<any>(null);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Initialize Seaport when user is authenticated
    useEffect(() => {
        if (ready && authenticated && user?.wallet) {
            const provider = new ethers.providers.Web3Provider(user.wallet.provider);
            const signer = provider.getSigner();
            
            const seaportInstance = new Seaport(signer as any, {
                overrides: { contractAddress: SEAPORT_ADDRESS }
            });

            const contract = new ethers.Contract(
                SEAPORT_ADDRESS,
                [
                    "function getOrderStatus(bytes32) view returns (bool, bool, uint256, uint256)",
                    "function getCounter(address) view returns (uint256)",
                    "function cancel(bytes32[]) external"
                ],
                signer
            );

            setSeaport(seaportInstance);
            setSeaportContract(contract);
        }
    }, [ready, authenticated, user]);

    // Create order
    const createOrder = useCallback(async (offer: any[], consideration: any[]) => {
        if (!seaport) throw new Error("Seaport not initialized");
        
        setIsLoading(true);
        setError(null);
        
        try {
            validateOrderInput(offer, consideration);
            
            const { executeAllActions } = await seaport.createOrder({
                offer,
                consideration,
                endTime: (Math.floor(Date.now() / 1000) + 86400).toString(), // 24 hours from now
            });

            const order = await executeAllActions();
            const orderHash = await seaport.getOrderHash(order.parameters);
            
            // Get initial order status
            const status = await seaportContract?.getOrderStatus(orderHash);
            setOrderStatus({
                isValidated: status[0],
                isCancelled: status[1],
                totalFilled: status[2].toString(),
                totalSize: status[3].toString()
            });

            return { order, orderHash };
        } catch (err) {
            setError(err instanceof Error ? err.message : "Failed to create order");
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, [seaport, seaportContract]);

    // Cancel order
    const cancelOrder = useCallback(async (orderHash: string) => {
        if (!seaportContract) throw new Error("Seaport contract not initialized");
        
        setIsLoading(true);
        setError(null);
        
        try {
            const tx = await seaportContract.cancel([orderHash]);
            await tx.wait();
            return true;
        } catch (err) {
            setError(err instanceof Error ? err.message : "Failed to cancel order");
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, [seaportContract]);

    // Fulfill order
    const fulfillOrder = useCallback(async (order: any) => {
        if (!seaport) throw new Error("Seaport not initialized");
        
        setIsLoading(true);
        setError(null);
        
        try {
            const { executeAllActions } = await seaport.fulfillOrder({
                order,
                accountAddress: await seaportContract?.signer.getAddress(),
            });

            const result = await executeAllActions();
            return result;
        } catch (err) {
            setError(err instanceof Error ? err.message : "Failed to fulfill order");
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, [seaport, seaportContract]);

    // Get order status
    const getOrderStatus = useCallback(async (orderHash: string) => {
        if (!seaportContract) throw new Error("Seaport contract not initialized");
        
        setIsLoading(true);
        setError(null);
        
        try {
            const [isValidated, isCancelled, totalFilled, totalSize] = 
                await seaportContract.getOrderStatus(orderHash);
            
            const status = {
                isValidated,
                isCancelled,
                totalFilled: totalFilled.toString(),
                totalSize: totalSize.toString()
            };
            
            setOrderStatus(status);
            return status;
        } catch (err) {
            setError(err instanceof Error ? err.message : "Failed to get order status");
            throw err;
        } finally {
            setIsLoading(false);
        }
    }, [seaportContract]);

    return {
        createOrder,
        cancelOrder,
        fulfillOrder,
        getOrderStatus,
        orderStatus,
        isLoading,
        error,
        isReady: !!seaport && !!seaportContract
    };
} 