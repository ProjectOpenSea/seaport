import { useState, useCallback } from 'react';
import { usePrivy } from '@privy-io/react-auth';
import { Seaport } from '@opensea/seaport-js';
import { ethers } from 'ethers';
import { base, avalanche, zora } from 'viem/chains';
import { ItemType } from '@opensea/seaport-js/lib/constants';

// Seaport contract addresses for different networks
const SEAPORT_ADDRESSES = {
  [base.id]: '0x00000000006c3852cbEf3e08E8dF289169EdE581',
  [avalanche.id]: '0x00000000006c3852cbEf3e08E8dF289169EdE581',
  [zora.id]: '0x00000000006c3852cbEf3e08E8dF289169EdE581',
};

export type OrderItem = {
  token: string;
  identifierOrCriteria: string;
  startAmount: string;
  endAmount: string;
};

export type OrderStatus = 'pending' | 'completed' | 'failed';

export type OrderResult = {
  orderHash: string;
  status: OrderStatus;
  error?: string;
};

export function useSeaport() {
  const { user } = usePrivy();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const createOrder = useCallback(async (
    offerItems: OrderItem[],
    considerationItems: OrderItem[],
  ): Promise<OrderResult> => {
    if (!user?.wallet) {
      throw new Error('Wallet not connected');
    }

    try {
      setIsLoading(true);
      setError(null);

      // Get the current chain ID
      const chainId = await user.wallet.getChainId();
      const provider = new ethers.providers.Web3Provider(user.wallet.provider);
      const signer = provider.getSigner();

      // Configure Seaport based on the network
      const seaport = new Seaport(signer, {
        overrides: {
          contractAddress: SEAPORT_ADDRESSES[chainId],
        },
      });

      // Validate order input
      if (!offerItems.length || !considerationItems.length) {
        throw new Error('Offer and consideration items are required');
      }

      // Create the order
      const { executeAllActions } = await seaport.createOrder({
        offer: offerItems.map(item => ({
          itemType: item.token === ethers.constants.AddressZero ? ItemType.NATIVE : ItemType.ERC20,
          token: item.token,
          identifierOrCriteria: item.identifierOrCriteria,
          startAmount: item.startAmount,
          endAmount: item.endAmount,
        })),
        consideration: considerationItems.map(item => ({
          itemType: item.token === ethers.constants.AddressZero ? ItemType.NATIVE : ItemType.ERC20,
          token: item.token,
          identifierOrCriteria: item.identifierOrCriteria,
          startAmount: item.startAmount,
          endAmount: item.endAmount,
          recipient: await signer.getAddress(),
        })),
      });

      // Execute the order
      const transaction = await executeAllActions();
      const receipt = await transaction.wait();

      return {
        orderHash: receipt.transactionHash,
        status: 'completed',
      };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
      setError(errorMessage);
      return {
        orderHash: '',
        status: 'failed',
        error: errorMessage,
      };
    } finally {
      setIsLoading(false);
    }
  }, [user]);

  const getOrderStatus = useCallback(async (orderHash: string): Promise<OrderStatus> => {
    if (!user?.wallet) {
      throw new Error('Wallet not connected');
    }

    try {
      const chainId = await user.wallet.getChainId();
      const provider = new ethers.providers.Web3Provider(user.wallet.provider);
      const seaport = new Seaport(provider, {
        overrides: {
          contractAddress: SEAPORT_ADDRESSES[chainId],
        },
      });

      const order = await seaport.getOrder(orderHash);
      return order ? 'completed' : 'pending';
    } catch (err) {
      console.error('Error getting order status:', err);
      return 'failed';
    }
  }, [user]);

  return {
    createOrder,
    getOrderStatus,
    isLoading,
    error,
  };
} 