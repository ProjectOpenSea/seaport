import { NextApiRequest, NextApiResponse } from 'next';
import { FarcasterIntegrationService } from '../services/farcaster-integration-service';
import { ArtworkVisualizationService } from '../services/artwork-visualization-service';
import { ArtworkReportingService } from '../services/artwork-reporting-service';
import { MarketAnalysisService } from '../services/market-analysis-service';
import { ethers } from 'ethers';

// Initialize services
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const visualizationService = new ArtworkVisualizationService(
    new ArtworkReportingService(),
    new MarketAnalysisService(),
    provider
);
const reportingService = new ArtworkReportingService();
const marketService = new MarketAnalysisService();

const farcasterService = new FarcasterIntegrationService(
    visualizationService,
    reportingService,
    marketService,
    provider
);

export default async function handler(
    req: NextApiRequest,
    res: NextApiResponse
) {
    if (req.method === 'GET') {
        const { artworkId, frameType = 'artwork', userRole = 'public' } = req.query;

        if (!artworkId) {
            return res.status(400).json({ error: 'Artwork ID is required' });
        }

        try {
            let frameHtml: string;

            switch (frameType) {
                case 'market':
                    frameHtml = await farcasterService.generateMarketTrendsFrameHtml(
                        artworkId as string
                    );
                    break;

                case 'curator':
                    if (userRole !== 'curator') {
                        return res.status(403).json({ error: 'Curator access required' });
                    }
                    frameHtml = await farcasterService.generateCuratorInsightsFrameHtml(
                        artworkId as string
                    );
                    break;

                case 'artwork':
                default:
                    frameHtml = await farcasterService.generateFrameHtml(
                        artworkId as string,
                        userRole as string
                    );
            }

            res.setHeader('Content-Type', 'text/html');
            return res.status(200).send(frameHtml);
        } catch (error) {
            console.error('Error generating frame:', error);
            return res.status(500).json({ error: 'Error generating frame' });
        }
    }

    if (req.method === 'POST') {
        const { artworkId, frameType = 'artwork', action, userAddress } = req.body;

        if (!artworkId || !action || !userAddress) {
            return res.status(400).json({
                error: 'Artwork ID, action, and user address are required'
            });
        }

        try {
            let result;

            switch (frameType) {
                case 'market':
                    result = await farcasterService.handleMarketFrameInteraction(
                        artworkId,
                        action,
                        userAddress
                    );
                    break;

                case 'curator':
                    result = await farcasterService.handleCuratorFrameInteraction(
                        artworkId,
                        action,
                        userAddress
                    );
                    break;

                case 'artwork':
                default:
                    result = await farcasterService.handleFrameInteraction(
                        artworkId,
                        action,
                        userAddress
                    );
            }

            return res.status(200).json(result);
        } catch (error) {
            console.error('Error handling frame interaction:', error);
            return res.status(500).json({ error: 'Error handling frame interaction' });
        }
    }

    return res.status(405).json({ error: 'Method not allowed' });
} 