import { ethers } from 'ethers';
import { AISimilarityDetection } from '../typechain-types';
import { Configuration, OpenAIApi } from 'openai';
import { GoogleGenerativeAI } from '@google/generative-ai';
import { Replicate } from 'replicate';
import { config } from 'dotenv';
import { HfInference } from '@huggingface/inference';

config(); // Load environment variables

export class AISimilarityService {
    private openai: OpenAIApi;
    private genAI: GoogleGenerativeAI;
    private replicate: Replicate;
    private hf: HfInference;
    private contract: AISimilarityDetection;
    private provider: ethers.providers.Provider;

    constructor(
        contractAddress: string,
        provider: ethers.providers.Provider,
        signer: ethers.Signer
    ) {
        // Initialize AI providers
        this.openai = new OpenAIApi(
            new Configuration({
                apiKey: process.env.OPENAI_API_KEY,
            })
        );

        this.genAI = new GoogleGenerativeAI(process.env.GOOGLE_AI_API_KEY!);
        this.replicate = new Replicate({
            auth: process.env.REPLICATE_API_KEY!,
        });
        this.hf = new HfInference(process.env.HUGGINGFACE_API_KEY!);

        // Initialize contract
        this.contract = new ethers.Contract(
            contractAddress,
            AISimilarityDetection.abi,
            signer
        ) as unknown as AISimilarityDetection;

        this.provider = provider;
    }

    /**
     * Enhanced feature extraction using multiple AI models
     */
    async extractFeatures(imageUrl: string): Promise<string[]> {
        const features: string[] = [];
        const processingPromises: Promise<string[]>[] = [];

        // 1. CLIP for visual features (OpenAI)
        processingPromises.push(this.extractCLIPFeatures(imageUrl));

        // 2. Gemini Pro Vision for object detection
        processingPromises.push(this.extractVisionFeatures(imageUrl));

        // 3. Stable Diffusion for style analysis
        processingPromises.push(this.extractStyleFeatures(imageUrl));

        // 4. DALL-E for artistic style analysis
        processingPromises.push(this.extractDALLEFeatures(imageUrl));

        // 5. HuggingFace's ViT for additional visual features
        processingPromises.push(this.extractViTFeatures(imageUrl));

        // Process all features in parallel
        const results = await Promise.allSettled(processingPromises);

        // Combine results
        results.forEach(result => {
            if (result.status === 'fulfilled') {
                features.push(...result.value);
            }
        });

        return this.deduplicateFeatures(features);
    }

    /**
     * Extract features using OpenAI's CLIP model
     */
    private async extractCLIPFeatures(imageUrl: string): Promise<string[]> {
        try {
            const response = await this.openai.createImageAnalysis({
                image: imageUrl,
                model: "clip-vit-base-patch32",
            });

            return response.data.features.map(f => f.toString());
        } catch (error) {
            console.error('CLIP feature extraction failed:', error);
            return [];
        }
    }

    /**
     * Extract features using Google Vision AI
     */
    private async extractVisionFeatures(imageUrl: string): Promise<string[]> {
        try {
            const model = this.genAI.getGenerativeModel({ model: "gemini-pro-vision" });
            const result = await model.generateContent([
                "Analyze this image and extract key visual features",
                { inlineData: { data: imageUrl, mimeType: "image/jpeg" } }
            ]);

            return result.response.text().split(',');
        } catch (error) {
            console.error('Vision AI feature extraction failed:', error);
            return [];
        }
    }

    /**
     * Extract style features using Stable Diffusion
     */
    private async extractStyleFeatures(imageUrl: string): Promise<string[]> {
        try {
            const output = await this.replicate.run(
                "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
                {
                    input: {
                        image: imageUrl,
                        prompt: "Analyze the artistic style of this image"
                    }
                }
            );

            return output.toString().split(',');
        } catch (error) {
            console.error('Style feature extraction failed:', error);
            return [];
        }
    }

    /**
     * Extract features using DALL-E
     */
    private async extractDALLEFeatures(imageUrl: string): Promise<string[]> {
        try {
            const response = await this.openai.createImageVariation({
                image: imageUrl,
                n: 1,
                size: "256x256",
            });

            // Use GPT-4 to analyze the variations
            const analysis = await this.openai.createChatCompletion({
                model: "gpt-4-vision-preview",
                messages: [
                    {
                        role: "user",
                        content: [
                            { type: "text", text: "Analyze the artistic style and key features of this image" },
                            { type: "image_url", image_url: imageUrl }
                        ]
                    }
                ]
            });

            return analysis.data.choices[0].message?.content?.split(',') || [];
        } catch (error) {
            console.error('DALL-E feature extraction failed:', error);
            return [];
        }
    }

