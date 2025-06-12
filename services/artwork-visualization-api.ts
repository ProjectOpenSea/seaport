import express from 'express';
import { ethers } from 'ethers';
import { ArtworkVisualizationService } from './artwork-visualization-service';
import { ArtworkVisualizationStorage } from '../typechain-types';
import { config } from 'dotenv';
import { rateLimit } from 'express-rate-limit';
import { validateRequest } from './middleware/validation';
import { authenticateUser } from './middleware/auth';
import { cacheMiddleware } from './middleware/cache';

config();

export class ArtworkVisualizationAPI {
    private app: express.Application;
    private visualizationService: ArtworkVisualizationService;
    private contract: ArtworkVisualizationStorage;
    private provider: ethers.providers.Provider;

    constructor(
        visualizationService: ArtworkVisualizationService,
        contractAddress: string,
        provider: ethers.providers.Provider
    ) {
        this.app = express();
        this.visualizationService = visualizationService;
        this.provider = provider;
        this.contract = new ethers.Contract(
            contractAddress,
            ArtworkVisualizationStorage.abi,
            provider
        ) as unknown as ArtworkVisualizationStorage;

        this.setupMiddleware();
        this.setupRoutes();
    }

    /**
     * Setup API middleware
     */
    private setupMiddleware() {
        // Rate limiting
        const limiter = rateLimit({
            windowMs: 15 * 60 * 1000, // 15 minutes
            max: 100 // limit each IP to 100 requests per windowMs
        });

        this.app.use(express.json());
        this.app.use(limiter);
        this.app.use(authenticateUser);
        this.app.use(cacheMiddleware);
    }

    /**
     * Setup API routes
     */
    private setupRoutes() {
        // Public routes
        this.app.get('/api/v1/artwork/:artworkId/visualization',
            validateRequest,
            this.getArtworkVisualization.bind(this)
        );

        this.app.get('/api/v1/artwork/:artworkId/market-chart',
            validateRequest,
            this.getMarketChart.bind(this)
        );

        this.app.get('/api/v1/artwork/:artworkId/quality-chart',
            validateRequest,
            this.getQualityChart.bind(this)
        );

        // Collector routes
        this.app.get('/api/v1/collector/artwork/:artworkId/detailed-visualization',
            validateRequest,
            this.getDetailedVisualization.bind(this)
        );

        this.app.get('/api/v1/collector/artwork/:artworkId/similarity-chart',
            validateRequest,
            this.getSimilarityChart.bind(this)
        );

        // Curator routes
        this.app.get('/api/v1/curator/artwork/:artworkId/expert-visualization',
            validateRequest,
            this.getExpertVisualization.bind(this)
        );

        this.app.get('/api/v1/curator/artwork/:artworkId/manipulation-chart',
            validateRequest,
            this.getManipulationChart.bind(this)
        );

        // History routes
        this.app.get('/api/v1/artwork/:artworkId/visualization-history',
            validateRequest,
            this.getVisualizationHistory.bind(this)
        );

        // Batch routes
        this.app.post('/api/v1/batch/visualizations',
            validateRequest,
            this.getBatchVisualizations.bind(this)
        );
    }

