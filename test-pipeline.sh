#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Testing MongoDB CDC Pipeline...${NC}"

# Test 1: Insert a new user in MongoDB
echo -e "${YELLOW}Test 1: Inserting new user in MongoDB...${NC}"
docker exec -it mongodb mongosh --host localhost:27017 --eval "
use testdb;
db.systemusers.insertOne({
  userId: 'user004',
  firstName: 'Alice',
  lastName: 'Brown',
  email: 'alice.brown@example.com',
  department: 'HR',
  role: 'Manager',
  isActive: true,
  createdAt: new Date(),
  lastLoginAt: new Date()
});
"

sleep 5

# Test 2: Update an existing user
echo -e "${YELLOW}Test 2: Updating existing user in MongoDB...${NC}"
docker exec -it mongodb mongosh --host localhost:27017 --eval "
use testdb;
db.systemusers.updateOne(
  { userId: 'user001' },
  { \$set: { department: 'Senior Engineering', role: 'Senior Developer', lastLoginAt: new Date() } }
);
"

sleep 5

# Test 3: Check PostgreSQL data
echo -e "${YELLOW}Test 3: Checking PostgreSQL data...${NC}"
echo -e "${BLUE}Data in PostgreSQL:${NC}"
docker exec -it postgres psql -U postgres -d testdb -c "SELECT user_id, first_name, last_name, email, department, role, is_active FROM systemusers ORDER BY user_id;"

sleep 2

# Test 4: Delete a user (soft delete by setting isActive to false)
echo -e "${YELLOW}Test 4: Soft deleting user in MongoDB...${NC}"
docker exec -it mongodb mongosh --host localhost:27017 --eval "
use testdb;
db.systemusers.updateOne(
  { userId: 'user003' },
  { \$set: { isActive: false, lastLoginAt: new Date() } }
);
"

sleep 5

# Final check
echo -e "${YELLOW}Final check: PostgreSQL data after all operations...${NC}"
echo -e "${BLUE}Final data in PostgreSQL:${NC}"
docker exec -it postgres psql -U postgres -d testdb -c "SELECT user_id, first_name, last_name, email, department, role, is_active, kafka_timestamp FROM systemusers ORDER BY user_id;"

echo ""
echo -e "${GREEN}Pipeline test completed!${NC}"
echo ""
echo -e "${GREEN}Additional monitoring commands:${NC}"
echo "- View Kafka topics: docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list"
echo "- View MongoDB data: docker exec -it mongodb mongosh --host mongodb:27017 --username admin --password password --authenticationDatabase admin"
echo "- View PostgreSQL data: docker exec -it postgres psql -U postgres -d testdb"
echo "- Kafka UI: http://localhost:8080"