    /**
     * Extract features using HuggingFace's ViT
     */
    private async extractViTFeatures(imageUrl: string): Promise<string[]> {
        try {
            const response = await this.hf.featureExtraction({
                model: 'google/vit-base-patch16-224',
                inputs: imageUrl,
            });

            return response.map(f => f.toString());
        } catch (error) {
            console.error('ViT feature extraction failed:', error);
            return [];
        }
    }

    /**
     * Deduplicate and normalize features
     */
    private deduplicateFeatures(features: string[]): string[] {
        const uniqueFeatures = new Set<string>();
        features.forEach(feature => {
            // Normalize feature string
            const normalized = feature.toLowerCase().trim();
            if (normalized) {
                uniqueFeatures.add(normalized);
            }
        });
        return Array.from(uniqueFeatures);
    }

    /**
     * Enhanced similarity calculation using multiple metrics
     */
    async calculateSimilarity(
        features1: string[],
        features2: string[]
    ): Promise<number> {
        const scores: number[] = [];

        // 1. Semantic similarity using OpenAI embeddings
        const semanticScore = await this.calculateSemanticSimilarity(features1, features2);
        scores.push(semanticScore);

        // 2. Visual similarity using CLIP
        const visualScore = await this.calculateVisualSimilarity(features1, features2);
        scores.push(visualScore);

        // 3. Style similarity using Stable Diffusion
        const styleScore = await this.calculateStyleSimilarity(features1, features2);
        scores.push(styleScore);

        // Weighted average of all scores
        const weights = [0.4, 0.4, 0.2]; // Adjust weights based on importance
        const finalScore = scores.reduce((sum, score, i) => sum + score * weights[i], 0);

        return Math.round(finalScore * 100); // Convert to 0-100 scale
    }

    /**
     * Calculate semantic similarity using OpenAI embeddings
     */
    private async calculateSemanticSimilarity(
        features1: string[],
        features2: string[]
    ): Promise<number> {
        const embedding1 = await this.getEmbedding(features1.join(' '));
        const embedding2 = await this.getEmbedding(features2.join(' '));
        return this.cosineSimilarity(embedding1, embedding2);
    }

    /**
     * Calculate visual similarity using CLIP
     */
    private async calculateVisualSimilarity(
        features1: string[],
        features2: string[]
    ): Promise<number> {
        try {
            // Get CLIP embeddings for both feature sets
            const clipEmbedding1 = await this.openai.createEmbedding({
                model: "clip-vit-base-patch32",
                input: features1.join(' '),
            });

            const clipEmbedding2 = await this.openai.createEmbedding({
                model: "clip-vit-base-patch32",
                input: features2.join(' '),
            });

            // Calculate cosine similarity between CLIP embeddings
            const similarity = this.cosineSimilarity(
                clipEmbedding1.data.data[0].embedding,
                clipEmbedding2.data.data[0].embedding
            );

            // CLIP is particularly good at visual similarity, so we weight it appropriately
            return similarity;
        } catch (error) {
            console.error('CLIP similarity calculation failed:', error);
            return 0; // Return 0 similarity on error
        }
    }

    /**
     * Calculate style similarity using Stable Diffusion
     */
    private async calculateStyleSimilarity(
        features1: string[],
        features2: string[]
    ): Promise<number> {
        try {
            // Use Stable Diffusion to analyze artistic style
            const styleAnalysis1 = await this.replicate.run(
                "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
                {
                    input: {
                        prompt: `Analyze the artistic style of this image: ${features1.join(' ')}`,
                        negative_prompt: "photorealistic, photograph",
                        num_inference_steps: 20
                    }
                }
            );

            const styleAnalysis2 = await this.replicate.run(
                "stability-ai/sdxl:39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
                {
                    input: {
                        prompt: `Analyze the artistic style of this image: ${features2.join(' ')}`,
                        negative_prompt: "photorealistic, photograph",
                        num_inference_steps: 20
                    }
                }
            );

            // Compare style characteristics
            const styleCharacteristics1 = this.extractStyleCharacteristics(styleAnalysis1);
            const styleCharacteristics2 = this.extractStyleCharacteristics(styleAnalysis2);

            // Calculate style similarity based on multiple factors
            const similarityScores = [
                this.compareColorPalettes(styleCharacteristics1, styleCharacteristics2),
                this.compareBrushStrokes(styleCharacteristics1, styleCharacteristics2),
                this.compareComposition(styleCharacteristics1, styleCharacteristics2),
                this.compareArtisticTechniques(styleCharacteristics1, styleCharacteristics2)
            ];

            // Weight and combine the scores
            const weights = [0.3, 0.3, 0.2, 0.2]; // Adjust based on importance
            return similarityScores.reduce((sum, score, i) => sum + score * weights[i], 0);
        } catch (error) {
            console.error('Style similarity calculation failed:', error);
            return 0; // Return 0 similarity on error
        }
    }

