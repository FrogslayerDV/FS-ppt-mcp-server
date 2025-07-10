#!/bin/bash

# Local Docker Testing Script for PowerPoint MCP Server
# This script helps test the Docker container locally before deployment

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="ppt-mcp-server"
CONTAINER_NAME="ppt-mcp-test"
TEST_PORT=8000

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if Docker is running
check_docker() {
    log_step "Checking Docker installation and status..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker Desktop first."
        log_info "Visit: https://www.docker.com/products/docker-desktop/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker Desktop."
        exit 1
    fi
    
    log_info "Docker is running successfully"
    docker --version
}

# Clean up existing containers and images
cleanup() {
    log_step "Cleaning up existing containers and images..."
    
    # Debug: Show all containers before cleanup
    log_info "Current containers before cleanup:"
    docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}"
    
    # Stop and remove ALL containers with the base name (including suffixes)
    log_info "Looking for containers matching pattern: ${CONTAINER_NAME}*"
    for container in $(docker ps -a --format "{{.Names}}" | grep "^${CONTAINER_NAME}"); do
        log_info "Stopping and removing container: $container"
        docker stop "$container" 2>/dev/null || true
        docker rm "$container" 2>/dev/null || true
    done
    
    # Remove image if it exists
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^${IMAGE_NAME}:"; then
        log_info "Removing existing images for: $IMAGE_NAME"
        docker rmi $(docker images "${IMAGE_NAME}" -q) 2>/dev/null || true
    fi
    
    # Debug: Show containers after cleanup
    log_info "Containers after cleanup:"
    docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}"
}

# Build the Docker image
build_image() {
    log_step "Building Docker image..."
    
    # Check if Dockerfile.enhanced exists
    if [ ! -f "Dockerfile.enhanced" ]; then
        log_error "Dockerfile.enhanced not found. Make sure you're in the project root directory."
        exit 1
    fi
    
    # Build the image
    log_info "Building image: $IMAGE_NAME:latest"
    docker build -f Dockerfile.enhanced -t "$IMAGE_NAME:latest" . || {
        log_error "Docker build failed"
        exit 1
    }
    
    log_info "Docker image built successfully"
    docker images "$IMAGE_NAME"
}

# Test stdio mode
test_stdio_mode() {
    log_step "Testing stdio mode..."
    
    log_info "Starting container in stdio mode..."
    docker run --name "$CONTAINER_NAME-stdio" \
        -e TRANSPORT_MODE=stdio \
        -e LOG_LEVEL=INFO \
        -d \
        "$IMAGE_NAME:latest" &
    
    # Wait a moment for startup
    sleep 5
    
    # Check if container is running
    if docker ps --format "table {{.Names}}" | grep -q "${CONTAINER_NAME}-stdio"; then
        log_info "✅ Container started successfully in stdio mode"
        
        # Show logs
        log_info "Container logs:"
        docker logs "${CONTAINER_NAME}-stdio" 2>&1 | head -20
        
        # Check health
        log_info "Checking container health..."
        docker exec "${CONTAINER_NAME}-stdio" /app/healthcheck.sh || log_warn "Health check failed"
        
    else
        log_error "❌ Container failed to start in stdio mode"
        docker logs "${CONTAINER_NAME}-stdio" 2>&1 || true
        return 1
    fi
    
    # Clean up
    docker stop "${CONTAINER_NAME}-stdio" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}-stdio" 2>/dev/null || true
}

