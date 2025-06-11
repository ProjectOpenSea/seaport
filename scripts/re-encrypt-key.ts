import { encrypt } from './utils/encryption';

const privateKey = 'your_actual_private_key'; // Replace with your actual private key
const encryptedKey = encrypt(privateKey);
console.log(encryptedKey);

const seaport = await OptimizedSeaport.deploy(conduitController);

// Create orders
const orders = [order1, order2, order3];

// Fulfill multiple orders in one transaction
const fulfilled = await seaport.fulfillOrders(orders, conduitKey);

// Check order status
const isCancelled = await seaport.isOrderCancelled(orderHash);
const orderCount = await seaport.getOrderCount(userAddress);

// Cancel multiple orders
await seaport.cancelOrders([orderHash1, orderHash2]);