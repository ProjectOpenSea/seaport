'use client';

import React, { useState, useEffect } from 'react';
import { usePrivy } from '@privy-io/react-auth';
import { useSeaport } from './hooks/useSeaport';
import { ethers } from 'ethers';
import { base, avalanche, zora } from 'viem/chains';
import { ZoraRodeoMinter } from './components/ZoraRodeoMinter';
import { SecurityMiddleware } from './components/SecurityMiddleware';

// Components
const LoadingSpinner = () => (
  <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-indigo-500"></div>
);

const NetworkBadge = ({ network }: { network: string }) => {
  const networkColor = network === 'Base' ? 'bg-blue-500' : network === 'Avalanche' ? 'bg-red-500' : 'bg-green-500';

  return (
    <div className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${networkColor} text-white`}>
      {network}
    </div>
  );
};

const MobileMenu = ({ isOpen, onClose, children }: { isOpen: boolean; onClose: () => void; children: React.ReactNode }) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50">
      <div className="fixed inset-0 bg-black bg-opacity-50" onClick={onClose} />
      <div className="fixed inset-y-0 right-0 max-w-xs w-full bg-white dark:bg-gray-800 shadow-xl">
        <div className="h-full flex flex-col py-6 px-4">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-medium">Menu</h2>
            <button onClick={onClose} className="text-gray-500 hover:text-gray-700">
              <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
          {children}
        </div>
      </div>
    </div>
  );
};

const TransactionHistory = ({ transactions }: { transactions: Array<{ hash: string; status: string }> }) => {
  if (!transactions.length) return null;

  return (
    <div className="mt-4">
      <h3 className="text-lg font-medium mb-2">Recent Transactions</h3>
      <div className="space-y-2">
        {transactions.map((tx) => (
          <div key={tx.hash} className="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-700 rounded">
            <span className="text-sm truncate">{tx.hash}</span>
            <span className={`text-xs px-2 py-1 rounded ${tx.status === 'success' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
              }`}>
              {tx.status}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default function Home() {
  const { user, login, logout } = usePrivy();
  const { createOrder, getOrderStatus, isLoading, error } = useSeaport();
  const [orderHash, setOrderHash] = useState<string | null>(null);
  const [orderError, setOrderError] = useState<string | null>(null);
  const [amount, setAmount] = useState<string>('');
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [transactions, setTransactions] = useState<Array<{ hash: string; status: string }>>([]);
  const [chainId, setChainId] = useState<number>(base.id);

  const handleCreateOrder = async () => {
    if (!user?.wallet) return;

    try {
      const amountInWei = ethers.utils.parseEther(amount).toString();

      const offer = [{
        itemType: 0, // NATIVE
        token: ethers.constants.AddressZero,
        identifierOrCriteria: "0",
        startAmount: amountInWei,
        endAmount: amountInWei
      }];

      const consideration = [{
        itemType: 1, // ERC20
        token: process.env.NEXT_PUBLIC_NFT_CONTRACT_ADDRESS || '',
        identifierOrCriteria: process.env.NEXT_PUBLIC_NFT_ID || '',
        startAmount: "1",
        endAmount: "1"
      }];

      const result = await createOrder(offer, consideration);
      setOrderHash(result.orderHash);
      setTransactions(prev => [...prev, { hash: result.orderHash, status: 'success' }]);
    } catch (err) {
      setOrderError(err instanceof Error ? err.message : 'Failed to create order');
      setTransactions(prev => [...prev, { hash: 'failed', status: 'error' }]);
    }
  };

  const handleCancelOrder = async () => {
    if (!orderHash) return;

    try {
      // Since we don't have a cancelOrder function, we'll just update the UI
      setOrderHash(null);
      setTransactions(prev => [...prev, { hash: orderHash, status: 'cancelled' }]);
    } catch (err) {
      setOrderError(err instanceof Error ? err.message : 'Failed to cancel order');
    }
  };

  const handleNetworkSwitch = async () => {
    if (!user?.wallet) return;

    try {
      const provider = user.wallet.provider;
      const currentChainId = await provider.getNetwork().then(n => n.chainId);
      const targetChainId = currentChainId === base.id
        ? avalanche.id
        : currentChainId === avalanche.id
          ? zora.id
          : base.id;

      await provider.send('wallet_switchEthereumChain', [{ chainId: `0x${targetChainId.toString(16)}` }]);
      setChainId(targetChainId);
    } catch (error) {
      console.error('Error switching network:', error);
    }
  };

  const getNetworkName = (chainId: number) => {
    switch (chainId) {
      case base.id:
        return 'Base';
      case avalanche.id:
        return 'Avalanche';
      case zora.id:
        return 'Zora';
      default:
        return 'Unknown';
    }
  };

  return (
    <SecurityMiddleware>
      <main className="min-h-screen bg-gray-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div className="text-center mb-12">
            <h1 className="text-4xl font-bold text-gray-900 mb-4">
              NFT Marketplace
            </h1>
            <p className="text-xl text-gray-600">
              Trade NFTs across multiple chains with the best prices
            </p>
          </div>

          {!user ? (
            <div className="text-center">
              <button
                onClick={login}
                className="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                Connect Wallet
              </button>
            </div>
          ) : (
            <div className="space-y-8">
              <div className="bg-white rounded-lg shadow-md p-6">
                <h2 className="text-2xl font-bold mb-4">Create Order</h2>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700">Amount (ETH)</label>
                    <input
                      type="number"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                    />
                  </div>
                  <button
                    onClick={handleCreateOrder}
                    disabled={isLoading}
                    className="w-full bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                  >
                    {isLoading ? 'Creating...' : 'Create Order'}
                  </button>
                </div>
              </div>

              <ZoraRodeoMinter />

              {orderHash && (
                <div className="bg-green-50 p-4 rounded-md">
                  <p className="text-green-800">Order created successfully!</p>
                  <p className="text-sm text-green-600">Hash: {orderHash}</p>
                </div>
              )}

              {orderError && (
                <div className="bg-red-50 p-4 rounded-md">
                  <p className="text-red-800">Error: {orderError}</p>
                </div>
              )}

              <TransactionHistory transactions={transactions} />
            </div>
          )}
        </div>
      </main>
    </SecurityMiddleware>
  );
} 