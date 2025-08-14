#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${GREEN}Real-time CDC Pipeline Monitor${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
echo ""

# Function to get MongoDB data with timestamps
get_mongodb_data() {
    docker exec mongodb mongosh --host localhost:27017 --quiet --eval "
    use('cdc_poc');
    db.systemusers.find({}, {userId: 1, firstName: 1, lastName: 1, department: 1, role: 1, status: 1, _id: 0})
      .sort({userId: 1})
      .limit(20)
      .toArray()
      .forEach(doc => print(JSON.stringify(doc)));
    " 2>/dev/null | grep -v "^$" | grep -E '^{.*}$'
}

# Function to get PostgreSQL data with timestamps
get_postgresql_data() {
    docker exec postgres psql -U postgres -d testdb -t -c "
    SELECT user_id, first_name, last_name, department, role, status, 
           EXTRACT(EPOCH FROM \"createdAt\")::INTEGER as created_ts
    FROM systemusers 
    ORDER BY user_id 
    LIMIT 20;
    " 2>/dev/null | grep -v "^$" | while read line; do
        echo "$line" | sed 's/|/,/g' | sed 's/^ *//g' | sed 's/ *$//g'
    done
}

# Function to get Kafka topic lag
get_kafka_lag() {
    local topic_info=$(docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic mongodb.cdc_poc.systemusers \
        --time -1 2>/dev/null | head -1)
    
    if [ -n "$topic_info" ]; then
        echo "$topic_info" | cut -d':' -f3
    else
        echo "0"
    fi
}

# Function to display side-by-side comparison
display_comparison() {
    clear
    echo -e "${GREEN}=== CDC Pipeline Real-time Monitor ===${NC}"
    echo -e "${BLUE}$(date)${NC}"
    echo ""
    
    # Get counts
    local mongo_count=$(docker exec mongodb mongosh --host localhost:27017 --quiet --eval "use('cdc_poc'); db.systemusers.countDocuments();" 2>/dev/null | tail -1 | grep -E '^[0-9]+$')
    local pg_count=$(docker exec postgres psql -U postgres -d testdb -t -c "SELECT COUNT(*) FROM systemusers;" 2>/dev/null | tr -d ' ' | grep -E '^[0-9]+$')
    local kafka_offset=$(get_kafka_lag)
    
    echo -e "${CYAN}📊 Statistics:${NC}"
    echo -e "   MongoDB Documents: ${YELLOW}$mongo_count${NC}"
    echo -e "   PostgreSQL Rows:   ${YELLOW}$pg_count${NC}"
    echo -e "   Kafka Offset:      ${YELLOW}$kafka_offset${NC}"
    
    if [ "$mongo_count" = "$pg_count" ]; then
        echo -e "   Sync Status:       ${GREEN}✅ In Sync${NC}"
    else
        echo -e "   Sync Status:       ${RED}⚠️ Out of Sync (diff: $((mongo_count - pg_count)))${NC}"
    fi
    
    echo ""
    echo -e "${MAGENTA}📋 All Users (Max 20 for easy tracking):${NC}"
    
    # Headers
    printf "%-15s %-12s %-12s %-12s %-12s %-8s\n" "User ID" "First Name" "Last Name" "Department" "Role" "Status"
    printf "%-15s %-12s %-12s %-12s %-12s %-8s\n" "---------------" "----------" "----------" "----------" "----" "------"
    
    # Get and display MongoDB data
    echo -e "${YELLOW}MongoDB:${NC}"
    get_mongodb_data | while IFS= read -r line; do
        if [ -n "$line" ]; then
            # Parse JSON and format
            user_id=$(echo "$line" | grep -o '"userId":"[^"]*"' | cut -d'"' -f4)
            first_name=$(echo "$line" | grep -o '"firstName":"[^"]*"' | cut -d'"' -f4)
            last_name=$(echo "$line" | grep -o '"lastName":"[^"]*"' | cut -d'"' -f4)
            department=$(echo "$line" | grep -o '"department":"[^"]*"' | cut -d'"' -f4)
            role=$(echo "$line" | grep -o '"role":"[^"]*"' | cut -d'"' -f4)
            status=$(echo "$line" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            
            printf "%-15s %-12s %-12s %-12s %-12s %-8s\n" \
                "${user_id:-N/A}" "${first_name:-N/A}" "${last_name:-N/A}" \
                "${department:-N/A}" "${role:-N/A}" "${status:-N/A}"
        fi
    done
    
    echo ""
    echo -e "${BLUE}PostgreSQL:${NC}"
    get_postgresql_data | while IFS=',' read -r user_id first_name last_name department role status created_ts; do
        if [ -n "$user_id" ]; then
            printf "%-15s %-12s %-12s %-12s %-12s %-8s\n" \
                "${user_id// /}" "${first_name// /}" "${last_name// /}" \
                "${department// /}" "${role// /}" "${status// /}"
        fi
    done
}

# Function to show connector status
show_connector_status() {
    echo ""
    echo -e "${CYAN}🔧 Connector Status:${NC}"
    
    # MongoDB Source Connector
    if curl -s http://localhost:8083/connectors/mongodb-source-connector/status >/dev/null 2>&1; then
        local mongo_status=$(curl -s http://localhost:8083/connectors/mongodb-source-connector/status | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo -e "   MongoDB Source: ${GREEN}$mongo_status${NC}"
    else
        echo -e "   MongoDB Source: ${RED}Not Available${NC}"
    fi
    
    # PostgreSQL Sink Connector
    if curl -s http://localhost:8083/connectors/postgres-sink-connector/status >/dev/null 2>&1; then
        local pg_status=$(curl -s http://localhost:8083/connectors/postgres-sink-connector/status | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4)
        echo -e "   PostgreSQL Sink: ${GREEN}$pg_status${NC}"
    else
        echo -e "   PostgreSQL Sink: ${RED}Not Available${NC}"
    fi
}

# Trap Ctrl+C to exit gracefully
trap 'echo -e "\n${GREEN}Stopping monitor...${NC}"; exit 0' INT

# Main monitoring loop
monitor_count=0
while true; do
    display_comparison
    
    # Show connector status every 5 iterations
    if [ $((monitor_count % 5)) -eq 0 ]; then
        show_connector_status
    fi
    
    echo ""
    echo -e "${YELLOW}Refreshing in 3 seconds... (Ctrl+C to stop)${NC}"
    
    ((monitor_count++))
    sleep 3
done
