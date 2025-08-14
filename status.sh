#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}MongoDB CDC Pipeline Status${NC}"
echo "==============================="

# Check if services are running
echo -e "${YELLOW}Service Status:${NC}"
services=("zookeeper" "kafka" "schema-registry" "mongodb" "postgres" "kafka-connect" "kafka-ui")

for service in "${services[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "^${service}$"; then
        echo -e "✅ ${service}: ${GREEN}Running${NC}"
    else
        echo -e "❌ ${service}: ${RED}Stopped${NC}"
    fi
done

echo ""

# Check connector status
echo -e "${YELLOW}Connector Status:${NC}"
if curl -s http://localhost:8083/connectors 2>/dev/null | grep -q "mongodb-source-connector"; then
    mongodb_status=$(curl -s http://localhost:8083/connectors/mongodb-source-connector/status | jq -r '.connector.state')
    echo -e "📊 MongoDB Source Connector: ${GREEN}${mongodb_status}${NC}"
else
    echo -e "📊 MongoDB Source Connector: ${RED}Not Found${NC}"
fi

if curl -s http://localhost:8083/connectors 2>/dev/null | grep -q "postgres-sink-connector"; then
    postgres_status=$(curl -s http://localhost:8083/connectors/postgres-sink-connector/status | jq -r '.connector.state')
    echo -e "📊 PostgreSQL Sink Connector: ${GREEN}${postgres_status}${NC}"
else
    echo -e "📊 PostgreSQL Sink Connector: ${RED}Not Found${NC}"
fi

echo ""

# Check topic creation
echo -e "${YELLOW}Kafka Topics:${NC}"
if docker ps --format "table {{.Names}}" | grep -q "^kafka$"; then
    topics=$(docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | grep -E "(mongodb|systemusers)" || echo "No topics found")
    echo "📋 Topics: $topics"
else
    echo -e "📋 Topics: ${RED}Kafka not running${NC}"
fi

echo ""

# Check data counts
echo -e "${YELLOW}Data Counts:${NC}"
if docker ps --format "table {{.Names}}" | grep -q "^mongodb$"; then
    mongo_count=$(docker exec mongodb mongosh --host localhost:27017 --quiet --eval "use testdb; db.systemusers.countDocuments()" 2>/dev/null || echo "Error")
    echo "📄 MongoDB systemusers: $mongo_count documents"
else
    echo -e "📄 MongoDB systemusers: ${RED}MongoDB not running${NC}"
fi

if docker ps --format "table {{.Names}}" | grep -q "^postgres$"; then
    pg_count=$(docker exec postgres psql -U postgres -d testdb -t -c "SELECT COUNT(*) FROM systemusers;" 2>/dev/null | tr -d ' ' || echo "Error")
    echo "📄 PostgreSQL systemusers: $pg_count rows"
else
    echo -e "📄 PostgreSQL systemusers: ${RED}PostgreSQL not running${NC}"
fi

echo ""
echo -e "${BLUE}Access URLs:${NC}"
echo "🌐 Kafka UI: http://localhost:8080"
echo "🔧 Kafka Connect API: http://localhost:8083/connectors"
echo "📊 Schema Registry: http://localhost:8081/subjects"
