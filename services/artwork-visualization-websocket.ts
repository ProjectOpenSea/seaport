import { Server } from 'ws';
import { ethers } from 'ethers';
import { ArtworkVisualizationStorage } from '../typechain-types';
import { config } from 'dotenv';

config();

export class ArtworkVisualizationWebSocket {
    private wss: Server;
    private provider: ethers.providers.Provider;
    private contract: ArtworkVisualizationStorage;
    private clients: Map<string, Set<WebSocket>>;

    constructor(
        port: number,
        contractAddress: string,
        provider: ethers.providers.Provider
    ) {
        this.wss = new Server({ port });
        this.provider = provider;
        this.contract = new ethers.Contract(
            contractAddress,
            ArtworkVisualizationStorage.abi,
            provider
        ) as unknown as ArtworkVisualizationStorage;
        this.clients = new Map();

        this.setupWebSocket();
        this.setupEventListeners();
    }

    /**
     * Setup WebSocket server
     */
    private setupWebSocket() {
        this.wss.on('connection', (ws: WebSocket, req: any) => {
            const artworkId = req.url.split('?artworkId=')[1];

            if (!artworkId) {
                ws.close(1008, 'Artwork ID required');
                return;
            }

            // Add client to artwork's subscriber list
            if (!this.clients.has(artworkId)) {
                this.clients.set(artworkId, new Set());
            }
            this.clients.get(artworkId)?.add(ws);

            // Send initial data
            this.sendInitialData(ws, artworkId);

            // Handle client messages
            ws.on('message', (message: string) => {
                this.handleClientMessage(ws, message, artworkId);
            });

            // Handle client disconnect
            ws.on('close', () => {
                this.clients.get(artworkId)?.delete(ws);
            });
        });
    }

    /**
     * Setup contract event listeners
     */
    private setupEventListeners() {
        // Listen for visualization data updates
        this.contract.on('VisualizationDataUpdated',
            (artworkId: string, timestamp: number, offChainDataHash: string) => {
                this.broadcastUpdate(artworkId, {
                    type: 'visualization_update',
                    data: {
                        timestamp,
                        offChainDataHash
                    }
                });
            }
        );

        // Listen for curator approvals
        this.contract.on('CuratorApprovalAdded',
            (artworkId: string, curator: string) => {
                this.broadcastUpdate(artworkId, {
                    type: 'curator_approval',
                    data: {
                        curator,
                        timestamp: Date.now()
                    }
                });
            }
        );

        // Listen for price updates
        this.provider.on('block', async () => {
            // Implement price update logic
        });
    }

    /**
     * Send initial data to new client
     */
    private async sendInitialData(ws: WebSocket, artworkId: string) {
        try {
            const [visualizationData, history] = await Promise.all([
                this.contract.getVisualizationData(artworkId),
                this.contract.getVisualizationHistory(artworkId)
            ]);

            ws.send(JSON.stringify({
                type: 'initial_data',
                data: {
                    visualizationData,
                    history: history.slice(-10) // Last 10 updates
                }
            }));
        } catch (error) {
            console.error('Failed to send initial data:', error);
            ws.send(JSON.stringify({
                type: 'error',
                data: {
                    message: 'Failed to load initial data'
                }
            }));
        }
    }

    /**
     * Handle client messages
     */
    private handleClientMessage(ws: WebSocket, message: string, artworkId: string) {
        try {
            const data = JSON.parse(message);

            switch (data.type) {
                case 'subscribe':
                    this.handleSubscribe(ws, data, artworkId);
                    break;
                case 'unsubscribe':
                    this.handleUnsubscribe(ws, data, artworkId);
                    break;
                case 'request_update':
                    this.handleUpdateRequest(ws, artworkId);
                    break;
                default:
                    ws.send(JSON.stringify({
                        type: 'error',
                        data: {
                            message: 'Unknown message type'
                        }
                    }));
            }
        } catch (error) {
            console.error('Failed to handle client message:', error);
            ws.send(JSON.stringify({
                type: 'error',
                data: {
                    message: 'Invalid message format'
                }
            }));
        }
    }

    /**
     * Handle subscription request
     */
    private handleSubscribe(ws: WebSocket, data: any, artworkId: string) {
        const { channels } = data;

        if (!channels || !Array.isArray(channels)) {
            ws.send(JSON.stringify({
                type: 'error',
                data: {
                    message: 'Invalid channels'
                }
            }));
            return;
        }

        // Store subscription preferences
        ws.subscriptions = channels;

        ws.send(JSON.stringify({
            type: 'subscription_confirmed',
            data: {
                channels
            }
        }));
    }

    /**
     * Handle unsubscription request
     */
    private handleUnsubscribe(ws: WebSocket, data: any, artworkId: string) {
        const { channels } = data;

        if (!channels || !Array.isArray(channels)) {
            ws.send(JSON.stringify({
                type: 'error',
                data: {
                    message: 'Invalid channels'
                }
            }));
            return;
        }

        // Remove subscription preferences
        ws.subscriptions = ws.subscriptions.filter(
            (channel: string) => !channels.includes(channel)
        );

        ws.send(JSON.stringify({
            type: 'unsubscription_confirmed',
            data: {
                channels
            }
        }));
    }

    /**
     * Handle update request
     */
    private async handleUpdateRequest(ws: WebSocket, artworkId: string) {
        try {
            const visualizationData = await this.contract.getVisualizationData(artworkId);

            ws.send(JSON.stringify({
                type: 'update',
                data: {
                    visualizationData,
                    timestamp: Date.now()
                }
            }));
        } catch (error) {
            console.error('Failed to handle update request:', error);
            ws.send(JSON.stringify({
                type: 'error',
                data: {
                    message: 'Failed to fetch update'
                }
            }));
        }
    }

    /**
     * Broadcast update to all subscribed clients
     */
    private broadcastUpdate(artworkId: string, update: any) {
        const clients = this.clients.get(artworkId);

        if (!clients) {
            return;
        }

        clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                // Check if client is subscribed to this update type
                if (!client.subscriptions || client.subscriptions.includes(update.type)) {
                    client.send(JSON.stringify(update));
                }
            }
        });
    }
}

// Extend WebSocket type to include subscriptions
declare global {
    interface WebSocket {
        subscriptions?: string[];
    }
} 