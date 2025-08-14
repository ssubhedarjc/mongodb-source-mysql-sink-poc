#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}Latest Changes Monitor${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Store previous counts for change detection
prev_mongo_count=0
prev_pg_count=0

# Function to log changes
log_change() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${CYAN}[$timestamp]${NC} $1"
}

# Trap Ctrl+C to exit gracefully
trap 'echo -e "\n${GREEN}Stopping change monitor...${NC}"; exit 0' INT

# Initial counts
prev_mongo_count=$(docker exec mongodb mongosh --host localhost:27017 --quiet --eval "db.getSiblingDB('cdc_poc').systemusers.countDocuments()" 2>/dev/null || echo "0")
prev_pg_count=$(docker exec postgres psql -U postgres -d testdb -t -c "SELECT COUNT(*) FROM systemusers;" 2>/dev/null | tr -d ' ' || echo "0")

log_change "Starting monitoring... MongoDB: $prev_mongo_count, PostgreSQL: $prev_pg_count"

while true; do
    # Get current counts
    current_mongo_count=$(docker exec mongodb mongosh --host localhost:27017 --quiet --eval "db.getSiblingDB('cdc_poc').systemusers.countDocuments()" 2>/dev/null || echo "0")
    current_pg_count=$(docker exec postgres psql -U postgres -d testdb -t -c "SELECT COUNT(*) FROM systemusers;" 2>/dev/null | tr -d ' ' || echo "0")
    
    # Check for changes in MongoDB
    if [ "$current_mongo_count" -ne "$prev_mongo_count" ]; then
        diff=$((current_mongo_count - prev_mongo_count))
        if [ $diff -gt 0 ]; then
            log_change "${GREEN}MongoDB: +$diff documents${NC} (Total: $current_mongo_count)"
            
            # Show the latest document
            latest_doc=$(docker exec mongodb mongosh --host localhost:27017 --quiet --eval "
            var latest = db.getSiblingDB('cdc_poc').systemusers.find().sort({_id: -1}).limit(1).toArray()[0];
            if (latest) {
                print('  Latest: ' + latest.userId + ' (' + latest.firstName + ' ' + latest.lastName + ') - ' + latest.department);
            }
            " 2>/dev/null | grep "Latest:")
            
            if [ -n "$latest_doc" ]; then
                echo -e "    $latest_doc"
            fi
        else
            log_change "${RED}MongoDB: $diff documents${NC} (Total: $current_mongo_count)"
        fi
        prev_mongo_count=$current_mongo_count
    fi
    
    # Check for changes in PostgreSQL
    if [ "$current_pg_count" -ne "$prev_pg_count" ]; then
        diff=$((current_pg_count - prev_pg_count))
        if [ $diff -gt 0 ]; then
            log_change "${BLUE}PostgreSQL: +$diff rows${NC} (Total: $current_pg_count)"
            
            # Show the latest row
            latest_row=$(docker exec postgres psql -U postgres -d testdb -t -c "
            SELECT '  Latest: ' || user_id || ' (' || first_name || ' ' || last_name || ') - ' || department 
            FROM systemusers 
            ORDER BY kafka_timestamp DESC 
            LIMIT 1;
            " 2>/dev/null | grep "Latest:" | sed 's/^ *//')
            
            if [ -n "$latest_row" ]; then
                echo -e "    $latest_row"
            fi
        else
            log_change "${RED}PostgreSQL: $diff rows${NC} (Total: $current_pg_count)"
        fi
        prev_pg_count=$current_pg_count
    fi
    
    # Check sync status
    if [ "$current_mongo_count" -ne "$current_pg_count" ]; then
        sync_diff=$((current_mongo_count - current_pg_count))
        if [ $sync_diff -ne 0 ]; then
            log_change "${YELLOW}⚠️ Sync lag detected: $sync_diff documents pending${NC}"
        fi
    fi
    
    sleep 2
done
