import { ethers } from 'ethers';
import { ArtworkVisualizationService } from './artwork-visualization-service';
import { ArtworkReportingService } from './artwork-reporting-service';
import { MarketAnalysisService } from './market-analysis-service';

interface FrameMetadata {
    artworkId: string;
    title: string;
    artist: string;
    imageUrl: string;
    price: string;
    qualityScore: number;
    curatorApprovals: number;
}

interface FrameAction {
    label: string;
    action: string;
    target: string;
}

interface MarketTrendsMetadata {
    artworkId: string;
    priceTrend: {
        current: string;
        change24h: string;
        change7d: string;
    };
    volumeTrend: {
        current: string;
        change24h: string;
        change7d: string;
    };
    marketMetrics: {
        liquidity: string;
        holderCount: number;
        tradingActivity: string;
    };
    chartData: string; // Base64 encoded chart
}

interface CuratorInsightsMetadata {
    artworkId: string;
    qualityMetrics: {
        composition: number;
        execution: number;
        originality: number;
        technical: number;
    };
    curatorApprovals: {
        total: number;
        recent: number;
        topCurators: string[];
    };
    expertAnalysis: {
        strengths: string[];
        weaknesses: string[];
        recommendations: string[];
    };
    verificationStatus: {
        verified: boolean;
        verificationDate: string;
        verificationMethod: string;
    };
}

export class FarcasterIntegrationService {
    private readonly visualizationService: ArtworkVisualizationService;
    private readonly reportingService: ArtworkReportingService;
    private readonly marketService: MarketAnalysisService;
    private readonly provider: ethers.Provider;

    constructor(
        visualizationService: ArtworkVisualizationService,
        reportingService: ArtworkReportingService,
        marketService: MarketAnalysisService,
        provider: ethers.Provider
    ) {
        this.visualizationService = visualizationService;
        this.reportingService = reportingService;
        this.marketService = marketService;
        this.provider = provider;
    }

    /**
     * Generate Farcaster frame metadata for an artwork
     */
    async generateFrameMetadata(artworkId: string): Promise<FrameMetadata> {
        const report = await this.reportingService.generateArtworkReport(artworkId, 'public');
        const marketData = await this.marketService.analyzeMarketData(artworkId);

        return {
            artworkId,
            title: report.artworkInfo.title,
            artist: report.artworkInfo.artist,
            imageUrl: report.artworkInfo.imageUrl,
            price: marketData.priceData.currentPrice.toString(),
            qualityScore: report.qualityMetrics.overallScore,
            curatorApprovals: report.curatorApprovals.length
        };
    }

    /**
     * Generate frame actions based on artwork status and user role
     */
    async generateFrameActions(artworkId: string, userRole: string): Promise<FrameAction[]> {
        const actions: FrameAction[] = [
            {
                label: 'View Details',
                action: 'post_redirect',
                target: `${process.env.APP_URL}/artwork/${artworkId}`
            }
        ];

        if (userRole === 'curator') {
            actions.push({
                label: 'Approve Artwork',
                action: 'post',
                target: `${process.env.API_URL}/curator/approve/${artworkId}`
            });
        }

        if (userRole === 'collector') {
            actions.push({
                label: 'Place Bid',
                action: 'post',
                target: `${process.env.API_URL}/marketplace/bid/${artworkId}`
            });
        }

        return actions;
    }

    /**
     * Generate frame HTML for Farcaster
     */
    async generateFrameHtml(artworkId: string, userRole: string): Promise<string> {
        const metadata = await this.generateFrameMetadata(artworkId);
        const actions = await this.generateFrameActions(artworkId, userRole);

        return `
            <!DOCTYPE html>
            <html>
                <head>
                    <meta property="og:title" content="${metadata.title} by ${metadata.artist}" />
                    <meta property="og:image" content="${metadata.imageUrl}" />
                    <meta property="fc:frame" content="vNext" />
                    <meta property="fc:frame:image" content="${metadata.imageUrl}" />
                    <meta property="fc:frame:button:1" content="View Details" />
                    ${actions.map((action, index) => `
                        <meta property="fc:frame:button:${index + 2}" content="${action.label}" />
                    `).join('')}
                    <meta property="fc:frame:post_url" content="${process.env.API_URL}/farcaster/frame/${artworkId}" />
                </head>
                <body>
                    <div style="display: flex; flex-direction: column; align-items: center; padding: 20px;">
                        <img src="${metadata.imageUrl}" style="max-width: 100%; height: auto;" />
                        <h2>${metadata.title}</h2>
                        <p>by ${metadata.artist}</p>
                        <p>Price: ${metadata.price} ETH</p>
                        <p>Quality Score: ${metadata.qualityScore}</p>
                        <p>Curator Approvals: ${metadata.curatorApprovals}</p>
                    </div>
                </body>
            </html>
        `;
    }