    /**
     * Extract style characteristics from Stable Diffusion analysis
     */
    private extractStyleCharacteristics(analysis: any): any {
        // Parse and extract relevant style characteristics
        return {
            colorPalette: this.extractColorPalette(analysis),
            brushStrokes: this.extractBrushStrokes(analysis),
            composition: this.extractComposition(analysis),
            techniques: this.extractArtisticTechniques(analysis)
        };
    }

    /**
     * Compare color palettes between two artworks
     */
    private compareColorPalettes(style1: any, style2: any): number {
        try {
            const palette1 = this.extractColorPalette(style1);
            const palette2 = this.extractColorPalette(style2);

            // Compare dominant colors
            const dominantColorSimilarity = this.compareColorSets(
                palette1.dominantColors,
                palette2.dominantColors
            );

            // Compare color harmony
            const harmonySimilarity = this.compareColorHarmony(
                palette1.harmony,
                palette2.harmony
            );

            // Compare color temperature
            const temperatureSimilarity = this.compareColorTemperature(
                palette1.temperature,
                palette2.temperature
            );

            // Compare color contrast
            const contrastSimilarity = this.compareColorContrast(
                palette1.contrast,
                palette2.contrast
            );

            // Weight and combine the scores
            const weights = [0.3, 0.3, 0.2, 0.2];
            return [
                dominantColorSimilarity,
                harmonySimilarity,
                temperatureSimilarity,
                contrastSimilarity
            ].reduce((sum, score, i) => sum + score * weights[i], 0);
        } catch (error) {
            console.error('Color palette comparison failed:', error);
            return 0;
        }
    }

    /**
     * Compare brush stroke characteristics
     */
    private compareBrushStrokes(style1: any, style2: any): number {
        try {
            const strokes1 = this.extractBrushStrokes(style1);
            const strokes2 = this.extractBrushStrokes(style2);

            // Compare stroke direction patterns
            const directionSimilarity = this.compareStrokeDirections(
                strokes1.directions,
                strokes2.directions
            );

            // Compare stroke thickness distribution
            const thicknessSimilarity = this.compareStrokeThickness(
                strokes1.thickness,
                strokes2.thickness
            );

            // Compare stroke texture
            const textureSimilarity = this.compareStrokeTexture(
                strokes1.texture,
                strokes2.texture
            );

            // Compare stroke patterns
            const patternSimilarity = this.compareStrokePatterns(
                strokes1.patterns,
                strokes2.patterns
            );

            // Weight and combine the scores
            const weights = [0.25, 0.25, 0.25, 0.25];
            return [
                directionSimilarity,
                thicknessSimilarity,
                textureSimilarity,
                patternSimilarity
            ].reduce((sum, score, i) => sum + score * weights[i], 0);
        } catch (error) {
            console.error('Brush stroke comparison failed:', error);
            return 0;
        }
    }

    /**
     * Compare composition elements
     */
    private compareComposition(style1: any, style2: any): number {
        try {
            const comp1 = this.extractComposition(style1);
            const comp2 = this.extractComposition(style2);

            // Compare rule of thirds application
            const ruleOfThirdsSimilarity = this.compareRuleOfThirds(
                comp1.ruleOfThirds,
                comp2.ruleOfThirds
            );

            // Compare focal points
            const focalPointsSimilarity = this.compareFocalPoints(
                comp1.focalPoints,
                comp2.focalPoints
            );

            // Compare balance
            const balanceSimilarity = this.compareBalance(
                comp1.balance,
                comp2.balance
            );

            // Compare negative space
            const negativeSpaceSimilarity = this.compareNegativeSpace(
                comp1.negativeSpace,
                comp2.negativeSpace
            );

            // Weight and combine the scores
            const weights = [0.3, 0.3, 0.2, 0.2];
            return [
                ruleOfThirdsSimilarity,
                focalPointsSimilarity,
                balanceSimilarity,
                negativeSpaceSimilarity
            ].reduce((sum, score, i) => sum + score * weights[i], 0);
        } catch (error) {
            console.error('Composition comparison failed:', error);
            return 0;
        }
    }

