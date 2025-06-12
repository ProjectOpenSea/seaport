import { useState } from 'react';
import { useZoraRodeo } from '../hooks/useZoraRodeo';
import { usePrivy } from '@privy-io/react-auth';

export function ZoraRodeoMinter() {
    const { user } = usePrivy();
    const {
        mintOnZora,
        listOnZora,
        mintOnRodeo,
        listOnRodeo,
        isLoading,
        error,
    } = useZoraRodeo();

    const [mintingOptions, setMintingOptions] = useState({
        artistAddress: '',
        price: '',
        maxSupply: 1,
        royaltyBps: 500, // 5% royalty
        metadata: {
            name: '',
            description: '',
            image: '',
            attributes: [],
        },
    });

    const [listingOptions, setListingOptions] = useState({
        tokenId: '',
        price: '',
        isAuction: false,
        endTime: 0,
    });

    const handleMint = async (platform: 'zora' | 'rodeo') => {
        try {
            if (platform === 'zora') {
                await mintOnZora(mintingOptions);
            } else {
                await mintOnRodeo(mintingOptions);
            }
        } catch (err) {
            console.error('Minting error:', err);
        }
    };

    const handleList = async (platform: 'zora' | 'rodeo') => {
        try {
            if (platform === 'zora') {
                await listOnZora(listingOptions);
            } else {
                await listOnRodeo(listingOptions);
            }
        } catch (err) {
            console.error('Listing error:', err);
        }
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
            <h2 className="text-2xl font-bold mb-6">Mint & List NFTs</h2>

            {/* Minting Form */}
            <div className="bg-white rounded-lg shadow-md p-6 mb-6">
                <h3 className="text-xl font-semibold mb-4">Mint New NFT</h3>
                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Artist Address</label>
                        <input
                            type="text"
                            value={mintingOptions.artistAddress}
                            onChange={(e) => setMintingOptions({ ...mintingOptions, artistAddress: e.target.value })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Price (ETH)</label>
                        <input
                            type="number"
                            value={mintingOptions.price}
                            onChange={(e) => setMintingOptions({ ...mintingOptions, price: e.target.value })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Max Supply</label>
                        <input
                            type="number"
                            value={mintingOptions.maxSupply}
                            onChange={(e) => setMintingOptions({ ...mintingOptions, maxSupply: parseInt(e.target.value) })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700">NFT Name</label>
                        <input
                            type="text"
                            value={mintingOptions.metadata.name}
                            onChange={(e) => setMintingOptions({
                                ...mintingOptions,
                                metadata: { ...mintingOptions.metadata, name: e.target.value }
                            })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Description</label>
                        <textarea
                            value={mintingOptions.metadata.description}
                            onChange={(e) => setMintingOptions({
                                ...mintingOptions,
                                metadata: { ...mintingOptions.metadata, description: e.target.value }
                            })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Image URL</label>
                        <input
                            type="text"
                            value={mintingOptions.metadata.image}
                            onChange={(e) => setMintingOptions({
                                ...mintingOptions,
                                metadata: { ...mintingOptions.metadata, image: e.target.value }
                            })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        />
                    </div>
                    <div className="flex space-x-4">
                        <button
                            onClick={() => handleMint('zora')}
                            disabled={isLoading}
                            className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                        >
                            Mint on Zora
                        </button>
                        <button
                            onClick={() => handleMint('rodeo')}
                            disabled={isLoading}
                            className="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                        >
                            Mint on Rodeo
                        </button>
                    </div>
                </div>
            </div>

            {/* Listing Form */}
            <div className="bg-white rounded-lg shadow-md p-6">
                <h3 className="text-xl font-semibold mb-4">List NFT</h3>
                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Token ID</label>
                        <input
                            type="text"
                            value={listingOptions.tokenId}
                            onChange={(e) => setListingOptions({ ...listingOptions, tokenId: e.target.value })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700">Price (ETH)</label>
                        <input
                            type="number"
                            value={listingOptions.price}
                            onChange={(e) => setListingOptions({ ...listingOptions, price: e.target.value })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                        />
                    </div>
                    <div className="flex items-center">
                        <input
                            type="checkbox"
                            checked={listingOptions.isAuction}
                            onChange={(e) => setListingOptions({ ...listingOptions, isAuction: e.target.checked })}
                            className="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                        />
                        <label className="ml-2 block text-sm text-gray-900">Auction</label>
                    </div>
                    {listingOptions.isAuction && (
                        <div>
                            <label className="block text-sm font-medium text-gray-700">End Time (Unix timestamp)</label>
                            <input
                                type="number"
                                value={listingOptions.endTime}
                                onChange={(e) => setListingOptions({ ...listingOptions, endTime: parseInt(e.target.value) })}
                                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                            />
                        </div>
                    )}
                    <div className="flex space-x-4">
                        <button
                            onClick={() => handleList('zora')}
                            disabled={isLoading}
                            className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                        >
                            List on Zora
                        </button>
                        <button
                            onClick={() => handleList('rodeo')}
                            disabled={isLoading}
                            className="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2"
                        >
                            List on Rodeo
                        </button>
                    </div>
                </div>
            </div>

            {error && (
                <div className="mt-4 p-4 bg-red-50 text-red-700 rounded-md">
                    {error}
                </div>
            )}
        </div>
    );
} 