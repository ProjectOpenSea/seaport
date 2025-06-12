import { useState, useCallback } from 'react';
import { usePrivy } from '@privy-io/react-auth';
import { Seaport } from '@opensea/seaport-js';
import { ethers } from 'ethers';
import { base, avalanche } from 'viem/chains';

// Types
interface OrderItem {
  itemType: number;
  token: string;
  identifierOrCriteria: string;
  startAmount: string;
  endAmount: string;
}

interface OrderStatus {
  isValid: boolean;
  isCancelled: boolean;
  isFulfilled: boolean;
  error?: string;
}

interface OrderResult {
  orderHash: string;
  status: OrderStatus;
}

// Constants for Base Mainnet
const SEAPORT_ADDRESS = "0x00000000000001ad428e4906aE43D8F9852d0dD6"; // Seaport 1.6 on Base
const ALCHEMY_API_URL = "https://base-mainnet.g.alchemy.com/v2";

// Utility functions
function validateOrderInput(offer: OrderItem[], consideration: OrderItem[]) {
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
    const { user, wallet } = usePrivy();
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [orderStatus, setOrderStatus] = useState<OrderStatus | null>(null);

    const getSeaportInstance = useCallback(() => {
        if (!wallet) throw new Error('Wallet not connected');
        
        // Get the current chain ID from the wallet
        const chainId = wallet.chainId;
        
        // Create a Web3Provider from the wallet's provider
        const provider = new ethers.providers.Web3Provider(wallet.provider);
        const signer = provider.getSigner();
        
        // Configure Seaport based on network
        const seaportConfig = {
            overrides: {
                contractAddress: chainId === base.id 
                    ? '0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC' // Base Seaport
                    : '0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC', // Avalanche Seaport
            },
        };

        return new Seaport(signer, seaportConfig);
    }, [wallet]);

    const validateOrderInput = useCallback((offer: OrderItem[], consideration: OrderItem[]) => {
        if (!offer.length || !consideration.length) {
            throw new Error('Offer and consideration must not be empty');
        }
        // Add more validation as needed
    }, []);

    const createOrder = useCallback(async (
        offer: OrderItem[],
        consideration: OrderItem[],
        zone = ethers.constants.AddressZero,
        conduitKey = '0x0000000000000000000000000000000000000000000000000000000000000000'
    ): Promise<OrderResult> => {
        try {
            setIsLoading(true);
            setError(null);

            if (!wallet) {
                throw new Error('Wallet not connected');
            }

            validateOrderInput(offer, consideration);

            const seaport = getSeaportInstance();
            
            const { executeAllActions } = await seaport.createOrder({
                offer,
                consideration,
                zone,
                conduitKey,
            });

            const order = await executeAllActions();
            
            // Verify the order
            const isValid = await seaport.validate([order]);
            
            setOrderStatus({
                isValid,
                isCancelled: false,
                isFulfilled: false,
            });

            return {
                orderHash: order.hash,
                status: {
                    isValid,
                    isCancelled: false,
                    isFulfilled: false,
                },
            };
        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'Failed to create order';
            setError(errorMessage);
            throw new Error(errorMessage);
        } finally {
            setIsLoading(false);
        }
    }, [wallet, validateOrderInput, getSeaportInstance]);

    const getOrderStatus = useCallback(async (orderHash: string): Promise<OrderStatus> => {
        try {
            setIsLoading(true);
            setError(null);

            if (!wallet) {
                throw new Error('Wallet not connected');
            }

            const seaport = getSeaportInstance();
            
            // Get order status from Seaport
            const isValid = await seaport.validate([{ hash: orderHash }]);
            
            const status: OrderStatus = {
                isValid,
                isCancelled: false, // You'll need to implement cancellation check
                isFulfilled: false, // You'll need to implement fulfillment check
            };

            setOrderStatus(status);
            return status;
        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'Failed to get order status';
            setError(errorMessage);
            throw new Error(errorMessage);
        } finally {
            setIsLoading(false);
        }
    }, [wallet, getSeaportInstance]);

    return {
        createOrder,
        getOrderStatus,
        isLoading,
        error,
        orderStatus,
    };
} 