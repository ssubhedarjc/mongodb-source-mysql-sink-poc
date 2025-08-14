-- Create the systemusers table to store data from MongoDB
CREATE TABLE IF NOT EXISTS systemusers (
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_systemusers_user_id ON systemusers(user_id);
CREATE INDEX IF NOT EXISTS idx_systemusers_email ON systemusers(email);
CREATE INDEX IF NOT EXISTS idx_systemusers_department ON systemusers(department);

-- Create a table to track CDC operations
CREATE TABLE IF NOT EXISTS cdc_operations (
    id SERIAL PRIMARY KEY,
    operation_type VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    document_id VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    kafka_topic VARCHAR(255),
    kafka_partition INTEGER,
    kafka_offset BIGINT
);
