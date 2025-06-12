# Seaport dApp 🚢

[![Next.js](https://img.shields.io/badge/Next.js-000000?style=for-the-badge&logo=next.js&logoColor=white)](https://nextjs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=for-the-badge&logo=tailwind-css&logoColor=white)](https://tailwindcss.com/)
[![Base](https://img.shields.io/badge/Base-0052FF?style=for-the-badge&logo=base&logoColor=white)](https://base.org/)
[![Avalanche](https://img.shields.io/badge/Avalanche-E84142?style=for-the-badge&logo=avalanche&logoColor=white)](https://www.avax.network/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

A modern, responsive dApp for creating and managing NFT orders on Base and Avalanche networks using the Seaport protocol. Built with Next.js, TypeScript, and Tailwind CSS.

![Seaport dApp Preview](public/preview.png)

## ✨ Features

- 🔐 **Secure Authentication**: Privy integration for wallet connection
- 📱 **Responsive Design**: Mobile-first approach with dark mode support
- 🔄 **Real-time Updates**: Live transaction tracking and order status
- 🎨 **Modern UI**: Beautiful gradients and smooth animations
- 📊 **Transaction History**: Track all your orders and transactions
- 🌙 **Dark Mode**: Toggle between light and dark themes
- 🌐 **Multi-chain Support**: Seamless integration with Base and Avalanche networks

## 🚀 Quick Start

### Prerequisites

- Node.js 16+
- npm or yarn
- Base or Avalanche network wallet
- Privy credentials

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/seaport-dapp.git
   cd seaport-dapp
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env.local
   ```
   Then edit `.env.local` with your actual values.

4. Start development server:
   ```bash
   npm run dev
   ```

5. Open [http://localhost:3000](http://localhost:3000) in your browser

## 🔒 Security

### Environment Variables
Never commit sensitive information to the repository. Use `.env.local` for local development and set up environment variables in your deployment platform.

Required environment variables:
- `NEXT_PUBLIC_PRIVY_APP_ID`: Your Privy application ID
- `NEXT_PUBLIC_PRIVY_CLIENT_ID`: Your Privy client ID
- `NEXT_PUBLIC_NFT_CONTRACT_ADDRESS`: Your NFT contract address
- `NEXT_PUBLIC_NFT_ID`: Your NFT ID
- `NEXT_PUBLIC_AVALANCHE_RPC_URL`: Avalanche RPC URL
- `NEXT_PUBLIC_BASE_RPC_URL`: Base RPC URL

### Security Features
The repository includes several security features to prevent accidental exposure of sensitive data:

1. **Pre-commit Hooks**
   - Automatically checks for sensitive data patterns before each commit
   - Prevents commits containing API keys, private keys, or other sensitive information
   - Creates automatic backups before each commit

2. **Git Secrets**
   - Installed and configured to detect sensitive data patterns
   - Checks for common patterns like API keys, private keys, and credentials
   - Includes blockchain-specific patterns for private keys and mnemonics

3. **Automatic Backups**
   - Creates timestamped backups before each commit
   - Stores backups in a dedicated branch
   - Helps prevent work loss in case of crashes or errors

To set up these security features:

```bash
# Install git-secrets
./scripts/setup-git-secrets.sh

# The pre-commit hook is automatically installed
# You can test it by trying to commit a file with sensitive data
```

### Security Best Practices
1. Never commit API keys or private keys
2. Use environment variables for sensitive data
3. Keep dependencies updated
4. Follow the principle of least privilege
5. Implement proper error handling
6. Use secure communication channels
7. Regular security audits

## 🛠️ Tech Stack

- **Framework**: [Next.js](https://nextjs.org/)
- **Language**: [TypeScript](https://www.typescriptlang.org/)
- **Styling**: [Tailwind CSS](https://tailwindcss.com/)
- **Authentication**: [Privy](https://privy.io/)
- **Blockchain**: 
  - [Base](https://base.org/)
  - [Avalanche](https://www.avax.network/)
- **Protocol**: [Seaport](https://opensea.io/blog/announcements/introducing-seaport-the-next-generation-web3-marketplace-protocol/)

## 🌐 Network Support

### Avalanche (AVAX)
- Mainnet (C-Chain)
- Fuji Testnet
- Custom RPC support
- Native AVAX token support
- Cross-chain compatibility

### Base
- Mainnet
- Goerli Testnet
- Optimized gas fees
- Fast transaction processing

## 📱 Mobile Support

The dApp is fully responsive and optimized for mobile devices:

- Touch-friendly interface
- Mobile menu navigation
- Optimized form inputs
- Full-width elements on mobile
- Smooth animations

## 🎨 UI Components

- Loading Spinner
- Network Badge
- Mobile Menu
- Transaction History
- Theme Toggle
- Order Form
- Status Indicators
- Network Switcher

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License and Copyright

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Copyright Notice
© 2024 ASKNIGHTS & PARTNERS. All rights reserved.

All new features, developments, and optimizations in this project are made by ASKNIGHTS & PARTNERS under the supervision of Sebastian Clej. All copyrights and intellectual property rights are owned by ASKNIGHTS & PARTNERS.

This includes but is not limited to:
- Custom implementations and modifications
- UI/UX designs and components
- Network integrations and optimizations
- Security implementations
- Mobile optimizations
- Cross-chain functionality

## 🙏 Acknowledgments

- [OpenSea](https://opensea.io/) for the Seaport protocol
- [Base](https://base.org/) for the network infrastructure
- [Avalanche](https://www.avax.network/) for the C-Chain infrastructure
- [Privy](https://privy.io/) for authentication
- [Next.js](https://nextjs.org/) team for the amazing framework

## 📞 Support

If you have any questions or need help, please:

- Open an issue
- Join our [Discord](https://discord.gg/your-discord)
- Follow us on [Twitter](https://twitter.com/your-handle)

---

Developed by ASKNIGHTS & PARTNERS
Supervised by Sebastian Clej

# API Keys
ALCHEMY_API_KEY=your_alchemy_key_here

# Wallet
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
