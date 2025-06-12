# Seaport dApp Documentation

## Overview
The Seaport dApp is a Next.js application that enables users to create, manage, and fulfill NFT orders on the Base network using the Seaport protocol. The application features a modern, responsive UI with dark mode support and mobile-first design.

## Features

### 1. Authentication & Wallet Integration
- Privy integration for secure wallet connection
- Support for multiple wallet types
- Network detection and switching
- Base Mainnet and Base Goerli support

### 2. Order Management
- Create new orders with ETH
- Cancel existing orders
- View order status and history
- Real-time transaction tracking
- Error handling and validation

### 3. User Interface
- Responsive design for mobile and desktop
- Dark mode support
- Loading states and animations
- Transaction history display
- Network status indicator
- Mobile menu for better navigation

### 4. Components

#### Core Components
- `LoadingSpinner`: Animated loading indicator
- `NetworkBadge`: Network status display
- `MobileMenu`: Responsive navigation menu
- `TransactionHistory`: Transaction list with status
- `ThemeToggle`: Dark/Light mode switch

#### Layout Components
- Main layout with responsive padding
- Card-based UI elements
- Gradient backgrounds
- Animated transitions

### 5. State Management
- Order status tracking
- Transaction history
- Error handling
- Loading states
- Theme management
- Mobile menu state

### 6. Styling & Design
- Tailwind CSS for styling
- Custom animations
- Gradient effects
- Responsive typography
- Dark mode color scheme
- Mobile-first approach

## Technical Implementation

### 1. Dependencies
```json
{
  "dependencies": {
    "@privy-io/react-auth": "latest",
    "ethers": "5.7.2",
    "@opensea/seaport-js": "latest",
    "next": "latest",
    "react": "latest",
    "react-dom": "latest"
  }
}
```

### 2. Environment Variables
```env
NEXT_PUBLIC_PRIVY_APP_ID=your-app-id
NEXT_PUBLIC_PRIVY_CLIENT_ID=your-client-id
NEXT_PUBLIC_NFT_CONTRACT_ADDRESS=your-nft-contract
NEXT_PUBLIC_NFT_ID=your-nft-id
```

### 3. Key Features Implementation

#### Wallet Connection
- Uses Privy for secure wallet connection
- Supports multiple wallet types
- Handles network switching
- Provides wallet status information

#### Order Creation
- Validates input amounts
- Handles ETH conversion
- Manages order creation process
- Provides real-time feedback

#### Transaction Management
- Tracks transaction status
- Maintains transaction history
- Handles errors gracefully
- Provides status updates

### 4. UI/UX Improvements

#### Mobile Experience
- Responsive layout
- Touch-friendly buttons
- Mobile menu navigation
- Optimized form inputs
- Full-width elements on mobile

#### Desktop Experience
- Multi-column layout
- Hover effects
- Keyboard navigation
- Detailed transaction view

#### Animations & Transitions
- Fade-in effects
- Loading spinners
- Button hover states
- Menu transitions
- Error shake animations

## Security Features
- Secure wallet connection
- Input validation
- Error handling
- Network security checks
- Transaction confirmation

## Performance Optimizations
- Lazy loading components
- Optimized animations
- Efficient state management
- Responsive image handling
- Mobile-first approach

## Future Improvements
1. Add more network support
2. Implement order fulfillment
3. Add NFT preview
4. Enhance transaction history
5. Add price charts
6. Implement order search
7. Add user profiles
8. Enhance mobile experience

## Getting Started

### Prerequisites
- Node.js 16+
- npm or yarn
- Base network wallet
- Privy credentials

### Installation
1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```
3. Create `.env.local` file
4. Start development server:
   ```bash
   npm run dev
   ```

### Usage
1. Connect wallet
2. Create new order
3. Monitor transaction status
4. View transaction history
5. Toggle dark mode
6. Use mobile menu on small screens

## Contributing
1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create pull request

## License
MIT License

## Network Support

### Base
- Mainnet
- Goerli Testnet
- Optimized gas fees
- Fast transaction processing

### Avalanche
- Mainnet (C-Chain)
- Fuji Testnet
- Custom RPC support
- Native AVAX token support
- Cross-chain compatibility

### Zora
- Mainnet
- Optimized for NFT trading
- Low gas fees
- Native ETH support
- Seamless integration with Zora.co marketplace

## Environment Variables

Required environment variables:
```env
# API Keys
ALCHEMY_API_KEY=your_alchemy_key_here

