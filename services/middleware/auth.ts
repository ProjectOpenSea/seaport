import { Request, Response, NextFunction } from 'express';
import { ethers } from 'ethers';
import { ArtworkVisualizationStorage } from '../../typechain-types';

export async function authenticateUser(
    req: Request,
    res: Response,
    next: NextFunction
) {
    try {
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({
                success: false,
                error: 'No authentication token provided'
            });
        }

        // Verify the token and get user role
        const userRole = await verifyToken(token);

        if (!userRole) {
            return res.status(401).json({
                success: false,
                error: 'Invalid authentication token'
            });
        }

        // Add user role to request
        req.user = {
            role: userRole
        };

        next();
    } catch (error) {
        res.status(500).json({
            success: false,
            error: 'Authentication failed'
        });
    }
}

/**
 * Verify authentication token and determine user role
 */
async function verifyToken(token: string): Promise<'public' | 'collector' | 'curator' | null> {
    try {
        // Verify the token (implementation depends on your auth system)
        const decodedToken = await verifyJWTToken(token);

        if (!decodedToken) {
            return null;
        }

        // Check if user is a curator
        const isCurator = await checkCuratorStatus(decodedToken.address);

        if (isCurator) {
            return 'curator';
        }

        // Check if user is a collector
        const isCollector = await checkCollectorStatus(decodedToken.address);

        if (isCollector) {
            return 'collector';
        }

        return 'public';
    } catch (error) {
        console.error('Token verification failed:', error);
        return null;
    }
}

/**
 * Verify JWT token
 */
async function verifyJWTToken(token: string): Promise<any> {
    // Implement JWT verification
    // This is a placeholder implementation
    return {
        address: '0x...',
        role: 'user'
    };
}

/**
 * Check if address is a curator
 */
async function checkCuratorStatus(address: string): Promise<boolean> {
    try {
        const contract = new ethers.Contract(
            process.env.VISUALIZATION_STORAGE_ADDRESS!,
            ArtworkVisualizationStorage.abi,
            new ethers.providers.JsonRpcProvider(process.env.RPC_URL)
        ) as unknown as ArtworkVisualizationStorage;

        return await contract.isCurator(address);
    } catch (error) {
        console.error('Curator status check failed:', error);
        return false;
    }
}

/**
 * Check if address is a collector
 */
async function checkCollectorStatus(address: string): Promise<boolean> {
    // Implement collector status check
    // This could check if the address owns any NFTs
    return true;
}

// Extend Express Request type to include user
declare global {
    namespace Express {
        interface Request {
            user?: {
                role: 'public' | 'collector' | 'curator';
            };
        }
    }
} 