    /**
     * Handle frame interactions
     */
    async handleFrameInteraction(
        artworkId: string,
        action: string,
        userAddress: string
    ): Promise<{ success: boolean; message: string }> {
        try {
            switch (action) {
                case 'view_details':
                    return {
                        success: true,
                        message: `Redirecting to artwork details: ${process.env.APP_URL}/artwork/${artworkId}`
                    };

                case 'approve_artwork':
                    // Verify curator status
                    const isCurator = await this.verifyCuratorStatus(userAddress);
                    if (!isCurator) {
                        return {
                            success: false,
                            message: 'Only curators can approve artworks'
                        };
                    }

                    // Process curator approval
                    await this.processCuratorApproval(artworkId, userAddress);
                    return {
                        success: true,
                        message: 'Artwork approved successfully'
                    };

                case 'place_bid':
                    // Verify collector status
                    const isCollector = await this.verifyCollectorStatus(userAddress);
                    if (!isCollector) {
                        return {
                            success: false,
                            message: 'Only collectors can place bids'
                        };
                    }

                    // Process bid placement
                    await this.processBidPlacement(artworkId, userAddress);
                    return {
                        success: true,
                        message: 'Bid placed successfully'
                    };

                default:
                    return {
                        success: false,
                        message: 'Invalid action'
                    };
            }
        } catch (error) {
            console.error('Frame interaction error:', error);
            return {
                success: false,
                message: 'Error processing frame interaction'
            };
        }
    }

    /**
     * Verify curator status
     */
    private async verifyCuratorStatus(address: string): Promise<boolean> {
        // Implement curator verification logic
        return false;
    }

    /**
     * Verify collector status
     */
    private async verifyCollectorStatus(address: string): Promise<boolean> {
        // Implement collector verification logic
        return false;
    }

    /**
     * Process curator approval
     */
    private async processCuratorApproval(artworkId: string, curatorAddress: string): Promise<void> {
        // Implement curator approval logic
    }

    /**
     * Process bid placement
     */
    private async processBidPlacement(artworkId: string, collectorAddress: string): Promise<void> {
        // Implement bid placement logic
    }

    /**
     * Generate market trends frame metadata
     */
    async generateMarketTrendsFrame(artworkId: string): Promise<MarketTrendsMetadata> {
        const marketData = await this.marketService.analyzeMarketData(artworkId);
        const chart = await this.visualizationService.generateMarketChart(artworkId);

        return {
            artworkId,
            priceTrend: {
                current: marketData.priceData.currentPrice.toString(),
                change24h: marketData.priceData.priceChange24h.toString(),
                change7d: marketData.priceData.priceChange7d.toString()
            },
            volumeTrend: {
                current: marketData.volumeData.currentVolume.toString(),
                change24h: marketData.volumeData.volumeChange24h.toString(),
                change7d: marketData.volumeData.volumeChange7d.toString()
            },
            marketMetrics: {
                liquidity: marketData.liquidityMetrics.currentLiquidity.toString(),
                holderCount: marketData.holderData.totalHolders,
                tradingActivity: marketData.tradingPatterns.activityLevel
            },
            chartData: chart.toString('base64')
        };
    }

    /**
     * Generate curator insights frame metadata
     */
    async generateCuratorInsightsFrame(artworkId: string): Promise<CuratorInsightsMetadata> {
        const report = await this.reportingService.generateArtworkReport(artworkId, 'curator');
        const marketData = await this.marketService.analyzeMarketData(artworkId);

        return {
            artworkId,
            qualityMetrics: {
                composition: report.qualityMetrics.compositionScore,
                execution: report.qualityMetrics.executionScore,
                originality: report.qualityMetrics.originalityScore,
                technical: report.qualityMetrics.technicalScore
            },
            curatorApprovals: {
                total: report.curatorApprovals.length,
                recent: report.curatorApprovals.filter(a =>
                    Date.now() - new Date(a.timestamp).getTime() < 7 * 24 * 60 * 60 * 1000
                ).length,
                topCurators: report.curatorApprovals
                    .sort((a, b) => b.reputation - a.reputation)
                    .slice(0, 3)
                    .map(a => a.curatorAddress)
            },
            expertAnalysis: {
                strengths: report.expertAnalysis.strengths,
                weaknesses: report.expertAnalysis.weaknesses,
                recommendations: report.expertAnalysis.recommendations
            },
            verificationStatus: {
                verified: report.verificationStatus.verified,
                verificationDate: report.verificationStatus.verificationDate,
                verificationMethod: report.verificationStatus.verificationMethod
            }
        };
    }

