'use client';

import { usePrivy } from '@privy-io/react-auth';
import { useSeaport } from './hooks/useSeaport';
import { ethers } from 'ethers';

export default function Home() {
  const { login, authenticated, user } = usePrivy();
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
    if (!user?.wallet) return;

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
          recipient: user.wallet.address,
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

  if (!authenticated) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center p-24">
        <button
          onClick={login}
          className="rounded-lg bg-blue-500 px-4 py-2 text-white hover:bg-blue-600"
        >
          Connect Wallet
        </button>
      </div>
    );
  }

  if (!isReady) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center p-24">
        <div>Connecting to wallet...</div>
      </div>
    );
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="z-10 max-w-5xl w-full items-center justify-between font-mono text-sm">
        <h1 className="text-4xl font-bold mb-8">Seaport dApp</h1>
        
        {/* Debug Section */}
        <div className="mb-8 p-4 bg-gray-100 rounded-lg">
          <h3 className="text-lg font-semibold mb-2">Connection Status</h3>
          <pre className="whitespace-pre-wrap">
            {JSON.stringify({
              authenticated,
              walletAddress: user?.wallet?.address,
              walletType: user?.wallet?.walletClientType,
              chainId: user?.wallet?.chainId,
            }, null, 2)}
          </pre>
        </div>
        
        <div className="mb-8">
          <button
            onClick={handleCreateOrder}
            disabled={isLoading}
            className="rounded-lg bg-blue-500 px-4 py-2 text-white hover:bg-blue-600 disabled:bg-gray-400"
          >
            {isLoading ? 'Creating Order...' : 'Create Order'}
          </button>
        </div>

        {error && (
          <div className="mb-4 p-4 bg-red-100 text-red-700 rounded-lg">
            {error}
          </div>
        )}

        {orderStatus && (
          <div className="mb-4 p-4 bg-gray-100 rounded-lg">
            <h3 className="text-lg font-semibold mb-2">Order Status</h3>
            <pre className="whitespace-pre-wrap">
              {JSON.stringify(orderStatus, null, 2)}
            </pre>
          </div>
        )}
      </div>
    </main>
  );
} 