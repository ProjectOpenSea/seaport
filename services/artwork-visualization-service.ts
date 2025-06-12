import { ethers } from 'ethers';
import { ArtworkReportingService } from './artwork-reporting-service';
import { MarketAnalysisService } from './market-analysis-service';
import { config } from 'dotenv';
import * as d3 from 'd3';
import { ChartJSNodeCanvas } from 'chartjs-node-canvas';

config();

export class ArtworkVisualizationService {
    private reportingService: ArtworkReportingService;
    private marketService: MarketAnalysisService;
    private provider: ethers.providers.Provider;
    private chartJSNodeCanvas: ChartJSNodeCanvas;

    constructor(
        reportingService: ArtworkReportingService,
        marketService: MarketAnalysisService,
        provider: ethers.providers.Provider
    ) {
        this.reportingService = reportingService;
        this.marketService = marketService;
        this.provider = provider;
        this.chartJSNodeCanvas = new ChartJSNodeCanvas({
            width: 800,
            height: 600,
            backgroundColour: 'white'
        });
    }

    /**
     * Generate comprehensive visualization package
     */
    async generateVisualizationPackage(
        artworkId: string,
        imageUrl: string,
        metadata: any,
        requesterRole: 'curator' | 'collector' | 'public'
    ): Promise<VisualizationPackage> {
        const report = await this.reportingService.generateArtworkReport(
            artworkId,
            imageUrl,
            metadata,
            requesterRole
        );

        const visualizations = await this.generateVisualizations(report, requesterRole);
        const onChainData = this.prepareOnChainData(report, visualizations);

        return {
            visualizations,
            onChainData,
            metadata: this.prepareMetadata(report, requesterRole)
        };
    }

    /**
     * Generate all visualizations based on report data
     */
    private async generateVisualizations(
        report: any,
        role: 'curator' | 'collector' | 'public'
    ): Promise<Visualizations> {
        const [
            marketChart,
            qualityChart,
            similarityChart,
            trendChart
        ] = await Promise.all([
            this.generateMarketChart(report),
            this.generateQualityChart(report),
            this.generateSimilarityChart(report),
            this.generateTrendChart(report)
        ]);

        return {
            marketChart,
            qualityChart,
            similarityChart,
            trendChart,
            additionalCharts: role === 'curator' ? await this.generateCuratorCharts(report) : undefined
        };
    }