# Test HTTP mode
test_http_mode() {
    log_step "Testing HTTP mode..."
    
    # Check if port is available
    if lsof -i :$TEST_PORT &> /dev/null; then
        log_warn "Port $TEST_PORT is already in use. Trying to free it..."
        lsof -ti :$TEST_PORT | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    log_info "Starting container in HTTP mode on port $TEST_PORT..."
    docker run --name "$CONTAINER_NAME-http" \
        -e TRANSPORT_MODE=http \
        -e HTTP_PORT=$TEST_PORT \
        -e LOG_LEVEL=INFO \
        -p $TEST_PORT:$TEST_PORT \
        -d \
        "$IMAGE_NAME:latest" || {
        log_error "Failed to start container in HTTP mode"
        return 1
    }
    
    # Wait for startup
    log_info "Waiting for server to start..."
    sleep 10
    
    # Check if container is running
    if docker ps --format "table {{.Names}}" | grep -q "${CONTAINER_NAME}-http"; then
        log_info "✅ Container started successfully in HTTP mode"
        
        # Show logs
        log_info "Container logs:"
        docker logs "${CONTAINER_NAME}-http" 2>&1 | tail -10
        
        # Test HTTP endpoint
        log_info "Testing HTTP endpoint..."
        for i in {1..5}; do
            if curl -s -f "http://localhost:$TEST_PORT/health" &> /dev/null; then
                log_info "✅ HTTP endpoint is responding"
                break
            else
                log_warn "Attempt $i/5: HTTP endpoint not ready, waiting..."
                sleep 3
            fi
            
            if [ $i -eq 5 ]; then
                log_error "❌ HTTP endpoint failed to respond after 5 attempts"
                docker logs "${CONTAINER_NAME}-http" 2>&1 || true
                return 1
            fi
        done
        
        # Test MCP server info endpoint (if available)
        log_info "Testing MCP server endpoints..."
        if curl -s "http://localhost:$TEST_PORT/" | grep -q "MCP" 2>/dev/null; then
            log_info "✅ MCP server is responding"
        else
            log_warn "MCP server may not be fully ready (this is normal for some configurations)"
        fi
        
    else
        log_error "❌ Container failed to start in HTTP mode"
        docker logs "${CONTAINER_NAME}-http" 2>&1 || true
        return 1
    fi
    
    # Clean up
    docker stop "${CONTAINER_NAME}-http" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}-http" 2>/dev/null || true
}

# Interactive testing mode
interactive_test() {
    log_step "Starting interactive testing mode..."
    
    echo -e "${YELLOW}Choose testing mode:${NC}"
    echo "1. Stdio mode (for MCP client testing)"
    echo "2. HTTP mode (for API testing)"
    echo "3. Both modes (sequential)"
    echo "4. Exit"
    
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1)
            test_stdio_mode
            ;;
        2)
            test_http_mode
            ;;
        3)
            test_stdio_mode
            sleep 2
            test_http_mode
            ;;
        4)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid choice. Please try again."
            interactive_test
            ;;
    esac
}

# Show container information
show_container_info() {
    log_step "Container information..."
    
    log_info "Docker images:"
    docker images "$IMAGE_NAME" || true
    
    log_info "Running containers:"
    docker ps --filter "name=$CONTAINER_NAME" || true
    
    log_info "All containers (including stopped):"
    docker ps -a --filter "name=$CONTAINER_NAME" || true
}

# Main execution
main() {
    log_info "PowerPoint MCP Server - Local Docker Testing"
    log_info "=============================================="
    
    check_docker
    cleanup
    build_image
    show_container_info
    
    # Run tests based on arguments
    if [ "$1" = "stdio" ]; then
        test_stdio_mode
    elif [ "$1" = "http" ]; then
        test_http_mode
    elif [ "$1" = "both" ]; then
        test_stdio_mode
        sleep 2
        test_http_mode
    else
        interactive_test
    fi
    
    log_info "Testing completed!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Local Docker Testing Script for PowerPoint MCP Server"
        echo
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  -h, --help     Show this help message"
        echo "  stdio          Test only stdio mode"
        echo "  http           Test only HTTP mode"
        echo "  both           Test both modes sequentially"
        echo "  --cleanup      Clean up containers and images only"
        echo "  --build        Build image only"
        echo "  --info         Show container information only"
        echo
        echo "Examples:"
        echo "  $0              # Interactive mode"
        echo "  $0 stdio        # Test stdio mode only"
        echo "  $0 http         # Test HTTP mode only"
        echo "  $0 both         # Test both modes"
        echo "  $0 --cleanup    # Clean up only"
        exit 0
        ;;
    --cleanup)
        check_docker
        cleanup
        log_info "Cleanup completed"
        exit 0
        ;;
    --build)
        check_docker
        cleanup
        build_image
        log_info "Build completed"
        exit 0
        ;;
    --info)
        check_docker
        show_container_info
        exit 0
        ;;
    stdio|http|both)
        main "$1"
        ;;
    "")
        main
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac