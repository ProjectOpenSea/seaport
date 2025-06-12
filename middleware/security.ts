import { Request, Response, NextFunction } from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import cors from 'cors';
import { ethers } from 'ethers';

// Rate limiting configuration
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // Limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
});

// CORS configuration
const corsOptions = {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['https://yourdomain.com'],
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true
};

// Security middleware class
export class SecurityMiddleware {
    private provider: ethers.Provider;

    constructor() {
        this.provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    }

    // Apply all security middleware
    applyMiddleware(app: any) {
        // Basic security headers
        app.use(helmet());

        // CORS protection
        app.use(cors(corsOptions));

        // Rate limiting
        app.use(limiter);

        // Request validation
        app.use(this.validateRequest.bind(this));

        // Authentication
        app.use(this.authenticateRequest.bind(this));

        // License verification
        app.use(this.verifyLicense.bind(this));

        // API key validation
        app.use(this.validateApiKey.bind(this));
    }

    // Validate request format and content
    private async validateRequest(req: Request, res: Response, next: NextFunction) {
        try {
            // Validate request body
            if (req.body && Object.keys(req.body).length > 0) {
                await this.validateRequestBody(req.body);
            }

            // Validate request headers
            this.validateRequestHeaders(req.headers);

            // Validate request parameters
            if (req.params && Object.keys(req.params).length > 0) {
                await this.validateRequestParams(req.params);
            }

            next();
        } catch (error) {
            res.status(400).json({ error: 'Invalid request format' });
        }
    }

    // Authenticate request
    private async authenticateRequest(req: Request, res: Response, next: NextFunction) {
        try {
            const token = req.headers.authorization?.split(' ')[1];
            if (!token) {
                return res.status(401).json({ error: 'Authentication required' });
            }

            const isValid = await this.verifyToken(token);
            if (!isValid) {
                return res.status(401).json({ error: 'Invalid authentication token' });
            }

            next();
        } catch (error) {
            res.status(401).json({ error: 'Authentication failed' });
        }
    }

    // Verify license
    private async verifyLicense(req: Request, res: Response, next: NextFunction) {
        try {
            const licenseKey = req.headers['x-license-key'];
            if (!licenseKey) {
                return res.status(403).json({ error: 'License key required' });
            }

            const isValid = await this.validateLicenseKey(licenseKey as string);
            if (!isValid) {
                return res.status(403).json({ error: 'Invalid license key' });
            }

            next();
        } catch (error) {
            res.status(403).json({ error: 'License verification failed' });
        }
    }

    // Validate API key
    private async validateApiKey(req: Request, res: Response, next: NextFunction) {
        try {
            const apiKey = req.headers['x-api-key'];
            if (!apiKey) {
                return res.status(403).json({ error: 'API key required' });
            }

            const isValid = await this.verifyApiKey(apiKey as string);
            if (!isValid) {
                return res.status(403).json({ error: 'Invalid API key' });
            }

            next();
        } catch (error) {
            res.status(403).json({ error: 'API key validation failed' });
        }
    }

    // Helper methods
    private async validateRequestBody(body: any) {
        // Implement request body validation
    }

    private validateRequestHeaders(headers: any) {
        // Implement header validation
    }

    private async validateRequestParams(params: any) {
        // Implement parameter validation
    }

    private async verifyToken(token: string): Promise<boolean> {
        // Implement token verification
        return true;
    }

    private async validateLicenseKey(key: string): Promise<boolean> {
        // Implement license key validation
        return true;
    }

    private async verifyApiKey(key: string): Promise<boolean> {
        // Implement API key verification
        return true;
    }
}

// Export middleware instance
export const securityMiddleware = new SecurityMiddleware(); 