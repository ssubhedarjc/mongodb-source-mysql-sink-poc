const { MongoClient } = require('mongodb');

// Configuration
const MONGODB_URI = 'mongodb://mongodb:27017';
const DATABASE_NAME = 'cdc_poc';
const COLLECTION_NAME = 'systemusers';
const MIN_INTERVAL = 10000; // 10 seconds minimum
const MAX_INTERVAL = 30000; // 30 seconds maximum
const MIN_USERS = 5; // Minimum users to maintain

// Sample data
const FIRST_NAMES = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve', 'Frank', 'Grace', 'Henry', 'Ivy', 'Jack', 'Kate', 'Liam', 'Mia', 'Noah', 'Olivia', 'Paul', 'Quinn', 'Ruby', 'Sam', 'Tina'];
const LAST_NAMES = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin'];
const DEPARTMENTS = ['Engineering', 'Marketing', 'Sales', 'HR', 'Finance', 'Operations', 'Support', 'Legal', 'Design', 'Product'];
const ROLES = ['Manager', 'Developer', 'Analyst', 'Representative', 'Coordinator', 'Specialist', 'Lead', 'Director', 'Associate', 'Intern'];
const STATUSES = ['active', 'inactive'];

let client;
let db;
let collection;
let userCounter = 2000;

// Utility functions
function getRandomElement(array) {
    return array[Math.floor(Math.random() * array.length)];
}

function getRandomInterval() {
    return Math.floor(Math.random() * (MAX_INTERVAL - MIN_INTERVAL + 1)) + MIN_INTERVAL;
}

