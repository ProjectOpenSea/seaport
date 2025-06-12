export const securityConfig = {
    // Repository protection
    repository: {
        requireNDA: true,
        requireCodeReview: true,
        requireStatusChecks: true,
        requireLinearHistory: true,
        enforceAdmins: true,
        restrictions: {
            users: [],
            teams: []
        }
    },

    // Branch protection
    branchProtection: {
        requiredStatusChecks: {
            strict: true,
            contexts: [
                'security-scan',
                'codeql-analysis',
                'snyk-scan',
                'nda-verification'
            ]
        },
        enforceAdmins: true,
        requiredPullRequestReviews: {
            requiredApprovingReviewCount: 2,
            dismissStaleReviews: true,
            requireCodeOwnerReviews: true
        },
        restrictions: {
            users: [],
            teams: []
        }
    },

    // Security scanning
    securityScanning: {
        codeql: {
            enabled: true,
            languages: ['javascript', 'typescript']
        },
        snyk: {
            enabled: true,
            severityThreshold: 'high'
        },
        secretScanning: {
            enabled: true,
            pushProtection: true
        }
    },

    // Access control
    accessControl: {
        requireNDA: true,
        require2FA: true,
        requireSSHKey: true,
        requireGPGKey: true
    },

    // Monitoring
    monitoring: {
        enabled: true,
        alertChannels: ['email', 'slack'],
        alertThresholds: {
            failedLogins: 5,
            suspiciousCommits: 1,
            sensitiveFileChanges: 1
        }
    }
}; 