# Wallet Configuration
ENCRYPTED_PRIVATE_KEY=your_encrypted_private_key_here
ENCRYPTION_KEY=your_encryption_key_here

# NFT Details
NFT_CONTRACT_ADDRESS=your_nft_contract_address_here
NFT_ID=your_nft_id_here

# Contract Addresses
SEAPORT_ADDRESS=your_seaport_contract_address_here

# Privy Configuration
NEXT_PUBLIC_PRIVY_APP_ID=your_privy_app_id_here
NEXT_PUBLIC_PRIVY_CLIENT_ID=your_privy_client_id_here

# Network RPC URLs
NEXT_PUBLIC_AVALANCHE_RPC_URL=your_avalanche_rpc_url_here
NEXT_PUBLIC_BASE_RPC_URL=your_base_rpc_url_here
NEXT_PUBLIC_ZORA_RPC_URL=your_zora_rpc_url_here
```

## Network Configuration

### Base
```typescript
{
  id: 8453,
  name: 'Base',
  rpcUrl: process.env.NEXT_PUBLIC_BASE_RPC_URL || 'https://mainnet.base.org',
  blockExplorer: 'https://basescan.org',
  nativeCurrency: {
    name: 'ETH',
    symbol: 'ETH',
    decimals: 18,
  },
}
```

### Avalanche
```typescript
{
  id: 43114,
  name: 'Avalanche',
  rpcUrl: process.env.NEXT_PUBLIC_AVALANCHE_RPC_URL || 'https://api.avax.network/ext/bc/C/rpc',
  blockExplorer: 'https://snowtrace.io',
  nativeCurrency: {
    name: 'AVAX',
    symbol: 'AVAX',
    decimals: 18,
  },
}
```

### Zora
```typescript
{
  id: 7777777,
  name: 'Zora',
  rpcUrl: process.env.NEXT_PUBLIC_ZORA_RPC_URL || 'https://rpc.zora.energy',
  blockExplorer: 'https://explorer.zora.energy',
  nativeCurrency: {
    name: 'ETH',
    symbol: 'ETH',
    decimals: 18,
  },
}
```

## Seaport Integration

The dApp uses the Seaport protocol for NFT trading across all supported networks. The Seaport contract addresses are:

- Base: `0x00000000006c3852cbEf3e08E8dF289169EdE581`
- Avalanche: `0x00000000006c3852cbEf3e08E8dF289169EdE581`
- Zora: `0x00000000006c3852cbEf3e08E8dF289169EdE581`

## Zora.co Integration

The dApp integrates with Zora.co marketplace for enhanced NFT trading capabilities:

1. **Marketplace Integration**
   - Direct access to Zora.co listings
   - Real-time price feeds
   - Order synchronization

2. **Trading Features**
   - Buy and sell NFTs
   - Create and manage listings
   - Track order status
   - View transaction history

3. **Network Benefits**
   - Optimized gas fees
   - Fast transaction processing
   - Native ETH support
   - Seamless cross-chain trading

## Security Features

1. **Pre-commit Hooks**
   - Automatic sensitive data detection
   - Backup creation before commits
   - Pattern matching for secrets

2. **Git Secrets**
   - API key detection
   - Private key detection
   - Credential scanning

3. **Environment Variables**
   - Secure storage of sensitive data
   - Network-specific configurations
   - API key management

## Development Workflow

1. **Setup**
   ```bash
   # Clone the repository
   git clone https://github.com/yourusername/seaport-dapp.git
   cd seaport-dapp

   # Install dependencies
   npm install

   # Set up environment variables
   cp .env.example .env.local
   # Edit .env.local with your values

   # Install git-secrets
   ./scripts/setup-git-secrets.sh
   ```

2. **Development**
   ```bash
   # Start development server
   npm run dev
   ```

3. **Testing**
   ```bash
   # Run tests
   npm test

   # Run security checks
   npm run security
   ```

4. **Deployment**
   ```bash
   # Build for production
   npm run build

   # Deploy
   npm run deploy
   ```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 