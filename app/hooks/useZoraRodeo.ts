import { useState, useCallback } from 'react';
import { usePrivy } from '@privy-io/react-auth';
import { zora } from 'viem/chains';
import { ethers } from 'ethers';

// Zora.co contract addresses
const ZORA_CONTRACTS = {
    MARKETPLACE: '0x0000000000000000000000000000000000000000', // Replace with actual address
    MINTING: '0x0000000000000000000000000000000000000000', // Replace with actual address
};

// Rodeo.club contract addresses
const RODEO_CONTRACTS = {
    MARKETPLACE: '0x0000000000000000000000000000000000000000', // Replace with actual address
    MINTING: '0x0000000000000000000000000000000000000000', // Replace with actual address
};

export type MintingOptions = {
    artistAddress: string;
    price: string;
    maxSupply: number;
    royaltyBps: number;
    metadata: {
        name: string;
        description: string;
        image: string;
        attributes?: Array<{
            trait_type: string;
            value: string;
        }>;
    };
};

export type MarketplaceListing = {
    tokenId: string;
    price: string;
    seller: string;
    isAuction: boolean;
    endTime?: number;
};

export function useZoraRodeo() {
    const { user } = usePrivy();
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Mint new NFT on Zora
    const mintOnZora = useCallback(async (options: MintingOptions) => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        try {
            setIsLoading(true);
            setError(null);

            const provider = new ethers.providers.Web3Provider(user.wallet.provider);
            const signer = provider.getSigner();

            // Create contract instance
            const mintingContract = new ethers.Contract(
                ZORA_CONTRACTS.MINTING,
                [
                    'function mint(address artist, uint256 price, uint256 maxSupply, uint256 royaltyBps, string memory metadata) returns (uint256)',
                ],
                signer
            );

            // Mint NFT
            const tx = await mintingContract.mint(
                options.artistAddress,
                ethers.utils.parseEther(options.price),
                options.maxSupply,
                options.royaltyBps,
                JSON.stringify(options.metadata)
            );

            const receipt = await tx.wait();
            return receipt;
        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
            setError(errorMessage);
            throw new Error(errorMessage);
        } finally {
            setIsLoading(false);
        }
    }, [user]);

    // List NFT on Zora marketplace
    const listOnZora = useCallback(async (listing: MarketplaceListing) => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        try {
            setIsLoading(true);
            setError(null);

            const provider = new ethers.providers.Web3Provider(user.wallet.provider);
            const signer = provider.getSigner();

            // Create contract instance
            const marketplaceContract = new ethers.Contract(
                ZORA_CONTRACTS.MARKETPLACE,
                [
                    'function listNFT(uint256 tokenId, uint256 price, bool isAuction, uint256 endTime)',
                ],
                signer
            );

            // List NFT
            const tx = await marketplaceContract.listNFT(
                listing.tokenId,
                ethers.utils.parseEther(listing.price),
                listing.isAuction,
                listing.endTime || 0
            );

            const receipt = await tx.wait();
            return receipt;
        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
            setError(errorMessage);
            throw new Error(errorMessage);
        } finally {
            setIsLoading(false);
        }
    }, [user]);

    // Mint on Rodeo.club (cheapest mints)
    const mintOnRodeo = useCallback(async (options: MintingOptions) => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        try {
            setIsLoading(true);
            setError(null);

            const provider = new ethers.providers.Web3Provider(user.wallet.provider);
            const signer = provider.getSigner();

            // Create contract instance
            const mintingContract = new ethers.Contract(
                RODEO_CONTRACTS.MINTING,
                [
                    'function mint(address artist, uint256 price, uint256 maxSupply, uint256 royaltyBps, string memory metadata) returns (uint256)',
                ],
                signer
            );

            // Mint NFT with optimized gas
            const tx = await mintingContract.mint(
                options.artistAddress,
                ethers.utils.parseEther(options.price),
                options.maxSupply,
                options.royaltyBps,
                JSON.stringify(options.metadata),
                {
                    gasLimit: 500000, // Optimized gas limit for Rodeo
                }
            );

            const receipt = await tx.wait();
            return receipt;
        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
            setError(errorMessage);
            throw new Error(errorMessage);
        } finally {
            setIsLoading(false);
        }
    }, [user]);

    // List on Rodeo marketplace
    const listOnRodeo = useCallback(async (listing: MarketplaceListing) => {
        if (!user?.wallet) {
            throw new Error('Wallet not connected');
        }

        try {
            setIsLoading(true);
            setError(null);

            const provider = new ethers.providers.Web3Provider(user.wallet.provider);
            const signer = provider.getSigner();

            // Create contract instance
            const marketplaceContract = new ethers.Contract(
                RODEO_CONTRACTS.MARKETPLACE,
                [
                    'function listNFT(uint256 tokenId, uint256 price, bool isAuction, uint256 endTime)',
                ],
                signer
            );

            // List NFT with optimized gas
            const tx = await marketplaceContract.listNFT(
                listing.tokenId,
                ethers.utils.parseEther(listing.price),
                listing.isAuction,
                listing.endTime || 0,
                {
                    gasLimit: 300000, // Optimized gas limit for Rodeo
                }
            );

            const receipt = await tx.wait();
            return receipt;
        } catch (err) {
            const errorMessage = err instanceof Error ? err.message : 'Unknown error occurred';
            setError(errorMessage);
            throw new Error(errorMessage);
        } finally {
            setIsLoading(false);
        }
    }, [user]);

    return {
        mintOnZora,
        listOnZora,
        mintOnRodeo,
        listOnRodeo,
        isLoading,
        error,
    };
} 