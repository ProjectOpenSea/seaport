'use client';

import React from 'react';
import { PrivyProvider } from '@privy-io/react-auth';
import { base, avalanche, zora } from 'viem/chains';

const ZORA_CHAIN = {
  ...zora,
  rpcUrls: {
    default: {
      http: [process.env.NEXT_PUBLIC_ZORA_RPC_URL || 'https://rpc.zora.energy'],
    },
    public: {
      http: [process.env.NEXT_PUBLIC_ZORA_RPC_URL || 'https://rpc.zora.energy'],
    },
  },
};

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <PrivyProvider
      appId={process.env.NEXT_PUBLIC_PRIVY_APP_ID || ''}
      config={{
        supportedChains: [base, avalanche, ZORA_CHAIN],
        appearance: {
          theme: 'dark',
          accentColor: '#0052FF',
        },
        embeddedWallets: {
          createOnLogin: 'all-users',
        },
      }}
    >
      {children}
    </PrivyProvider>
  );
} 