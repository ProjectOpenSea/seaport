export const FarcasterConfig = {
    // Frame configuration
    frame: {
        version: 'vNext',
        imageAspectRatio: '1:1',
        maxButtons: 4,
        buttonLabels: {
            viewDetails: 'View Details',
            approveArtwork: 'Approve Artwork',
            placeBid: 'Place Bid',
            viewMarket: 'View Market',
            viewTrends: 'View Trends',
            viewInsights: 'View Insights'
        },
        types: {
            artwork: {
                name: 'Artwork',
                description: 'Basic artwork information and actions',
                maxButtons: 4
            },
            market: {
                name: 'Market Trends',
                description: 'Market performance and trading data',
                maxButtons: 3,
                updateFrequency: 300 // 5 minutes
            },
            curator: {
                name: 'Curator Insights',
                description: 'Expert analysis and quality metrics',
                maxButtons: 3,
                updateFrequency: 3600 // 1 hour
            }
        }
    },

    // API endpoints
    api: {
        frame: '/api/farcaster/frame',
        interaction: '/api/farcaster/interaction',
        verification: '/api/farcaster/verify',
        market: '/api/farcaster/frame/market',
        curator: '/api/farcaster/frame/curator'
    },

    // Integration settings
    integration: {
        supportedApps: ['firefly', 'yup', 'warpcast'],
        frameTypes: ['artwork', 'market', 'curator'],
        updateFrequency: 300, // 5 minutes
        cacheDuration: 3600 // 1 hour
    },

    // Security settings
    security: {
        maxRequestsPerMinute: 60,
        requireAuthentication: true,
        allowedOrigins: [
            'https://warpcast.com',
            'https://firefly.xyz',
            'https://yup.io'
        ],
        roleBasedAccess: {
            curator: ['artwork', 'market', 'curator'],
            collector: ['artwork', 'market'],
            public: ['artwork']
        }
    },

    // Display settings
    display: {
        defaultImageSize: '1024x1024',
        quality: 'high',
        format: 'png',
        compression: {
            enabled: true,
            quality: 0.8
        },
        charts: {
            market: {
                type: 'line',
                colors: ['#4CAF50', '#2196F3', '#FFC107'],
                animation: true
            },
            quality: {
                type: 'radar',
                colors: ['#9C27B0', '#E91E63', '#FF9800'],
                animation: true
            }
        }
    },

    // Analytics settings
    analytics: {
        enabled: true,
        trackInteractions: true,
        trackImpressions: true,
        trackConversions: true,
        frameMetrics: {
            market: {
                trackPriceChanges: true,
                trackVolumeChanges: true,
                trackHolderChanges: true
            },
            curator: {
                trackApprovals: true,
                trackQualityChanges: true,
                trackVerificationStatus: true
            }
        }
    }
}; 