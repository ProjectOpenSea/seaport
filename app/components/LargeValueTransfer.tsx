import { useState } from 'react';
import { useMultiSig } from '../hooks/useMultiSig';
import { usePrivy } from '@privy-io/react-auth';
import { ethers } from 'ethers';

// Large value thresholds
const VALUE_THRESHOLDS = {
  STANDARD: ethers.utils.parseEther('10'), // 10 ETH
  LARGE: ethers.utils.parseEther('50'), // 50 ETH
  EXTREME: ethers.utils.parseEther('100'), // 100 ETH
};

// Required signatures based on value
const REQUIRED_SIGNATURES = {
  [VALUE_THRESHOLDS.STANDARD.toString()]: 2,
  [VALUE_THRESHOLDS.LARGE.toString()]: 3,
  [VALUE_THRESHOLDS.EXTREME.toString()]: 4,
};

export function LargeValueTransfer() {
  const { user } = usePrivy();
  const {
    createTransaction,
    signTransaction,
    executeTransaction,
    getTransactionStatus,
    getPendingTransactions,
    getApprovedTransactions,
    isLoading,
  } = useMultiSig();

  const [transferDetails, setTransferDetails] = useState({
    to: '',
    value: '',
    data: '',
  });

  const [currentTransaction, setCurrentTransaction] = useState<string | null>(null);

  const handleCreateTransfer = async () => {
    try {
      const value = ethers.utils.parseEther(transferDetails.value);
      
      // Determine required signatures based on value
      const requiredSignatures = Object.entries(REQUIRED_SIGNATURES)
        .find(([threshold]) => value.lte(ethers.BigNumber.from(threshold)))?.[1] || 4;

      // Create multi-sig transaction
      const transaction = await createTransaction(
        transferDetails.to,
        value,
        transferDetails.data || '0x'
      );

      setCurrentTransaction(transaction.id);
    } catch (err) {
      console.error('Error creating transfer:', err);
    }
  };

  const handleSignTransfer = async () => {
    if (!currentTransaction) return;

    try {
      await signTransaction(currentTransaction);
    } catch (err) {
      console.error('Error signing transfer:', err);
    }
  };

  const handleExecuteTransfer = async () => {
    if (!currentTransaction) return;

    try {
      await executeTransaction(currentTransaction);
    } catch (err) {
      console.error('Error executing transfer:', err);
    }
  };

  const getRequiredSignatures = (value: string) => {
    const parsedValue = ethers.utils.parseEther(value);
    return Object.entries(REQUIRED_SIGNATURES)
      .find(([threshold]) => parsedValue.lte(ethers.BigNumber.from(threshold)))?.[1] || 4;
  };

  if (!user?.wallet) {
    return (
      <div className="text-center p-4">
        <p className="text-gray-600">Please connect your wallet to continue</p>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto p-6">
      <h2 className="text-2xl font-bold mb-6">Large Value Transfer</h2>

      {/* Transfer Form */}
      <div className="bg-white rounded-lg shadow-md p-6 mb-6">
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700">Recipient Address</label>
            <input
              type="text"
              value={transferDetails.to}
              onChange={(e) => setTransferDetails({ ...transferDetails, to: e.target.value })}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Amount (ETH)</label>
            <input
              type="number"
              value={transferDetails.value}
              onChange={(e) => setTransferDetails({ ...transferDetails, value: e.target.value })}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            />
            {transferDetails.value && (
              <p className="mt-1 text-sm text-gray-500">
                Required signatures: {getRequiredSignatures(transferDetails.value)}
              </p>
            )}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700">Additional Data (Optional)</label>
            <input
              type="text"
              value={transferDetails.data}
              onChange={(e) => setTransferDetails({ ...transferDetails, data: e.target.value })}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
            />
          </div>
          <button
            onClick={handleCreateTransfer}
            disabled={isLoading || !transferDetails.to || !transferDetails.value}
            className="w-full bg-indigo-600 text-white px-4 py-2 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50"
          >
            Create Transfer
          </button>
        </div>
      </div>

      {/* Transaction Status */}
      {currentTransaction && (
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <h3 className="text-lg font-semibold mb-4">Transaction Status</h3>
          <div className="space-y-4">
            <p className="text-sm text-gray-600">
              Status: {getTransactionStatus(currentTransaction)}
            </p>
            <div className="flex space-x-4">
              <button
                onClick={handleSignTransfer}
                disabled={isLoading || getTransactionStatus(currentTransaction) !== 'pending'}
                className="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 disabled:opacity-50"
              >
                Sign Transfer
              </button>
              <button
                onClick={handleExecuteTransfer}
                disabled={isLoading || getTransactionStatus(currentTransaction) !== 'approved'}
                className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50"
              >
                Execute Transfer
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Pending Transactions */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <h3 className="text-lg font-semibold mb-4">Pending Transactions</h3>
        <div className="space-y-4">
          {getPendingTransactions().map((tx) => (
            <div key={tx.id} className="border-b border-gray-200 pb-4">
              <p className="text-sm text-gray-600">To: {tx.to}</p>
              <p className="text-sm text-gray-600">
                Value: {ethers.utils.formatEther(tx.value)} ETH
              </p>
              <p className="text-sm text-gray-600">
                Signatures: {tx.signatures.length} / {getRequiredSignatures(ethers.utils.formatEther(tx.value))}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
} 