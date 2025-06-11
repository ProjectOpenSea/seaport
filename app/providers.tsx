'use client';

import { PrivyProvider } from '@privy-io/react-auth';

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <PrivyProvider
      appId={process.env.NEXT_PUBLIC_PRIVY_APP_ID || ''}
      clientId={process.env.NEXT_PUBLIC_PRIVY_CLIENT_ID || ''}
      config={{
        // Create embedded wallets for users who don't have a wallet
        embeddedWallets: {
          ethereum: {
            createOnLogin: 'users-without-wallets'
          }
        },
        // Add Base network configuration
        defaultChain: {
          id: 8453, // Base Mainnet
          name: 'Base',
          rpcUrl: 'https://mainnet.base.org',
          blockExplorer: 'https://basescan.org',
          nativeCurrency: {
            name: 'Ether',
            symbol: 'ETH',
            decimals: 18
          }
        },
        // Add supported chains
        supportedChains: [
          {
            id: 8453, // Base Mainnet
            name: 'Base',
            rpcUrl: 'https://mainnet.base.org',
            blockExplorer: 'https://basescan.org',
            nativeCurrency: {
              name: 'Ether',
              symbol: 'ETH',
              decimals: 18
            }
          }
        ]
      }}
    >
      {children}
    </PrivyProvider>
  );
} 