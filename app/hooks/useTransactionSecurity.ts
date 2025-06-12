import { useState, useCallback } from 'react';
import { usePrivy } from '@privy-io/react-auth';
import { ethers } from 'ethers';
import { zora } from 'viem/chains';

// Security thresholds
const SECURITY_THRESHOLDS = {
    MAX_GAS_PRICE: ethers.utils.parseUnits('100', 'gwei'), // 100 gwei
    MAX_TRANSACTION_VALUE: ethers.utils.parseEther('10'), // 10 ETH
    MIN_CONFIRMATION_BLOCKS: 3,
    RATE_LIMIT_WINDOW: 3600, // 1 hour in seconds
    MAX_TRANSACTIONS_PER_WINDOW: 5,
};

// Transaction simulation results
type SimulationResult = {
    success: boolean;
    error?: string;
    gasEstimate?: ethers.BigNumber;
    revertReason?: string;
};

// Rate limiting state
type RateLimitState = {
    transactions: Array<{
        timestamp: number;
        value: ethers.BigNumber;
    }>;
};

export function useTransactionSecurity() {
    const { user } = usePrivy();
    const [isSimulating, setIsSimulating] = useState(false);
    const [rateLimitState, setRateLimitState] = useState<RateLimitState>({
        transactions: [],
    });

    // Simulate transaction before sending
    const simulateTransaction = useCallback(async (
        to: string,
        value: ethers.BigNumber,
        data: string
    ): Promise<SimulationResult> => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        try {
            setIsSimulating(true);
            const provider = new ethers.providers.Web3Provider(user.wallet.provider);
            const signer = provider.getSigner();
            const from = await signer.getAddress();

            // Get current gas price
            const gasPrice = await provider.getGasPrice();
            if (gasPrice.gt(SECURITY_THRESHOLDS.MAX_GAS_PRICE)) {
                return {
                    success: false,
                    error: 'Gas price too high',
                };
            }

            // Check transaction value
            if (value.gt(SECURITY_THRESHOLDS.MAX_TRANSACTION_VALUE)) {
                return {
                    success: false,
                    error: 'Transaction value exceeds maximum allowed',
                };
            }

            // Simulate transaction
            const gasEstimate = await provider.estimateGas({
                from,
                to,
                value,
                data,
            });

            // Check if simulation was successful
            return {
                success: true,
                gasEstimate,
            };
        } catch (err) {
            const error = err as Error;
            return {
                success: false,
                error: error.message,
                revertReason: error.message,
            };
        } finally {
            setIsSimulating(false);
        }
    }, [user]);

    // Check rate limiting
    const checkRateLimit = useCallback((
        value: ethers.BigNumber
    ): boolean => {
        const now = Math.floor(Date.now() / 1000);
        const windowStart = now - SECURITY_THRESHOLDS.RATE_LIMIT_WINDOW;

        // Clean up old transactions
        const recentTransactions = rateLimitState.transactions.filter(
            tx => tx.timestamp >= windowStart
        );

        // Check if we're within rate limits
        if (recentTransactions.length >= SECURITY_THRESHOLDS.MAX_TRANSACTIONS_PER_WINDOW) {
            return false;
        }

        // Update rate limit state
        setRateLimitState({
            transactions: [
                ...recentTransactions,
                { timestamp: now, value },
            ],
        });

        return true;
    }, [rateLimitState]);

    // Secure transaction wrapper
    const secureTransaction = useCallback(async (
        to: string,
        value: ethers.BigNumber,
        data: string
    ): Promise<ethers.ContractTransaction> => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        // Check rate limiting
        if (!checkRateLimit(value)) {
            throw new Error('Rate limit exceeded. Please try again later.');
        }

        // Simulate transaction
        const simulation = await simulateTransaction(to, value, data);
        if (!simulation.success) {
            throw new Error(simulation.error || 'Transaction simulation failed');
        }

        // Get provider and signer
        const provider = new ethers.providers.Web3Provider(user.wallet.provider);
        const signer = provider.getSigner();

        // Send transaction with security parameters
        const tx = await signer.sendTransaction({
            to,
            value,
            data,
            gasLimit: simulation.gasEstimate?.mul(120).div(100), // Add 20% buffer
            maxFeePerGas: SECURITY_THRESHOLDS.MAX_GAS_PRICE,
        });

        // Wait for confirmations
        await tx.wait(SECURITY_THRESHOLDS.MIN_CONFIRMATION_BLOCKS);

        return tx;
    }, [user, simulateTransaction, checkRateLimit]);

    // Get security status
    const getSecurityStatus = useCallback(() => {
        const now = Math.floor(Date.now() / 1000);
        const windowStart = now - SECURITY_THRESHOLDS.RATE_LIMIT_WINDOW;
        const recentTransactions = rateLimitState.transactions.filter(
            tx => tx.timestamp >= windowStart
        );

        return {
            remainingTransactions: SECURITY_THRESHOLDS.MAX_TRANSACTIONS_PER_WINDOW - recentTransactions.length,
            timeUntilReset: windowStart + SECURITY_THRESHOLDS.RATE_LIMIT_WINDOW - now,
            totalValueInWindow: recentTransactions.reduce(
                (sum, tx) => sum.add(tx.value),
                ethers.BigNumber.from(0)
            ),
        };
    }, [rateLimitState]);

    return {
        secureTransaction,
        simulateTransaction,
        checkRateLimit,
        getSecurityStatus,
        isSimulating,
    };
} 