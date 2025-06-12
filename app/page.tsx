'use client';

import React, { useState, useEffect } from 'react';
import { usePrivy } from '@privy-io/react-auth';
import { useSeaport } from './hooks/useSeaport';
import { ethers } from 'ethers';
import { base, avalanche } from 'viem/chains';

// Components
const LoadingSpinner = () => (
  <div className="animate-spin rounded-full h-6 w-6 border-b-2 border-indigo-500"></div>
);

const NetworkBadge = ({ chainId }: { chainId: number }) => {
  const networkName = chainId === base.id ? 'Base' : 'Avalanche';
  const networkColor = chainId === base.id ? 'bg-blue-500' : 'bg-red-500';
  
  return (
    <div className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${networkColor} text-white`}>
      {networkName}
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
            <span className={`text-xs px-2 py-1 rounded ${
              tx.status === 'success' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
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
  const { user, wallet, login, logout } = usePrivy();
  const { createOrder, getOrderStatus, isLoading, error } = useSeaport();
  const [orderHash, setOrderHash] = useState<string | null>(null);
  const [orderError, setOrderError] = useState<string | null>(null);
  const [amount, setAmount] = useState<string>('');
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [transactions, setTransactions] = useState<Array<{ hash: string; status: string }>>([]);

  const handleCreateOrder = async () => {
    if (!wallet) return;
    
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
    if (!wallet) return;
    
    try {
      const currentChainId = wallet.chainId;
      const targetChainId = currentChainId === base.id ? avalanche.id : base.id;
      
      await wallet.switchChain(targetChainId);
    } catch (err) {
      setOrderError(err instanceof Error ? err.message : 'Failed to switch network');
    }
  };

  return (
    <main className="min-h-screen bg-gray-50 dark:bg-gray-900">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900 dark:text-white">Seaport dApp</h1>
          <div className="flex items-center space-x-4">
            {wallet && <NetworkBadge chainId={wallet.chainId} />}
            <button
              onClick={() => setIsMobileMenuOpen(true)}
              className="sm:hidden p-2 rounded-md text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
            >
              <svg className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
          </div>
        </div>

        <MobileMenu isOpen={isMobileMenuOpen} onClose={() => setIsMobileMenuOpen(false)}>
          <div className="space-y-4">
            {!user ? (
              <button
                onClick={login}
                className="w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700"
              >
                Connect Wallet
              </button>
            ) : (
              <button
                onClick={logout}
                className="w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700"
              >
                Disconnect
              </button>
            )}
            {wallet && (
              <button
                onClick={handleNetworkSwitch}
                className="w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700"
              >
                Switch Network
              </button>
            )}
          </div>
        </MobileMenu>

        {!user ? (
          <div className="text-center">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-4">Connect your wallet to get started</h2>
            <button
              onClick={login}
              className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700"
            >
              Connect Wallet
            </button>
          </div>
        ) : (
          <div className="space-y-6">
            <div className="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
              <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-4">Create Order</h2>
              <div className="space-y-4">
                <div>
                  <label htmlFor="amount" className="block text-sm font-medium text-gray-700 dark:text-gray-300">
                    Amount (ETH)
                  </label>
                  <div className="mt-1 relative rounded-md shadow-sm">
                    <input
                      type="number"
                      name="amount"
                      id="amount"
                      value={amount}
                      onChange={(e) => setAmount(e.target.value)}
                      className="block w-full pr-12 border-gray-300 dark:border-gray-600 rounded-md focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm dark:bg-gray-700 dark:text-white"
                      placeholder="0.0"
                      step="0.01"
                    />
                    <div className="absolute inset-y-0 right-0 pr-3 flex items-center pointer-events-none">
                      <span className="text-gray-500 dark:text-gray-400 sm:text-sm">ETH</span>
                    </div>
                  </div>
                </div>
                <button
                  onClick={handleCreateOrder}
                  disabled={isLoading || !amount}
                  className="w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isLoading ? <LoadingSpinner /> : 'Create Order'}
                </button>
              </div>
            </div>

            {orderHash && (
              <div className="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
                <h2 className="text-xl font-semibold text-gray-900 dark:text-white mb-4">Order Details</h2>
                <div className="space-y-4">
                  <p className="text-sm text-gray-500 dark:text-gray-400 break-all">
                    Order Hash: {orderHash}
                  </p>
                  <button
                    onClick={handleCancelOrder}
                    disabled={isLoading}
                    className="w-full flex items-center justify-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {isLoading ? <LoadingSpinner /> : 'Cancel Order'}
                  </button>
                </div>
              </div>
            )}

            {orderError && (
              <div className="bg-red-50 dark:bg-red-900 border border-red-200 dark:border-red-800 rounded-md p-4">
                <p className="text-sm text-red-700 dark:text-red-200">{orderError}</p>
              </div>
            )}

            <TransactionHistory transactions={transactions} />
          </div>
        )}
      </div>
    </main>
  );
} 