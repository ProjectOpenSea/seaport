'use client';

import React from 'react';
import { PrivyProvider } from '@privy-io/react-auth';
import { base, avalanche } from 'viem/chains';

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <PrivyProvider
      appId={process.env.NEXT_PUBLIC_PRIVY_APP_ID || ''}
      config={{
        embeddedWallets: {
          createOnLogin: 'all-users',
        },
        supportedChains: [
          {
            id: base.id,
            name: 'Base',
            rpcUrl: process.env.NEXT_PUBLIC_BASE_RPC_URL || 'https://mainnet.base.org',
            blockExplorer: 'https://basescan.org',
            nativeCurrency: {
              name: 'ETH',
              symbol: 'ETH',
              decimals: 18,
            },
          },
          {
            id: avalanche.id,
            name: 'Avalanche',
            rpcUrl: process.env.NEXT_PUBLIC_AVALANCHE_RPC_URL || 'https://api.avax.network/ext/bc/C/rpc',
            blockExplorer: 'https://snowtrace.io',
            nativeCurrency: {
              name: 'AVAX',
              symbol: 'AVAX',
              decimals: 18,
            },
          },
        ],
        defaultChain: base,
      }}
    >
      {children}
    </PrivyProvider>
  );
} 