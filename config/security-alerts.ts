export const SecurityAlertConfig = {
    // Monitoring intervals
    intervals: {
        deploymentCheck: 5 * 60 * 1000,    // 5 minutes
        apiMonitoring: 1 * 60 * 1000,      // 1 minute
        licenseCheck: 15 * 60 * 1000,      // 15 minutes
        contractMonitoring: 2 * 60 * 1000,  // 2 minutes
        suspiciousActivity: 1 * 60 * 1000   // 1 minute
    },

    // Alert thresholds
    thresholds: {
        unauthorizedAccess: {
            count: 1,
            timeWindow: 24 * 60 * 60 * 1000  // 24 hours
        },
        suspiciousActivity: {
            count: 5,
            timeWindow: 1 * 60 * 60 * 1000   // 1 hour
        },
        licenseViolation: {
            count: 1,
            timeWindow: 24 * 60 * 60 * 1000  // 24 hours
        },
        apiAbuse: {
            count: 100,
            timeWindow: 1 * 60 * 60 * 1000   // 1 hour
        }
    },

    // Alert channels
    channels: {
        discord: {
            webhookUrl: process.env.DISCORD_WEBHOOK_URL,
            enabled: true,
            severity: ['high', 'critical']
        },
        slack: {
            webhookUrl: process.env.SLACK_WEBHOOK_URL,
            enabled: true,
            severity: ['medium', 'high', 'critical']
        },
        email: {
            smtpConfig: {
                host: process.env.SMTP_HOST,
                port: parseInt(process.env.SMTP_PORT || '587'),
                secure: true,
                auth: {
                    user: process.env.SMTP_USER,
                    pass: process.env.SMTP_PASS
                }
            },
            recipients: process.env.ALERT_EMAIL_RECIPIENTS?.split(',') || [],
            enabled: true,
            severity: ['critical']
        }
    },

    // Monitoring targets
    targets: {
        contracts: {
            networks: ['mainnet', 'polygon', 'arbitrum'],
            addresses: process.env.MONITORED_CONTRACT_ADDRESSES?.split(',') || []
        },
        apis: {
            endpoints: [
                '/api/v1/artwork',
                '/api/v1/market',
                '/api/v1/curator'
            ],
            rateLimits: {
                default: 100,
                perEndpoint: {
                    '/api/v1/artwork': 50,
                    '/api/v1/market': 200,
                    '/api/v1/curator': 30
                }
            }
        },
        licenses: {
            validationEndpoints: [
                'https://api.your-domain.com/validate-license',
                'https://api.your-domain.com/verify-usage'
            ],
            checkFrequency: 15 * 60 * 1000  // 15 minutes
        }
    },

    // Alert templates
    templates: {
        unauthorizedDeployment: {
            title: '🚨 Unauthorized Deployment Detected',
            message: 'An unauthorized deployment of our contract code has been detected on {network}.',
            severity: 'critical'
        },
        licenseViolation: {
            title: '⚠️ License Violation Detected',
            message: 'Unauthorized usage of licensed features detected from {source}.',
            severity: 'high'
        },
        suspiciousActivity: {
            title: '🔍 Suspicious Activity Detected',
            message: 'Unusual patterns detected in {type} from {source}.',
            severity: 'medium'
        },
        apiAbuse: {
            title: '⚡ API Abuse Detected',
            message: 'Potential API abuse detected from {source} with {count} requests in {timeWindow}.',
            severity: 'high'
        }
    },

    // Response actions
    actions: {
        unauthorizedDeployment: {
            immediate: [
                'notifyLegal',
                'blockAddress',
                'freezeContract'
            ],
            followUp: [
                'investigateSource',
                'prepareLegalAction',
                'updateBlacklist'
            ]
        },
        licenseViolation: {
            immediate: [
                'notifyLegal',
                'revokeAccess',
                'logViolation'
            ],
            followUp: [
                'investigateUsage',
                'prepareCeaseAndDesist',
                'updateLicenseTerms'
            ]
        },
        suspiciousActivity: {
            immediate: [
                'increaseMonitoring',
                'logActivity',
                'notifySecurity'
            ],
            followUp: [
                'analyzePatterns',
                'updateDetectionRules',
                'enhanceProtection'
            ]
        }
    }
}; 