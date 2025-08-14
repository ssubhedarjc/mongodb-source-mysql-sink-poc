# MongoDB CDC to PostgreSQL Pipeline POC

This project demonstrates a Change Data Capture (CDC) pipeline that captures changes from MongoDB and replicates them to PostgreSQL using Kafka and Debezium.

## Architecture

```
MongoDB (systemusers) → Debezium Connector → Kafka → JDBC Sink Connector → PostgreSQL
```

### Components

- **MongoDB**: Source database with `systemusers` collection
- **Apache Kafka**: Message broker for streaming changes
- **Debezium MongoDB Connector**: Captures changes from MongoDB
- **Confluent JDBC Sink Connector**: Writes changes to PostgreSQL
- **PostgreSQL**: Target relational database
- **Schema Registry**: Manages Avro schemas
- **Kafka UI**: Web interface for monitoring Kafka

## Prerequisites

- Docker and Docker Compose
- At least 4GB RAM allocated to Docker
- Ports 5432, 8080, 8081, 8083, 9092, 27017 should be available

## Quick Start

1. **Start the pipeline**:
   ```bash
   chmod +x *.sh
   ./start-pipeline.sh
   ```

2. **Test the pipeline**:
   ```bash
   ./test-pipeline.sh
   ```

3. **Test the pipeline**:
   ```bash
   ./test-pipeline.sh
   ```

4. **Start continuous CRUD operations** (in a separate terminal):
   ```bash
   ./continuous-crud.sh
   ```

5. **Monitor real-time changes** (in another terminal):
   ```bash
   ./monitor-realtime.sh
   # OR for change-only monitoring:
   ./monitor-changes.sh
   ```

6. **Clean up**:
   ```bash
   ./cleanup.sh
   ```

## MongoDB Schema

The `systemusers` collection contains user data with the following structure:

```javascript
{
  userId: "user001",              // Unique identifier
  firstName: "John",              // User's first name
  lastName: "Doe",                // User's last name
  email: "john.doe@example.com",  // Email address
  department: "Engineering",       // Department
  role: "Developer",              // Job role
  isActive: true,                 // Active status
  createdAt: ISODate(),           // Creation timestamp
  lastLoginAt: ISODate()          // Last login timestamp
}
```

## PostgreSQL Schema

The target `systemusers` table:

```sql
CREATE TABLE systemusers (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    department VARCHAR(255),
    role VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP,
    last_login_at TIMESTAMP,
    kafka_offset BIGINT,
    kafka_partition INTEGER,
    kafka_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Service URLs

- **MongoDB**: `mongodb://admin:password@localhost:27017`
- **PostgreSQL**: `postgresql://postgres:password@localhost:5432/testdb`
- **Kafka**: `localhost:9092`
- **Kafka Connect API**: `http://localhost:8083`
- **Kafka UI**: `http://localhost:8080`
- **Schema Registry**: `http://localhost:8081`

## Monitoring and Management

### Check Connector Status
```bash
# MongoDB source connector status
curl http://localhost:8083/connectors/mongodb-source-connector/status

# PostgreSQL sink connector status
curl http://localhost:8083/connectors/postgres-sink-connector/status
```

### View Kafka Topics
```bash
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

### Connect to MongoDB
```bash
docker exec -it mongodb mongosh --host mongodb:27017 --username admin --password password --authenticationDatabase admin
```

### Connect to PostgreSQL
```bash
docker exec -it postgres psql -U postgres -d testdb
```

## Testing the CDC Pipeline

### Continuous Testing

For comprehensive testing, use the continuous CRUD script in one terminal:
```bash
./continuous-crud.sh
```

This script will:
- **Insert** new users (40% probability)
- **Update** existing users (30% probability) 
- **Soft delete** users by setting `isActive=false` (20% probability)
- **Hard delete** users (10% probability, maintains minimum 5 users)
- Show statistics every 10 operations
- Use random realistic data for testing

### Real-time Monitoring

Monitor the pipeline in real-time with:
```bash
# Full dashboard view (refreshes every 3 seconds)
./monitor-realtime.sh

# OR change-only monitoring
./monitor-changes.sh
```

The real-time monitor shows:
- Current document/row counts in both databases
- Sync status and lag detection  
- Recent data comparison
- Connector health status
- Kafka offset information

### Manual Testing

#### Insert data in MongoDB:
```javascript
use testdb;
db.systemusers.insertOne({
  userId: "user005",
  firstName: "Carol",
  lastName: "Davis",
  email: "carol.davis@example.com",
  department: "Finance",
  role: "Analyst",
  isActive: true,
  createdAt: new Date(),
  lastLoginAt: new Date()
});
```

#### Update data in MongoDB:
```javascript
db.systemusers.updateOne(
  { userId: "user001" },
  { $set: { role: "Senior Developer", lastLoginAt: new Date() } }
);
```

#### Query data in PostgreSQL:
```sql
SELECT * FROM systemusers WHERE is_active = true ORDER BY kafka_timestamp DESC;
```

## Troubleshooting

### Common Issues

1. **Connectors not starting**: Check logs with `docker-compose logs kafka-connect`
2. **MongoDB replica set issues**: Ensure replica set is initialized properly
3. **Schema evolution errors**: Check Schema Registry at `http://localhost:8081`

### Logs
```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs kafka-connect
docker-compose logs mongodb
docker-compose logs postgres
```

### Reset Pipeline
```bash
./cleanup.sh
./start-pipeline.sh
```

## Configuration Files

- `docker-compose.yml`: Service definitions
- `connectors/mongodb-source.json`: MongoDB source connector config
- `connectors/postgres-sink.json`: PostgreSQL sink connector config
- `mongodb-init/init-replica-set.sh`: MongoDB initialization
- `postgres-init/init.sql`: PostgreSQL schema setup

## Monitoring and Testing Scripts

- `start-pipeline.sh`: Complete setup and initialization
- `test-pipeline.sh`: One-time test with sample operations
- `continuous-crud.sh`: Continuous CRUD operations for testing
- `monitor-realtime.sh`: Real-time side-by-side data comparison
- `monitor-changes.sh`: Live change detection and logging
- `status.sh`: Pipeline health and status check
- `cleanup.sh`: Stop and clean up all resources

## Features Demonstrated

- ✅ Real-time change capture from MongoDB
- ✅ Schema evolution and transformation
- ✅ Kafka-based event streaming
- ✅ Automatic PostgreSQL table synchronization
- ✅ Monitoring and observability
- ✅ Data type transformations (camelCase to snake_case)
- ✅ Metadata tracking (Kafka offset, partition, timestamp)

## Production Considerations

For production deployment, consider:

- Setting up proper authentication and SSL/TLS
- Configuring appropriate replication factors
- Setting up monitoring and alerting
- Implementing proper backup strategies
- Performance tuning for high throughput
- Error handling and dead letter queues