    /**
     * Compare artistic techniques
     */
    private compareArtisticTechniques(style1: any, style2: any): number {
        try {
            const tech1 = this.extractArtisticTechniques(style1);
            const tech2 = this.extractArtisticTechniques(style2);

            // Compare painting style
            const styleSimilarity = this.comparePaintingStyle(
                tech1.paintingStyle,
                tech2.paintingStyle
            );

            // Compare medium characteristics
            const mediumSimilarity = this.compareMedium(
                tech1.medium,
                tech2.medium
            );

            // Compare texture
            const textureSimilarity = this.compareTexture(
                tech1.texture,
                tech2.texture
            );

            // Compare special effects
            const effectsSimilarity = this.compareSpecialEffects(
                tech1.specialEffects,
                tech2.specialEffects
            );

            // Weight and combine the scores
            const weights = [0.3, 0.3, 0.2, 0.2];
            return [
                styleSimilarity,
                mediumSimilarity,
                textureSimilarity,
                effectsSimilarity
            ].reduce((sum, score, i) => sum + score * weights[i], 0);
        } catch (error) {
            console.error('Artistic technique comparison failed:', error);
            return 0;
        }
    }

    /**
     * Extract color palette information
     */
    private extractColorPalette(analysis: any): any {
        // Use GPT-4 Vision to analyze color palette
        return {
            dominantColors: this.extractDominantColors(analysis),
            harmony: this.extractColorHarmony(analysis),
            temperature: this.extractColorTemperature(analysis),
            contrast: this.extractColorContrast(analysis)
        };
    }

    /**
     * Extract brush stroke information
     */
    private extractBrushStrokes(analysis: any): any {
        // Use Stable Diffusion to analyze brush strokes
        return {
            directions: this.extractStrokeDirections(analysis),
            thickness: this.extractStrokeThickness(analysis),
            texture: this.extractStrokeTexture(analysis),
            patterns: this.extractStrokePatterns(analysis)
        };
    }

    /**
     * Extract composition information
     */
    private extractComposition(analysis: any): any {
        // Use CLIP and GPT-4 Vision to analyze composition
        return {
            ruleOfThirds: this.extractRuleOfThirds(analysis),
            focalPoints: this.extractFocalPoints(analysis),
            balance: this.extractBalance(analysis),
            negativeSpace: this.extractNegativeSpace(analysis)
        };
    }

    /**
     * Extract artistic technique information
     */
    private extractArtisticTechniques(analysis: any): any {
        // Use multiple models to analyze artistic techniques
        return {
            paintingStyle: this.extractPaintingStyle(analysis),
            medium: this.extractMedium(analysis),
            texture: this.extractTexture(analysis),
            specialEffects: this.extractSpecialEffects(analysis)
        };
    }

    /**
     * Get embeddings from OpenAI
     */
    private async getEmbedding(text: string): Promise<number[]> {
        const response = await this.openai.createEmbedding({
            model: "text-embedding-ada-002",
            input: text,
        });

        return response.data.data[0].embedding;
    }

    /**
     * Calculate cosine similarity between two vectors
     */
    private cosineSimilarity(vec1: number[], vec2: number[]): number {
        const dotProduct = vec1.reduce((sum, val, i) => sum + val * vec2[i], 0);
        const magnitude1 = Math.sqrt(vec1.reduce((sum, val) => sum + val * val, 0));
        const magnitude2 = Math.sqrt(vec2.reduce((sum, val) => sum + val * val, 0));
        return dotProduct / (magnitude1 * magnitude2);
    }

    /**
     * Process similarity check for an artwork
     */
    async processSimilarityCheck(
        contentHash: string,
        imageUrl: string
    ): Promise<void> {
        try {
            // Extract features
            const features = await this.extractFeatures(imageUrl);

            // Request similarity check
            await this.contract.requestSimilarityCheck(contentHash, features);

            // Get all existing artworks
            const existingArtworks = await this.getExistingArtworks();

            // Compare with existing artworks
            const similarArtworks: string[] = [];
            let maxSimilarity = 0;

            for (const artwork of existingArtworks) {
                const similarity = await this.calculateSimilarity(
                    features,
                    artwork.features
                );

                if (similarity > maxSimilarity) {
                    maxSimilarity = similarity;
                }

                if (similarity >= 80) { // Threshold for similar artworks
                    similarArtworks.push(artwork.contentHash);
                }
            }

            // Process results
            await this.contract.processSimilarityCheck(
                contentHash,
                maxSimilarity,
                similarArtworks
            );
        } catch (error) {
            console.error('Similarity check processing failed:', error);
            throw error;
        }
    }

    /**
     * Get all existing artworks from the contract
     */
    private async getExistingArtworks(): Promise<Array<{ contentHash: string; features: string[] }>> {
        // Implementation depends on how we store artwork data
        // This is a placeholder
        return [];
    }
} 