    /**
     * Generate frame HTML for market trends
     */
    async generateMarketTrendsFrameHtml(artworkId: string): Promise<string> {
        const metadata = await this.generateMarketTrendsFrame(artworkId);
        const actions = await this.generateFrameActions(artworkId, 'public');

        return `
            <!DOCTYPE html>
            <html>
                <head>
                    <meta property="og:title" content="Market Trends - ${artworkId}" />
                    <meta property="og:image" content="data:image/png;base64,${metadata.chartData}" />
                    <meta property="fc:frame" content="vNext" />
                    <meta property="fc:frame:image" content="data:image/png;base64,${metadata.chartData}" />
                    ${actions.map((action, index) => `
                        <meta property="fc:frame:button:${index + 1}" content="${action.label}" />
                    `).join('')}
                    <meta property="fc:frame:post_url" content="${process.env.API_URL}/farcaster/frame/market/${artworkId}" />
                </head>
                <body>
                    <div style="display: flex; flex-direction: column; align-items: center; padding: 20px;">
                        <h2>Market Trends</h2>
                        <div style="margin: 20px 0;">
                            <h3>Price Trends</h3>
                            <p>Current: ${metadata.priceTrend.current} ETH</p>
                            <p>24h Change: ${metadata.priceTrend.change24h}%</p>
                            <p>7d Change: ${metadata.priceTrend.change7d}%</p>
                        </div>
                        <div style="margin: 20px 0;">
                            <h3>Volume Trends</h3>
                            <p>Current: ${metadata.volumeTrend.current} ETH</p>
                            <p>24h Change: ${metadata.volumeTrend.change24h}%</p>
                            <p>7d Change: ${metadata.volumeTrend.change7d}%</p>
                        </div>
                        <div style="margin: 20px 0;">
                            <h3>Market Metrics</h3>
                            <p>Liquidity: ${metadata.marketMetrics.liquidity} ETH</p>
                            <p>Holders: ${metadata.marketMetrics.holderCount}</p>
                            <p>Activity: ${metadata.marketMetrics.tradingActivity}</p>
                        </div>
                    </div>
                </body>
            </html>
        `;
    }

    /**
     * Generate frame HTML for curator insights
     */
    async generateCuratorInsightsFrameHtml(artworkId: string): Promise<string> {
        const metadata = await this.generateCuratorInsightsFrame(artworkId);
        const actions = await this.generateFrameActions(artworkId, 'curator');

        return `
            <!DOCTYPE html>
            <html>
                <head>
                    <meta property="og:title" content="Curator Insights - ${artworkId}" />
                    <meta property="og:image" content="${process.env.APP_URL}/api/curator/insights/${artworkId}/preview" />
                    <meta property="fc:frame" content="vNext" />
                    <meta property="fc:frame:image" content="${process.env.APP_URL}/api/curator/insights/${artworkId}/preview" />
                    ${actions.map((action, index) => `
                        <meta property="fc:frame:button:${index + 1}" content="${action.label}" />
                    `).join('')}
                    <meta property="fc:frame:post_url" content="${process.env.API_URL}/farcaster/frame/curator/${artworkId}" />
                </head>
                <body>
                    <div style="display: flex; flex-direction: column; align-items: center; padding: 20px;">
                        <h2>Curator Insights</h2>
                        <div style="margin: 20px 0;">
                            <h3>Quality Metrics</h3>
                            <p>Composition: ${metadata.qualityMetrics.composition}/10</p>
                            <p>Execution: ${metadata.qualityMetrics.execution}/10</p>
                            <p>Originality: ${metadata.qualityMetrics.originality}/10</p>
                            <p>Technical: ${metadata.qualityMetrics.technical}/10</p>
                        </div>
                        <div style="margin: 20px 0;">
                            <h3>Curator Approvals</h3>
                            <p>Total: ${metadata.curatorApprovals.total}</p>
                            <p>Recent: ${metadata.curatorApprovals.recent}</p>
                            <p>Top Curators: ${metadata.curatorApprovals.topCurators.join(', ')}</p>
                        </div>
                        <div style="margin: 20px 0;">
                            <h3>Expert Analysis</h3>
                            <p>Strengths: ${metadata.expertAnalysis.strengths.join(', ')}</p>
                            <p>Weaknesses: ${metadata.expertAnalysis.weaknesses.join(', ')}</p>
                            <p>Recommendations: ${metadata.expertAnalysis.recommendations.join(', ')}</p>
                        </div>
                        <div style="margin: 20px 0;">
                            <h3>Verification Status</h3>
                            <p>Verified: ${metadata.verificationStatus.verified ? 'Yes' : 'No'}</p>
                            <p>Date: ${metadata.verificationStatus.verificationDate}</p>
                            <p>Method: ${metadata.verificationStatus.verificationMethod}</p>
                        </div>
                    </div>
                </body>
            </html>
        `;
    }
} 