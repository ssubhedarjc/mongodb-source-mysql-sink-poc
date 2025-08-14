#!/bin/bash
# Initialize MongoDB replica set (required for CDC)
echo "Waiting for MongoDB to start..."
sleep 15

# Wait for MongoDB to be ready (without authentication initially)
until mongosh --host localhost:27017 --eval "db.adminCommand('ping')" >/dev/null 2>&1; do
    echo "MongoDB not ready yet, waiting..."
    sleep 3
done

echo "MongoDB is ready, initializing replica set..."

# Initialize replica set
mongosh --host localhost:27017 <<EOF
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb:27017" }
  ]
});
EOF

echo "Replica set initialized, waiting for it to be ready..."
sleep 10

# Wait for replica set to become primary
until mongosh --host localhost:27017 --eval "rs.status().myState" 2>/dev/null | grep -q "1"; do
    echo "Waiting for replica set to become primary..."
    sleep 3
done

echo "Replica set is primary, creating sample data..."

# Create database and collection with sample data
mongosh --host localhost:27017 <<EOF
use testdb;

// Create systemusers collection with sample data
db.systemusers.insertMany([
  {
    userId: "user001",
    firstName: "John",
    lastName: "Doe",
    email: "john.doe@example.com",
    department: "Engineering",
    role: "Developer",
    isActive: true,
    createdAt: new Date(),
    lastLoginAt: new Date()
  },
  {
    userId: "user002",
    firstName: "Jane",
    lastName: "Smith",
    email: "jane.smith@example.com",
    department: "Marketing",
    role: "Manager",
    isActive: true,
    createdAt: new Date(),
    lastLoginAt: new Date()
  },
  {
    userId: "user003",
    firstName: "Bob",
    lastName: "Johnson",
    email: "bob.johnson@example.com",
    department: "Sales",
    role: "Representative",
    isActive: false,
    createdAt: new Date(),
    lastLoginAt: new Date()
  }
]);

// Create index on userId for better performance
db.systemusers.createIndex({ userId: 1 }, { unique: true });

console.log("Sample systemusers data created");
EOF

echo "MongoDB initialization completed successfully!"
