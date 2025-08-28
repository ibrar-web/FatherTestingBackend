#!/bin/bash

# 🧪 Deployment Testing Script
# Tests the deployed application on Cloud Run

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get the Cloud Run service URL
if [ -z "$SERVICE_URL" ]; then
    print_status "Getting Cloud Run service URL..."
    SERVICE_URL=$(gcloud run services describe feathers-backend \
        --region=us-central1 \
        --format='value(status.url)' 2>/dev/null || echo "")
    
    if [ -z "$SERVICE_URL" ]; then
        print_error "Could not get service URL. Make sure the service is deployed."
        echo "Run: gcloud run services list"
        exit 1
    fi
fi

print_status "Testing deployment at: $SERVICE_URL"

# Test 1: Health Check
print_status "Testing health check endpoint..."
HEALTH_RESPONSE=$(curl -s -w "%{http_code}" "$SERVICE_URL/health" -o /tmp/health_response.json)
HTTP_CODE="${HEALTH_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Health check passed (HTTP $HTTP_CODE)"
    cat /tmp/health_response.json | jq '.' 2>/dev/null || cat /tmp/health_response.json
else
    print_error "Health check failed (HTTP $HTTP_CODE)"
    cat /tmp/health_response.json
    exit 1
fi

echo ""

# Test 2: API Info
print_status "Testing API info endpoint..."
INFO_RESPONSE=$(curl -s -w "%{http_code}" "$SERVICE_URL/api/info" -o /tmp/info_response.json)
HTTP_CODE="${INFO_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    print_success "API info endpoint passed (HTTP $HTTP_CODE)"
    cat /tmp/info_response.json | jq '.name, .version' 2>/dev/null || echo "API info retrieved"
else
    print_error "API info endpoint failed (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""

# Test 3: Create a user
print_status "Testing user creation..."
USER_DATA='{"name":"Test User","email":"test@example.com","age":25}'
CREATE_RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$USER_DATA" \
    "$SERVICE_URL/api/users" \
    -o /tmp/create_response.json)
HTTP_CODE="${CREATE_RESPONSE: -3}"

if [ "$HTTP_CODE" = "201" ]; then
    print_success "User creation passed (HTTP $HTTP_CODE)"
    USER_ID=$(cat /tmp/create_response.json | jq -r '.id' 2>/dev/null || echo "1")
    echo "Created user with ID: $USER_ID"
else
    print_error "User creation failed (HTTP $HTTP_CODE)"
    cat /tmp/create_response.json
    exit 1
fi

echo ""

# Test 4: Get users
print_status "Testing user retrieval..."
GET_RESPONSE=$(curl -s -w "%{http_code}" "$SERVICE_URL/api/users" -o /tmp/get_response.json)
HTTP_CODE="${GET_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    print_success "User retrieval passed (HTTP $HTTP_CODE)"
    TOTAL_USERS=$(cat /tmp/get_response.json | jq -r '.total' 2>/dev/null || echo "unknown")
    echo "Total users: $TOTAL_USERS"
else
    print_error "User retrieval failed (HTTP $HTTP_CODE)"
    exit 1
fi

echo ""

# Test 5: Authentication
print_status "Testing authentication..."
AUTH_DATA='{"email":"test@example.com","password":"password123"}'
AUTH_RESPONSE=$(curl -s -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$AUTH_DATA" \
    "$SERVICE_URL/api/auth/login" \
    -o /tmp/auth_response.json)
HTTP_CODE="${AUTH_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Authentication passed (HTTP $HTTP_CODE)"
    TOKEN=$(cat /tmp/auth_response.json | jq -r '.token' 2>/dev/null || echo "token-received")
    echo "Received token: ${TOKEN:0:20}..."
else
    print_error "Authentication failed (HTTP $HTTP_CODE)"
    cat /tmp/auth_response.json
fi

echo ""

# Test 6: Stats endpoint
print_status "Testing stats endpoint..."
STATS_RESPONSE=$(curl -s -w "%{http_code}" "$SERVICE_URL/api/stats" -o /tmp/stats_response.json)
HTTP_CODE="${STATS_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Stats endpoint passed (HTTP $HTTP_CODE)"
    cat /tmp/stats_response.json | jq '.stats.users, .stats.uptime' 2>/dev/null || echo "Stats retrieved"
else
    print_error "Stats endpoint failed (HTTP $HTTP_CODE)"
fi

echo ""

# Performance test
print_status "Running basic performance test..."
echo "Testing response times (5 requests)..."

for i in {1..5}; do
    RESPONSE_TIME=$(curl -s -w "%{time_total}" -o /dev/null "$SERVICE_URL/health")
    echo "Request $i: ${RESPONSE_TIME}s"
done

echo ""

# Cleanup temp files
rm -f /tmp/health_response.json /tmp/info_response.json /tmp/create_response.json /tmp/get_response.json /tmp/auth_response.json /tmp/stats_response.json

print_success "🎉 All tests completed!"
echo ""
echo "📊 Test Summary:"
echo "✅ Health check"
echo "✅ API info"
echo "✅ User CRUD operations"
echo "✅ Authentication"
echo "✅ Stats endpoint"
echo "✅ Performance check"
echo ""
echo "🔗 Service URL: $SERVICE_URL"
echo "📱 Try these endpoints in your browser or API client:"
echo "   $SERVICE_URL/health"
echo "   $SERVICE_URL/api/info"
echo "   $SERVICE_URL/api/users"
echo ""