    /**
     * Generate market performance chart
     */
    private async generateMarketChart(report: any): Promise<ChartData> {
        const data = {
            labels: report.marketOverview.priceHistory.map((p: any) =>
                new Date(p.timestamp).toLocaleDateString()
            ),
            datasets: [{
                label: 'Price History',
                data: report.marketOverview.priceHistory.map((p: any) => p.price),
                borderColor: 'rgb(75, 192, 192)',
                tension: 0.1
            }]
        };

        const config = {
            type: 'line',
            data,
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Market Performance'
                    }
                }
            }
        };

        return {
            type: 'market',
            data: await this.chartJSNodeCanvas.renderToBuffer(config),
            metadata: {
                timeframe: '30d',
                metrics: ['price', 'volume']
            }
        };
    }

    /**
     * Generate quality assessment chart
     */
    private async generateQualityChart(report: any): Promise<ChartData> {
        const data = {
            labels: ['Composition', 'Execution', 'Originality', 'Technical Proficiency'],
            datasets: [{
                label: 'Quality Metrics',
                data: [
                    report.qualityMetrics.composition,
                    report.qualityMetrics.execution,
                    report.qualityMetrics.originality,
                    report.qualityMetrics.technicalProficiency
                ],
                backgroundColor: [
                    'rgba(255, 99, 132, 0.5)',
                    'rgba(54, 162, 235, 0.5)',
                    'rgba(255, 206, 86, 0.5)',
                    'rgba(75, 192, 192, 0.5)'
                ]
            }]
        };

        const config = {
            type: 'radar',
            data,
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Quality Assessment'
                    }
                }
            }
        };

        return {
            type: 'quality',
            data: await this.chartJSNodeCanvas.renderToBuffer(config),
            metadata: {
                metrics: ['composition', 'execution', 'originality', 'technical']
            }
        };
    }

    /**
     * Generate similarity analysis chart
     */
    private async generateSimilarityChart(report: any): Promise<ChartData> {
        const data = {
            labels: ['Style', 'Technique', 'Composition', 'Color'],
            datasets: [{
                label: 'Similarity Scores',
                data: [
                    report.similarityInfo.styleScore,
                    report.similarityInfo.techniqueScore,
                    report.similarityInfo.compositionScore,
                    report.similarityInfo.colorScore
                ],
                backgroundColor: 'rgba(75, 192, 192, 0.5)'
            }]
        };

        const config = {
            type: 'bar',
            data,
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Similarity Analysis'
                    }
                }
            }
        };

        return {
            type: 'similarity',
            data: await this.chartJSNodeCanvas.renderToBuffer(config),
            metadata: {
                metrics: ['style', 'technique', 'composition', 'color']
            }
        };
    }

    /**
     * Generate trend analysis chart
     */
    private async generateTrendChart(report: any): Promise<ChartData> {
        const data = {
            labels: report.marketOverview.priceHistory.map((p: any) =>
                new Date(p.timestamp).toLocaleDateString()
            ),
            datasets: [{
                label: 'Price Trend',
                data: report.marketOverview.priceHistory.map((p: any) => p.price),
                borderColor: 'rgb(75, 192, 192)',
                tension: 0.1
            }, {
                label: 'Volume Trend',
                data: report.marketOverview.priceHistory.map((p: any) => p.volume),
                borderColor: 'rgb(255, 99, 132)',
                tension: 0.1
            }]
        };

        const config = {
            type: 'line',
            data,
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Market Trends'
                    }
                }
            }
        };

        return {
            type: 'trend',
            data: await this.chartJSNodeCanvas.renderToBuffer(config),
            metadata: {
                timeframe: '30d',
                metrics: ['price', 'volume']
            }
        };
    }

    /**
     * Generate curator-specific charts
     */
    private async generateCuratorCharts(report: any): Promise<CuratorCharts> {
        return {
            manipulationChart: await this.generateManipulationChart(report),
            detailedAnalysisChart: await this.generateDetailedAnalysisChart(report),
            marketDepthChart: await this.generateMarketDepthChart(report)
        };
    }

    /**
     * Prepare data for on-chain storage
     */
    private prepareOnChainData(report: any, visualizations: any): OnChainData {
        return {
            // Critical data that needs to be on-chain
            artworkId: report.basicInfo.artworkId,
            timestamp: Date.now(),
            qualityScore: report.qualityMetrics.overallQuality,
            originalityScore: report.qualityMetrics.originality,
            marketMetrics: {
                currentPrice: report.marketOverview.currentPrice,
                tradingVolume: report.marketOverview.tradingVolume,
                holderCount: report.marketOverview.holderCount
            },
            verificationStatus: {
                isVerified: report.verificationStatus.isVerified,
                verificationTimestamp: report.verificationStatus.timestamp
            },
            // Hash of off-chain data for verification
            offChainDataHash: this.calculateOffChainDataHash(report, visualizations)
        };
    }

    /**
     * Calculate hash of off-chain data
     */
    private calculateOffChainDataHash(report: any, visualizations: any): string {
        const dataToHash = {
            report,
            visualizations
        };
        return ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes(JSON.stringify(dataToHash))
        );
    }

    /**
     * Prepare metadata for visualization package
     */
    private prepareMetadata(report: any, role: string): VisualizationMetadata {
        return {
            version: '1.0',
            timestamp: Date.now(),
            role,
            dataSources: this.getDataSources(report),
            updateFrequency: 'daily',
            lastUpdate: report.timestamp
        };
    }
}

// Type definitions
interface VisualizationPackage {
    visualizations: Visualizations;
    onChainData: OnChainData;
    metadata: VisualizationMetadata;
}

interface Visualizations {
    marketChart: ChartData;
    qualityChart: ChartData;
    similarityChart: ChartData;
    trendChart: ChartData;
    additionalCharts?: CuratorCharts;
}

interface ChartData {
    type: string;
    data: Buffer;
    metadata: {
        timeframe?: string;
        metrics: string[];
    };
}

interface CuratorCharts {
    manipulationChart: ChartData;
    detailedAnalysisChart: ChartData;
    marketDepthChart: ChartData;
}

interface OnChainData {
    artworkId: string;
    timestamp: number;
    qualityScore: number;
    originalityScore: number;
    marketMetrics: {
        currentPrice: number;
        tradingVolume: number;
        holderCount: number;
    };
    verificationStatus: {
        isVerified: boolean;
        verificationTimestamp: number;
    };
    offChainDataHash: string;
}

interface VisualizationMetadata {
    version: string;
    timestamp: number;
    role: string;
    dataSources: string[];
    updateFrequency: string;
    lastUpdate: number;
} 