# Artwork Visualization API Documentation

## Overview
The Artwork Visualization API provides access to real-time and historical visualization data for NFT artworks. The API supports different access levels (public, collector, curator) and includes WebSocket support for real-time updates.

## Authentication
All API requests require authentication using a JWT token in the Authorization header:
```
Authorization: Bearer <your-token>
```

## Rate Limits
- 100 requests per 15 minutes per IP
- WebSocket connections: 10 per IP
- Batch requests: 20 artworks per request

## Endpoints

### Public Endpoints

#### Get Basic Visualization
```http
GET /api/v1/artwork/:artworkId/visualization
```
Returns basic visualization data including market and quality charts.

**Response:**
```json
{
    "success": true,
    "data": {
        "marketChart": {
            "type": "market",
            "data": "base64-encoded-chart-data",
            "metadata": {
                "timeframe": "30d",
                "metrics": ["price", "volume"]
            }
        },
        "qualityChart": {
            "type": "quality",
            "data": "base64-encoded-chart-data",
            "metadata": {
                "metrics": ["composition", "execution", "originality", "technical"]
            }
        },
        "metadata": {
            "version": "1.0",
            "timestamp": 1234567890,
            "role": "public",
            "dataSources": ["market", "quality"],
            "updateFrequency": "daily",
            "lastUpdate": 1234567890
        }
    }
}
```

#### Get Market Chart
```http
GET /api/v1/artwork/:artworkId/market-chart
```
Returns market performance chart with on-chain data.

**Query Parameters:**
- `timeframe`: Chart timeframe (default: "30d")

**Response:**
```json
{
    "success": true,
    "data": {
        "chart": {
            "type": "market",
            "data": "base64-encoded-chart-data",
            "metadata": {
                "timeframe": "30d",
                "metrics": ["price", "volume"]
            }
        },
        "onChainData": {
            "currentPrice": "1.5",
            "tradingVolume": "1000",
            "holderCount": "50"
        }
    }
}
```

### Collector Endpoints

#### Get Detailed Visualization
```http
GET /api/v1/collector/artwork/:artworkId/detailed-visualization
```
Returns detailed visualization data including similarity analysis.

**Response:**
```json
{
    "success": true,
    "data": {
        "marketChart": {...},
        "qualityChart": {...},
        "similarityChart": {...},
        "trendChart": {...},
        "metadata": {...}
    }
}
```

### Curator Endpoints

#### Get Expert Visualization
```http
GET /api/v1/curator/artwork/:artworkId/expert-visualization
```
Returns expert-level visualization data including manipulation analysis.

**Response:**
```json
{
    "success": true,
    "data": {
        "marketChart": {...},
        "qualityChart": {...},
        "similarityChart": {...},
        "trendChart": {...},
        "additionalCharts": {
            "manipulationChart": {...},
            "detailedAnalysisChart": {...},
            "marketDepthChart": {...}
        },
        "metadata": {...}
    }
}
```

## WebSocket API

### Connection
```javascript
const ws = new WebSocket('ws://api.example.com/ws?artworkId=<artworkId>');
```

### Events

#### Initial Data
```json
{
    "type": "initial_data",
    "data": {
        "visualizationData": {...},
        "history": [...]
    }
}
```

#### Visualization Update
```json
{
    "type": "visualization_update",
    "data": {
        "timestamp": 1234567890,
        "offChainDataHash": "0x..."
    }
}
```

#### Curator Approval
```json
{
    "type": "curator_approval",
    "data": {
        "curator": "0x...",
        "timestamp": 1234567890
    }
}
```

### Client Messages

#### Subscribe
```json
{
    "type": "subscribe",
    "channels": ["visualization_update", "curator_approval"]
}
```

#### Unsubscribe
```json
{
    "type": "unsubscribe",
    "channels": ["visualization_update"]
}
```

#### Request Update
```json
{
    "type": "request_update"
}
```

## Error Handling

### Error Response Format
```json
{
    "success": false,
    "error": "Error message"
}
```

### Common Error Codes
- 400: Bad Request
- 401: Unauthorized
- 403: Forbidden
- 404: Not Found
- 429: Too Many Requests
- 500: Internal Server Error

## Best Practices

1. **Caching**
   - Cache responses when appropriate
   - Use ETags for conditional requests
   - Implement client-side caching

2. **Rate Limiting**
   - Implement exponential backoff
   - Monitor rate limit headers
   - Use batch endpoints for multiple requests

3. **WebSocket Usage**
   - Reconnect on connection loss
   - Subscribe only to needed channels
   - Handle message queuing

4. **Error Handling**
   - Implement proper error handling
   - Use appropriate HTTP status codes
   - Include detailed error messages

## Examples

### JavaScript
```javascript
// Fetch basic visualization
async function getVisualization(artworkId) {
    const response = await fetch(
        `/api/v1/artwork/${artworkId}/visualization`,
        {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        }
    );
    return response.json();
}

// WebSocket connection
const ws = new WebSocket(`ws://api.example.com/ws?artworkId=${artworkId}`);

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    // Handle different message types
    switch (data.type) {
        case 'visualization_update':
            updateVisualization(data.data);
            break;
        case 'curator_approval':
            handleCuratorApproval(data.data);
            break;
    }
};
```

### Python
```python
import requests
import websocket
import json

# Fetch basic visualization
def get_visualization(artwork_id, token):
    response = requests.get(
        f'/api/v1/artwork/{artwork_id}/visualization',
        headers={'Authorization': f'Bearer {token}'}
    )
    return response.json()

# WebSocket connection
def on_message(ws, message):
    data = json.loads(message)
    # Handle different message types
    if data['type'] == 'visualization_update':
        update_visualization(data['data'])
    elif data['type'] == 'curator_approval':
        handle_curator_approval(data['data'])

ws = websocket.WebSocketApp(
    f'ws://api.example.com/ws?artworkId={artwork_id}',
    on_message=on_message
)
ws.run_forever()
``` 