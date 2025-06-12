import { useEffect, useState } from 'react';
import { useTransactionSecurity } from '../hooks/useTransactionSecurity';
import { ethers } from 'ethers';

export function SecurityMiddleware({ children }: { children: React.ReactNode }) {
    const { getSecurityStatus, isSimulating } = useTransactionSecurity();
    const [securityStatus, setSecurityStatus] = useState<ReturnType<typeof getSecurityStatus>>();
    const [showWarning, setShowWarning] = useState(false);

    useEffect(() => {
        const interval = setInterval(() => {
            setSecurityStatus(getSecurityStatus());
        }, 1000);

        return () => clearInterval(interval);
    }, [getSecurityStatus]);

    useEffect(() => {
        if (securityStatus) {
            const { remainingTransactions, totalValueInWindow } = securityStatus;
            const maxValue = ethers.utils.parseEther('10'); // 10 ETH

            if (remainingTransactions <= 1 || totalValueInWindow.gt(maxValue)) {
                setShowWarning(true);
            } else {
                setShowWarning(false);
            }
        }
    }, [securityStatus]);

    return (
        <div className="relative">
            {/* Security Status Bar */}
            <div className="bg-gray-100 border-b border-gray-200">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="py-2 flex items-center justify-between">
                        <div className="flex items-center space-x-4">
                            <div className="flex items-center">
                                <span className="text-sm text-gray-600">Rate Limit:</span>
                                <span className="ml-2 text-sm font-medium text-gray-900">
                                    {securityStatus?.remainingTransactions} transactions remaining
                                </span>
                            </div>
                            <div className="flex items-center">
                                <span className="text-sm text-gray-600">Time until reset:</span>
                                <span className="ml-2 text-sm font-medium text-gray-900">
                                    {Math.max(0, Math.floor(securityStatus?.timeUntilReset || 0))}s
                                </span>
                            </div>
                        </div>
                        {isSimulating && (
                            <div className="flex items-center text-yellow-600">
                                <svg className="animate-spin h-4 w-4 mr-2" viewBox="0 0 24 24">
                                    <circle
                                        className="opacity-25"
                                        cx="12"
                                        cy="12"
                                        r="10"
                                        stroke="currentColor"
                                        strokeWidth="4"
                                    />
                                    <path
                                        className="opacity-75"
                                        fill="currentColor"
                                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                                    />
                                </svg>
                                <span className="text-sm">Simulating transaction...</span>
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {/* Security Warning */}
            {showWarning && (
                <div className="bg-yellow-50 border-l-4 border-yellow-400 p-4">
                    <div className="flex">
                        <div className="flex-shrink-0">
                            <svg
                                className="h-5 w-5 text-yellow-400"
                                viewBox="0 0 20 20"
                                fill="currentColor"
                            >
                                <path
                                    fillRule="evenodd"
                                    d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z"
                                    clipRule="evenodd"
                                />
                            </svg>
                        </div>
                        <div className="ml-3">
                            <p className="text-sm text-yellow-700">
                                {securityStatus?.remainingTransactions === 0
                                    ? 'Rate limit reached. Please wait before making more transactions.'
                                    : 'High transaction volume detected. Please proceed with caution.'}
                            </p>
                        </div>
                    </div>
                </div>
            )}

            {/* Main Content */}
            <div className="relative">
                {children}
            </div>

            {/* Security Footer */}
            <div className="bg-gray-50 border-t border-gray-200 mt-8">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-4">
                            <span className="text-sm text-gray-500">
                                Protected by Transaction Security
                            </span>
                            <span className="text-sm text-gray-500">•</span>
                            <span className="text-sm text-gray-500">
                                Max Transaction: 10 ETH
                            </span>
                            <span className="text-sm text-gray-500">•</span>
                            <span className="text-sm text-gray-500">
                                Max Gas Price: 100 gwei
                            </span>
                        </div>
                        <div className="flex items-center">
                            <svg
                                className="h-5 w-5 text-green-500"
                                viewBox="0 0 20 20"
                                fill="currentColor"
                            >
                                <path
                                    fillRule="evenodd"
                                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
                                    clipRule="evenodd"
                                />
                            </svg>
                            <span className="ml-2 text-sm text-gray-500">
                                Security Active
                            </span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
} 