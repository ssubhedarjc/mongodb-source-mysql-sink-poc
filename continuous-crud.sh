#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting continuous CRUD operations on systemusers collection...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Counter for unique user IDs
counter=1000

# Function to generate random data
generate_random_user() {
    local user_id="user$(printf "%03d" $counter)"
    local first_names=("Alice" "Bob" "Charlie" "Diana" "Eve" "Frank" "Grace" "Henry" "Ivy" "Jack" "Kate" "Liam" "Mia" "Noah" "Olivia" "Paul" "Quinn" "Ruby" "Sam" "Tina")
    local last_names=("Smith" "Johnson" "Williams" "Brown" "Jones" "Garcia" "Miller" "Davis" "Rodriguez" "Martinez" "Hernandez" "Lopez" "Gonzalez" "Wilson" "Anderson" "Thomas" "Taylor" "Moore" "Jackson" "Martin")
    local departments=("Engineering" "Marketing" "Sales" "HR" "Finance" "Operations" "Support" "Legal" "Design" "Product")
    local roles=("Manager" "Developer" "Analyst" "Representative" "Coordinator" "Specialist" "Lead" "Director" "Associate" "Intern")
    
    local first_name=${first_names[$RANDOM % ${#first_names[@]}]}
    local last_name=${last_names[$RANDOM % ${#last_names[@]}]}
    local department=${departments[$RANDOM % ${#departments[@]}]}
    local role=${roles[$RANDOM % ${#roles[@]}]}
    local email="${first_name,,}.${last_name,,}@example.com"
    
    echo "{ userId: \"$user_id\", firstName: \"$first_name\", lastName: \"$last_name\", email: \"$email\", department: \"$department\", role: \"$role\", isActive: true, createdAt: new Date(), lastLoginAt: new Date() }"
}

# Function to get existing user IDs
get_existing_users() {
    docker exec mongodb mongosh --host localhost:27017 --quiet --eval "
    use testdb;
    db.systemusers.find({}, {userId: 1, _id: 0}).toArray().map(u => u.userId);
    " 2>/dev/null | grep -o '"user[0-9]*"' | tr -d '"' | head -20
}

# Function to perform INSERT operation
perform_insert() {
    local user_data=$(generate_random_user)
    echo -e "${CYAN}[$(date '+%H:%M:%S')] INSERT:${NC} Creating user$(printf "%03d" $counter)"
    
    docker exec mongodb mongosh --host localhost:27017 --quiet --eval "
    use testdb;
    db.systemusers.insertOne($user_data);
    " >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "  ✅ Successfully inserted user$(printf "%03d" $counter)"
    else
        echo -e "  ❌ Failed to insert user$(printf "%03d" $counter)"
    fi
    
    ((counter++))
}

# Function to perform UPDATE operation
perform_update() {
    local users=($(get_existing_users))
    if [ ${#users[@]} -eq 0 ]; then
        echo -e "${YELLOW}[$(date '+%H:%M:%S')] UPDATE: No users found to update${NC}"
        return
    fi
    
    local user_to_update=${users[$RANDOM % ${#users[@]}]}
    local departments=("Engineering" "Marketing" "Sales" "HR" "Finance" "Operations" "Support" "Legal" "Design" "Product")
    local roles=("Manager" "Developer" "Analyst" "Representative" "Coordinator" "Specialist" "Lead" "Director" "Associate" "Intern")
    local new_department=${departments[$RANDOM % ${#departments[@]}]}
    local new_role=${roles[$RANDOM % ${#roles[@]}]}
    
    echo -e "${BLUE}[$(date '+%H:%M:%S')] UPDATE:${NC} Updating $user_to_update"
    
    docker exec mongodb mongosh --host localhost:27017 --quiet --eval "
    use testdb;
    db.systemusers.updateOne(
        { userId: \"$user_to_update\" },
        { \$set: { department: \"$new_department\", role: \"$new_role\", lastLoginAt: new Date() } }
    );
    " >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "  ✅ Successfully updated $user_to_update (dept: $new_department, role: $new_role)"
    else
        echo -e "  ❌ Failed to update $user_to_update"
    fi
}

# Function to perform SOFT DELETE operation (set isActive to false)
perform_soft_delete() {
    local users=($(get_existing_users))
    if [ ${#users[@]} -eq 0 ]; then
        echo -e "${YELLOW}[$(date '+%H:%M:%S')] SOFT DELETE: No users found to deactivate${NC}"
        return
    fi
    
    local user_to_deactivate=${users[$RANDOM % ${#users[@]}]}
    
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] SOFT DELETE:${NC} Deactivating $user_to_deactivate"
    
    docker exec mongodb mongosh --host localhost:27017 --quiet --eval "
    use testdb;
    db.systemusers.updateOne(
        { userId: \"$user_to_deactivate\" },
        { \$set: { isActive: false, lastLoginAt: new Date() } }
    );
    " >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "  ✅ Successfully deactivated $user_to_deactivate"
    else
        echo -e "  ❌ Failed to deactivate $user_to_deactivate"
    fi
}

# Function to perform HARD DELETE operation
perform_hard_delete() {
    local users=($(get_existing_users))
    if [ ${#users[@]} -eq 0 ]; then
        echo -e "${YELLOW}[$(date '+%H:%M:%S')] HARD DELETE: No users found to delete${NC}"
        return
    fi
    
    # Only delete if we have more than 5 users
    if [ ${#users[@]} -le 5 ]; then
        echo -e "${YELLOW}[$(date '+%H:%M:%S')] HARD DELETE: Keeping minimum 5 users, skipping delete${NC}"
        return
    fi
    
    local user_to_delete=${users[$RANDOM % ${#users[@]}]}
    
    echo -e "${RED}[$(date '+%H:%M:%S')] HARD DELETE:${NC} Deleting $user_to_delete"
    
    docker exec mongodb mongosh --host localhost:27017 --quiet --eval "
    use testdb;
    db.systemusers.deleteOne({ userId: \"$user_to_delete\" });
    " >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "  ✅ Successfully deleted $user_to_delete"
    else
        echo -e "  ❌ Failed to delete $user_to_delete"
    fi
}

# Function to show current stats
show_stats() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] STATS:${NC}"
    
    # MongoDB count
    local mongo_count=$(docker exec mongodb mongosh --host localhost:27017 --quiet --eval "
    use testdb;
    db.systemusers.countDocuments();
    " 2>/dev/null)
    
    # PostgreSQL count
    local pg_count=$(docker exec postgres psql -U postgres -d testdb -t -c "SELECT COUNT(*) FROM systemusers;" 2>/dev/null | tr -d ' ')
    
    echo -e "  📊 MongoDB: $mongo_count documents"
    echo -e "  📊 PostgreSQL: $pg_count rows"
    
    if [ "$mongo_count" != "$pg_count" ]; then
        echo -e "  ⚠️  ${YELLOW}Sync difference detected!${NC}"
    else
        echo -e "  ✅ Databases in sync"
    fi
}

# Trap Ctrl+C to exit gracefully
trap 'echo -e "\n${GREEN}Stopping continuous operations...${NC}"; exit 0' INT

# Main loop
operation_count=0
while true; do
    # Determine operation to perform (weighted random)
    rand=$((RANDOM % 100))
    
    if [ $rand -lt 40 ]; then
        # 40% chance - INSERT
        perform_insert
    elif [ $rand -lt 70 ]; then
        # 30% chance - UPDATE
        perform_update
    elif [ $rand -lt 90 ]; then
        # 20% chance - SOFT DELETE
        perform_soft_delete
    else
        # 10% chance - HARD DELETE
        perform_hard_delete
    fi
    
    ((operation_count++))
    
    # Show stats every 10 operations
    if [ $((operation_count % 10)) -eq 0 ]; then
        echo ""
        show_stats
        echo ""
    fi
    
    # Wait between operations (2-8 seconds)
    sleep_time=$((2 + RANDOM % 7))
    sleep $sleep_time
done
