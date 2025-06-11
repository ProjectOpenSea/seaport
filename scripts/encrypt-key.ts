import * as dotenv from 'dotenv';
import { encrypt, generateEncryptionKey } from './utils/encryption';
import * as fs from 'fs';
import * as path from 'path';

// Load environment variables
dotenv.config();

async function main() {
    // Generate a new encryption key if not exists
    if (!process.env.ENCRYPTION_KEY) {
        const newKey = generateEncryptionKey();
        console.log('Generated new encryption key. Add this to your .env file:');
        console.log(`ENCRYPTION_KEY=${newKey}`);
        
        // Update .env file
        const envPath = path.resolve(process.cwd(), '.env');
        fs.appendFileSync(envPath, `\nENCRYPTION_KEY=${newKey}\n`);
    }

    // Get private key from environment
    const privateKey = process.env.WALLET_PRIVATE_KEY;
    if (!privateKey) {
        throw new Error('WALLET_PRIVATE_KEY not found in .env file');
    }

    // Encrypt the private key
    const encryptedKey = encrypt(privateKey);
    
    // Update .env file with encrypted key
    const envPath = path.resolve(process.cwd(), '.env');
    let envContent = fs.readFileSync(envPath, 'utf8');
    
    // Replace or add the encrypted key
    if (envContent.includes('ENCRYPTED_PRIVATE_KEY=')) {
        envContent = envContent.replace(
            /ENCRYPTED_PRIVATE_KEY=.*/,
            `ENCRYPTED_PRIVATE_KEY=${encryptedKey}`
        );
    } else {
        envContent += `\nENCRYPTED_PRIVATE_KEY=${encryptedKey}\n`;
    }
    
    // Write back to .env file
    fs.writeFileSync(envPath, envContent);
    
    console.log('Private key has been encrypted and stored in .env file');
    console.log('You can now remove the WALLET_PRIVATE_KEY from .env file');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

const privateKey = 'your_actual_private_key'; // Replace with your actual private key
const encryptedKey = encrypt(privateKey);
console.log(encryptedKey); 