function generateUser() {
    const firstName = getRandomElement(FIRST_NAMES);
    const lastName = getRandomElement(LAST_NAMES);
    const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}@example.com`;
    
    return {
        userId: `user${String(userCounter++).padStart(4, '0')}`,
        username: `${firstName.toLowerCase()}_${lastName.toLowerCase()}`,
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: getRandomElement(ROLES),
        status: getRandomElement(STATUSES),
        department: getRandomElement(DEPARTMENTS),
        createdAt: new Date(),
        lastLoginAt: new Date()
    };
}

// CRUD Operations
async function performInsert() {
    try {
        const user = generateUser();
        const result = await collection.insertOne(user);
        console.log(`✅ [${new Date().toISOString()}] INSERT: Created user ${user.userId}`);
        return result;
    } catch (error) {
        console.error(`❌ [${new Date().toISOString()}] INSERT failed:`, error.message);
    }
}

async function performUpdate() {
    try {
        const users = await collection.find({}, { projection: { userId: 1 } }).limit(20).toArray();
        if (users.length === 0) {
            console.log(`⚠️  [${new Date().toISOString()}] UPDATE: No users found to update`);
            return;
        }

        const userToUpdate = getRandomElement(users);
        const updates = {
            department: getRandomElement(DEPARTMENTS),
            role: getRandomElement(ROLES),
            status: getRandomElement(STATUSES),
            lastLoginAt: new Date()
        };

        const result = await collection.updateOne(
            { userId: userToUpdate.userId },
            { $set: updates }
        );

        if (result.modifiedCount > 0) {
            console.log(`✅ [${new Date().toISOString()}] UPDATE: Updated user ${userToUpdate.userId} (dept: ${updates.department}, role: ${updates.role}, status: ${updates.status})`);
        } else {
            console.log(`⚠️  [${new Date().toISOString()}] UPDATE: No changes made to user ${userToUpdate.userId}`);
        }
    } catch (error) {
        console.error(`❌ [${new Date().toISOString()}] UPDATE failed:`, error.message);
    }
}

async function performSoftDelete() {
    try {
        const users = await collection.find({ status: 'active' }, { projection: { userId: 1 } }).limit(10).toArray();
        if (users.length === 0) {
            console.log(`⚠️  [${new Date().toISOString()}] SOFT DELETE: No active users found to deactivate`);
            return;
        }

        const userToDeactivate = getRandomElement(users);
        const result = await collection.updateOne(
            { userId: userToDeactivate.userId },
            { $set: { status: 'inactive', lastLoginAt: new Date() } }
        );

        if (result.modifiedCount > 0) {
            console.log(`✅ [${new Date().toISOString()}] SOFT DELETE: Deactivated user ${userToDeactivate.userId}`);
        }
    } catch (error) {
        console.error(`❌ [${new Date().toISOString()}] SOFT DELETE failed:`, error.message);
    }
}

async function performHardDelete() {
    try {
        const totalUsers = await collection.countDocuments();
        if (totalUsers <= MIN_USERS) {
            console.log(`⚠️  [${new Date().toISOString()}] HARD DELETE: Maintaining minimum ${MIN_USERS} users, skipping delete`);
            return;
        }

        const users = await collection.find({}, { projection: { userId: 1 } }).limit(10).toArray();
        if (users.length === 0) {
            console.log(`⚠️  [${new Date().toISOString()}] HARD DELETE: No users found to delete`);
            return;
        }

        const userToDelete = getRandomElement(users);
        const result = await collection.deleteOne({ userId: userToDelete.userId });

        if (result.deletedCount > 0) {
            console.log(`✅ [${new Date().toISOString()}] HARD DELETE: Deleted user ${userToDelete.userId}`);
        }
    } catch (error) {
        console.error(`❌ [${new Date().toISOString()}] HARD DELETE failed:`, error.message);
    }
}

async function showStats() {
    try {
        const totalUsers = await collection.countDocuments();
        const activeUsers = await collection.countDocuments({ status: 'active' });
        const inactiveUsers = await collection.countDocuments({ status: 'inactive' });
        
        console.log(`📊 [${new Date().toISOString()}] STATS: Total: ${totalUsers}, Active: ${activeUsers}, Inactive: ${inactiveUsers}`);
    } catch (error) {
        console.error(`❌ [${new Date().toISOString()}] STATS failed:`, error.message);
    }
}

// Operation selector with weights
async function performRandomOperation() {
    const rand = Math.random() * 100;
    
    if (rand < 50) {
        // 50% chance - INSERT
        await performInsert();
    } else if (rand < 75) {
        // 25% chance - UPDATE
        await performUpdate();
    } else if (rand < 90) {
        // 15% chance - SOFT DELETE
        await performSoftDelete();
    } else {
        // 10% chance - HARD DELETE
        await performHardDelete();
    }
}

// Main loop
async function runContinuousOperations() {
    let operationCount = 0;
    
    console.log(`🚀 [${new Date().toISOString()}] Starting continuous CRUD operations...`);
    console.log(`📋 Configuration: ${MIN_INTERVAL/1000}s - ${MAX_INTERVAL/1000}s intervals, min ${MIN_USERS} users`);
    
    while (true) {
        try {
            await performRandomOperation();
            operationCount++;
            
            // Show stats every 10 operations
            if (operationCount % 10 === 0) {
                await showStats();
            }
            
            // Wait for random interval
            const waitTime = getRandomInterval();
            console.log(`⏳ [${new Date().toISOString()}] Waiting ${waitTime/1000}s for next operation...`);
            await new Promise(resolve => setTimeout(resolve, waitTime));
            
        } catch (error) {
            console.error(`❌ [${new Date().toISOString()}] Operation failed:`, error.message);
            // Wait a bit longer on error
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }
}

// Connection and startup
async function connect() {
    try {
        console.log(`🔌 [${new Date().toISOString()}] Connecting to MongoDB at ${MONGODB_URI}...`);
        client = new MongoClient(MONGODB_URI);
        await client.connect();
        
        db = client.db(DATABASE_NAME);
        collection = db.collection(COLLECTION_NAME);
        
        console.log(`✅ [${new Date().toISOString()}] Connected to MongoDB successfully`);
        
        // Test connection
        await collection.findOne();
        console.log(`✅ [${new Date().toISOString()}] Collection access verified`);
        
        return true;
    } catch (error) {
        console.error(`❌ [${new Date().toISOString()}] MongoDB connection failed:`, error.message);
        return false;
    }
}

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log(`\n🛑 [${new Date().toISOString()}] Received SIGINT, shutting down gracefully...`);
    if (client) {
        await client.close();
        console.log(`✅ [${new Date().toISOString()}] MongoDB connection closed`);
    }
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log(`\n🛑 [${new Date().toISOString()}] Received SIGTERM, shutting down gracefully...`);
    if (client) {
        await client.close();
        console.log(`✅ [${new Date().toISOString()}] MongoDB connection closed`);
    }
    process.exit(0);
});

// Main execution
async function main() {
    // Wait for MongoDB to be ready
    let connected = false;
    let attempts = 0;
    const maxAttempts = 30;
    
    while (!connected && attempts < maxAttempts) {
        connected = await connect();
        if (!connected) {
            attempts++;
            console.log(`⏳ [${new Date().toISOString()}] Retrying connection in 5 seconds... (${attempts}/${maxAttempts})`);
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }
    
    if (!connected) {
        console.error(`❌ [${new Date().toISOString()}] Failed to connect after ${maxAttempts} attempts. Exiting.`);
        process.exit(1);
    }
    
    // Start the continuous operations
    await runContinuousOperations();
}

main().catch(console.error);
