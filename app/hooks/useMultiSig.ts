import { useState, useCallback } from 'react';
import { usePrivy } from '@privy-io/react-auth';
import { ethers } from 'ethers';

// Multi-sig configuration
const MULTISIG_CONFIG = {
    // Minimum number of required signatures
    MIN_SIGNATURES: 2,
    // Time window for collecting signatures (in seconds)
    SIGNATURE_WINDOW: 3600, // 1 hour
    // Authorized signers
    AUTHORIZED_SIGNERS: [
        '0x0000000000000000000000000000000000000000', // Replace with actual addresses
        '0x0000000000000000000000000000000000000000',
        '0x0000000000000000000000000000000000000000',
    ],
};

// Transaction status
type TransactionStatus = 'pending' | 'approved' | 'rejected' | 'executed' | 'expired';

// Multi-sig transaction
type MultiSigTransaction = {
    id: string;
    to: string;
    value: ethers.BigNumber;
    data: string;
    status: TransactionStatus;
    signatures: Array<{
        signer: string;
        signature: string;
        timestamp: number;
    }>;
    createdAt: number;
    executedAt?: number;
    executedBy?: string;
};

export function useMultiSig() {
    const { user } = usePrivy();
    const [transactions, setTransactions] = useState<MultiSigTransaction[]>([]);
    const [isLoading, setIsLoading] = useState(false);

    // Create a new multi-sig transaction
    const createTransaction = useCallback(async (
        to: string,
        value: ethers.BigNumber,
        data: string
    ): Promise<MultiSigTransaction> => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        const signer = new ethers.providers.Web3Provider(user.wallet.provider).getSigner();
        const signerAddress = await signer.getAddress();

        // Check if signer is authorized
        if (!MULTISIG_CONFIG.AUTHORIZED_SIGNERS.includes(signerAddress)) {
            throw new Error('Unauthorized signer');
        }

        const transaction: MultiSigTransaction = {
            id: ethers.utils.keccak256(ethers.utils.randomBytes(32)),
            to,
            value,
            data,
            status: 'pending',
            signatures: [],
            createdAt: Math.floor(Date.now() / 1000),
        };

        setTransactions(prev => [...prev, transaction]);
        return transaction;
    }, [user]);

    // Sign a transaction
    const signTransaction = useCallback(async (
        transactionId: string
    ): Promise<void> => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        setIsLoading(true);
        try {
            const signer = new ethers.providers.Web3Provider(user.wallet.provider).getSigner();
            const signerAddress = await signer.getAddress();

            // Check if signer is authorized
            if (!MULTISIG_CONFIG.AUTHORIZED_SIGNERS.includes(signerAddress)) {
                throw new Error('Unauthorized signer');
            }

            // Find the transaction
            const transaction = transactions.find(tx => tx.id === transactionId);
            if (!transaction) {
                throw new Error('Transaction not found');
            }

            // Check if transaction is still valid
            if (transaction.status !== 'pending') {
                throw new Error('Transaction is no longer pending');
            }

            // Check if signer has already signed
            if (transaction.signatures.some(sig => sig.signer === signerAddress)) {
                throw new Error('Already signed');
            }

            // Create signature
            const message = ethers.utils.arrayify(
                ethers.utils.keccak256(
                    ethers.utils.defaultAbiCoder.encode(
                        ['address', 'uint256', 'bytes', 'uint256'],
                        [transaction.to, transaction.value, transaction.data, transaction.createdAt]
                    )
                )
            );
            const signature = await signer.signMessage(message);

            // Update transaction
            setTransactions(prev => prev.map(tx => {
                if (tx.id === transactionId) {
                    const newSignatures = [
                        ...tx.signatures,
                        {
                            signer: signerAddress,
                            signature,
                            timestamp: Math.floor(Date.now() / 1000),
                        },
                    ];

                    // Check if we have enough signatures
                    const status = newSignatures.length >= MULTISIG_CONFIG.MIN_SIGNATURES
                        ? 'approved'
                        : 'pending';

                    return {
                        ...tx,
                        signatures: newSignatures,
                        status,
                    };
                }
                return tx;
            }));
        } finally {
            setIsLoading(false);
        }
    }, [user, transactions]);

    // Execute a transaction
    const executeTransaction = useCallback(async (
        transactionId: string
    ): Promise<ethers.ContractTransaction> => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        setIsLoading(true);
        try {
            const signer = new ethers.providers.Web3Provider(user.wallet.provider).getSigner();
            const signerAddress = await signer.getAddress();

            // Find the transaction
            const transaction = transactions.find(tx => tx.id === transactionId);
            if (!transaction) {
                throw new Error('Transaction not found');
            }

            // Check if transaction is approved
            if (transaction.status !== 'approved') {
                throw new Error('Transaction is not approved');
            }

            // Check if signer is authorized
            if (!MULTISIG_CONFIG.AUTHORIZED_SIGNERS.includes(signerAddress)) {
                throw new Error('Unauthorized signer');
            }

            // Execute transaction
            const tx = await signer.sendTransaction({
                to: transaction.to,
                value: transaction.value,
                data: transaction.data,
            });

            // Update transaction status
            setTransactions(prev => prev.map(tx => {
                if (tx.id === transactionId) {
                    return {
                        ...tx,
                        status: 'executed',
                        executedAt: Math.floor(Date.now() / 1000),
                        executedBy: signerAddress,
                    };
                }
                return tx;
            }));

            return tx;
        } finally {
            setIsLoading(false);
        }
    }, [user, transactions]);

    // Get transaction status
    const getTransactionStatus = useCallback((transactionId: string): TransactionStatus | null => {
        const transaction = transactions.find(tx => tx.id === transactionId);
        return transaction?.status || null;
    }, [transactions]);

    // Get pending transactions
    const getPendingTransactions = useCallback((): MultiSigTransaction[] => {
        return transactions.filter(tx => tx.status === 'pending');
    }, [transactions]);

    // Get approved transactions
    const getApprovedTransactions = useCallback((): MultiSigTransaction[] => {
        return transactions.filter(tx => tx.status === 'approved');
    }, [transactions]);

    return {
        createTransaction,
        signTransaction,
        executeTransaction,
        getTransactionStatus,
        getPendingTransactions,
        getApprovedTransactions,
        isLoading,
    };
} 