#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting MongoDB CDC to PostgreSQL Pipeline...${NC}"

# Start services
echo -e "${YELLOW}Starting Docker services...${NC}"
docker-compose up -d

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 30

# Check MongoDB status with timeout
echo -e "${YELLOW}Checking MongoDB status...${NC}"
mongodb_ready=false
mongodb_timeout=0
max_mongodb_timeout=60

while [ "$mongodb_ready" = false ] && [ $mongodb_timeout -lt $max_mongodb_timeout ]; do
    if docker exec mongodb mongosh --host localhost:27017 --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
        mongodb_ready=true
        echo -e "${GREEN}MongoDB is ready!${NC}"
    else
        echo "Waiting for MongoDB to be ready... (${mongodb_timeout}s/${max_mongodb_timeout}s)"
        sleep 5
        mongodb_timeout=$((mongodb_timeout + 5))
    fi
done

if [ "$mongodb_ready" = false ]; then
    echo -e "${RED}MongoDB failed to start within ${max_mongodb_timeout} seconds!${NC}"
    echo "Checking MongoDB logs:"
    docker logs mongodb --tail 20
    exit 1
fi

# Wait for replica set initialization to complete
echo -e "${YELLOW}Waiting for replica set initialization...${NC}"
sleep 15

# Check if Kafka Connect is ready with timeout
echo -e "${YELLOW}Checking Kafka Connect status...${NC}"
kafka_ready=false
kafka_timeout=0
max_kafka_timeout=120

while [ "$kafka_ready" = false ] && [ $kafka_timeout -lt $max_kafka_timeout ]; do
    if curl -f http://localhost:8083/connectors >/dev/null 2>&1; then
        kafka_ready=true
        echo -e "${GREEN}Kafka Connect is ready!${NC}"
    else
        echo "Waiting for Kafka Connect to be ready... (${kafka_timeout}s/${max_kafka_timeout}s)"
        sleep 10
        kafka_timeout=$((kafka_timeout + 10))
    fi
done

if [ "$kafka_ready" = false ]; then
    echo -e "${RED}Kafka Connect failed to start within ${max_kafka_timeout} seconds!${NC}"
    echo "Checking Kafka Connect logs:"
    docker logs kafka-connect --tail 20
    exit 1
fi

# Create MongoDB source connector
echo -e "${YELLOW}Creating MongoDB source connector...${NC}"
curl -X POST \
  -H "Content-Type: application/json" \
  --data @connectors/mongodb-source.json \
  http://localhost:8083/connectors

sleep 10

# Create PostgreSQL sink connector
echo -e "${YELLOW}Creating PostgreSQL sink connector...${NC}"
curl -X POST \
  -H "Content-Type: application/json" \
  --data @connectors/postgres-sink.json \
  http://localhost:8083/connectors

echo -e "${GREEN}Setup complete!${NC}"
echo ""
echo -e "${GREEN}Services running:${NC}"
echo "- MongoDB: localhost:27017 (admin/password)"
echo "- PostgreSQL: localhost:5432 (postgres/password)"
echo "- Kafka: localhost:9092"
echo "- Kafka Connect: localhost:8083"
echo "- Kafka UI: http://localhost:8080"
echo "- Schema Registry: localhost:8081"
echo ""
echo -e "${GREEN}To check connector status:${NC}"
echo "curl http://localhost:8083/connectors/mongodb-source-connector/status"
echo "curl http://localhost:8083/connectors/postgres-sink-connector/status"
echo ""
echo -e "${GREEN}To test the pipeline:${NC}"
echo "Run: ./test-pipeline.sh"
