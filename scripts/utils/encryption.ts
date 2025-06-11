import * as crypto from 'crypto';

// Encryption configuration
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY || crypto.randomBytes(32); // 32 bytes for AES-256
const IV_LENGTH = 16; // For AES, this is always 16
const ALGORITHM = 'aes-256-cbc';

export function encrypt(text: string): string {
    // Generate a random initialization vector
    const iv = crypto.randomBytes(IV_LENGTH);
    
    // Create cipher
    const cipher = crypto.createCipheriv(ALGORITHM, Buffer.from(ENCRYPTION_KEY), iv);
    
    // Encrypt the text
    let encrypted = cipher.update(text);
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    
    // Return iv and encrypted data as hex string
    return iv.toString('hex') + ':' + encrypted.toString('hex');
}

export function decrypt(text: string): string {
    try {
        // Split iv and encrypted text
        const textParts = text.split(':');
        const iv = Buffer.from(textParts.shift()!, 'hex');
        const encryptedText = Buffer.from(textParts.join(':'), 'hex');
        
        // Create decipher
        const decipher = crypto.createDecipheriv(ALGORITHM, Buffer.from(ENCRYPTION_KEY), iv);
        
        // Decrypt the text
        let decrypted = decipher.update(encryptedText);
        decrypted = Buffer.concat([decrypted, decipher.final()]);
        
        return decrypted.toString();
    } catch (error) {
        throw new Error('Decryption failed: Invalid encrypted text or key');
    }
}

// Utility function to generate a new encryption key
export function generateEncryptionKey(): string {
    return crypto.randomBytes(32).toString('hex');
} 