    /**
     * Get basic artwork visualization
     */
    private async getArtworkVisualization(req: express.Request, res: express.Response) {
        try {
            const { artworkId } = req.params;
            const visualization = await this.visualizationService.generateVisualizationPackage(
                artworkId,
                req.query.imageUrl as string,
                req.body.metadata,
                'public'
            );

            res.json({
                success: true,
                data: {
                    marketChart: visualization.visualizations.marketChart,
                    qualityChart: visualization.visualizations.qualityChart,
                    metadata: visualization.metadata
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to generate visualization'
            });
        }
    }

    /**
     * Get market chart
     */
    private async getMarketChart(req: express.Request, res: express.Response) {
        try {
            const { artworkId } = req.params;
            const { timeframe } = req.query;

            const onChainData = await this.contract.getVisualizationData(artworkId);
            const visualization = await this.visualizationService.generateVisualizationPackage(
                artworkId,
                req.query.imageUrl as string,
                req.body.metadata,
                'public'
            );

            res.json({
                success: true,
                data: {
                    chart: visualization.visualizations.marketChart,
                    onChainData: onChainData,
                    timeframe: timeframe || '30d'
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to generate market chart'
            });
        }
    }

    /**
     * Get quality chart
     */
    private async getQualityChart(req: express.Request, res: express.Response) {
        try {
            const { artworkId } = req.params;
            const visualization = await this.visualizationService.generateVisualizationPackage(
                artworkId,
                req.query.imageUrl as string,
                req.body.metadata,
                'public'
            );

            res.json({
                success: true,
                data: {
                    chart: visualization.visualizations.qualityChart,
                    metadata: visualization.metadata
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to generate quality chart'
            });
        }
    }

    /**
     * Get detailed visualization for collectors
     */
    private async getDetailedVisualization(req: express.Request, res: express.Response) {
        try {
            const { artworkId } = req.params;
            const visualization = await this.visualizationService.generateVisualizationPackage(
                artworkId,
                req.query.imageUrl as string,
                req.body.metadata,
                'collector'
            );

            res.json({
                success: true,
                data: {
                    ...visualization.visualizations,
                    metadata: visualization.metadata
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to generate detailed visualization'
            });
        }
    }

    /**
     * Get similarity chart
     */
    private async getSimilarityChart(req: express.Request, res: express.Response) {
        try {
            const { artworkId } = req.params;
            const visualization = await this.visualizationService.generateVisualizationPackage(
                artworkId,
                req.query.imageUrl as string,
                req.body.metadata,
                'collector'
            );

            res.json({
                success: true,
                data: {
                    chart: visualization.visualizations.similarityChart,
                    metadata: visualization.metadata
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to generate similarity chart'
            });
        }
    }

    /**
     * Get expert visualization for curators
     */
    private async getExpertVisualization(req: express.Request, res: express.Response) {
        try {
            const { artworkId } = req.params;
            const visualization = await this.visualizationService.generateVisualizationPackage(
                artworkId,
                req.query.imageUrl as string,
                req.body.metadata,
                'curator'
            );

            res.json({
                success: true,
                data: {
                    ...visualization.visualizations,
                    additionalCharts: visualization.visualizations.additionalCharts,
                    metadata: visualization.metadata
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to generate expert visualization'
            });
        }
    }

    /**
     * Get manipulation chart
     */
    private async getManipulationChart(req: express.Request, res: express.Response) {
        try {
            const { artworkId } = req.params;
            const visualization = await this.visualizationService.generateVisualizationPackage(
                artworkId,
                req.query.imageUrl as string,
                req.body.metadata,
                'curator'
            );

            res.json({
                success: true,
                data: {
                    chart: visualization.visualizations.additionalCharts?.manipulationChart,
                    metadata: visualization.metadata
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to generate manipulation chart'
            });
        }
    }

    /**
     * Get visualization history
     */
    private async getVisualizationHistory(req: express.Request, res: express.Response) {
        try {
            const { artworkId } = req.params;
            const { limit } = req.query;

            const history = await this.contract.getVisualizationHistory(artworkId);
            const limitedHistory = limit ? history.slice(-Number(limit)) : history;

            res.json({
                success: true,
                data: {
                    history: limitedHistory,
                    total: history.length
                }
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to fetch visualization history'
            });
        }
    }

    /**
     * Get batch visualizations
     */
    private async getBatchVisualizations(req: express.Request, res: express.Response) {
        try {
            const { artworkIds, role } = req.body;

            const visualizations = await Promise.all(
                artworkIds.map(async (artworkId: string) => {
                    const visualization = await this.visualizationService.generateVisualizationPackage(
                        artworkId,
                        req.query.imageUrl as string,
                        req.body.metadata,
                        role || 'public'
                    );

                    return {
                        artworkId,
                        visualization
                    };
                })
            );

            res.json({
                success: true,
                data: visualizations
            });
        } catch (error) {
            res.status(500).json({
                success: false,
                error: 'Failed to generate batch visualizations'
            });
        }
    }

    /**
     * Start the API server
     */
    public start(port: number) {
        this.app.listen(port, () => {
            console.log(`Visualization API server running on port ${port}`);
        });
    }
} 