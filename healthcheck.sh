#!/bin/sh

# Health check script for PowerPoint MCP Server
# Supports both HTTP and stdio transport modes

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Health check for HTTP mode
check_http_health() {
    local port=${HTTP_PORT:-8000}
    local max_retries=3
    local retry_delay=1
    
    for i in $(seq 1 $max_retries); do
        # Try to connect to the HTTP port
        if command -v wget >/dev/null 2>&1; then
            # Use wget if available
            if wget -q --timeout=5 --tries=1 -O /dev/null "http://localhost:$port/health" 2>/dev/null; then
                echo "${GREEN}HTTP health check passed${NC}"
                return 0
            fi
        elif command -v curl >/dev/null 2>&1; then
            # Use curl if available
            if curl -s --max-time 5 --fail "http://localhost:$port/health" >/dev/null 2>&1; then
                echo "${GREEN}HTTP health check passed${NC}"
                return 0
            fi
        elif command -v nc >/dev/null 2>&1; then
            # Use netcat as fallback
            if nc -z localhost $port 2>/dev/null; then
                echo "${GREEN}HTTP port $port is reachable${NC}"
                return 0
            fi
        else
            # Basic port check using /proc/net/tcp
            if [ -f /proc/net/tcp ]; then
                local hex_port=$(printf "%04X" $port)
                if grep -q ":$hex_port " /proc/net/tcp 2>/dev/null; then
                    echo "${GREEN}HTTP port $port is listening${NC}"
                    return 0
                fi
            fi
        fi
        
        if [ $i -lt $max_retries ]; then
            sleep $retry_delay
        fi
    done
    
    echo "${RED}HTTP health check failed after $max_retries attempts${NC}"
    return 1
}

# Health check for stdio mode
check_stdio_health() {
    # Check if the Python process is running
    if [ ! -z "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "${GREEN}Stdio process health check passed${NC}"
        return 0
    fi
    
    # Alternative: check for python process running ppt_mcp_server.py
    if pgrep -f "ppt_mcp_server.py" >/dev/null 2>&1; then
        echo "${GREEN}Stdio process is running${NC}"
        return 0
    fi
    
    # Check if the process is responsive to signals
    local main_pid=$(pgrep -f "ppt_mcp_server.py" | head -1)
    if [ ! -z "$main_pid" ] && kill -0 "$main_pid" 2>/dev/null; then
        echo "${GREEN}Stdio process is responsive${NC}"
        return 0
    fi
    
    echo "${RED}Stdio health check failed - process not running or responsive${NC}"
    return 1
}

# Check if required files exist
check_application_files() {
    if [ ! -f "/app/ppt_mcp_server.py" ]; then
        echo "${RED}Main application file missing: /app/ppt_mcp_server.py${NC}"
        return 1
    fi
    
    if [ ! -d "/app/tools" ]; then
        echo "${RED}Tools directory missing: /app/tools${NC}"
        return 1
    fi
    
    if [ ! -d "/app/utils" ]; then
        echo "${RED}Utils directory missing: /app/utils${NC}"
        return 1
    fi
    
    return 0
}

# Main health check logic
main() {
    local transport_mode=${TRANSPORT_MODE:-stdio}
    
    echo "Running health check for transport mode: $transport_mode"
    
    # Check application files first
    if ! check_application_files; then
        exit 1
    fi
    
    # Run transport-specific health check
    case "$transport_mode" in
        "http")
            check_http_health
            ;;
        "stdio")
            check_stdio_health
            ;;
        *)
            echo "${RED}Unknown transport mode: $transport_mode${NC}"
            exit 1
            ;;
    esac
    
    local health_result=$?
    
    if [ $health_result -eq 0 ]; then
        echo "${GREEN}Overall health check: PASSED${NC}"
        exit 0
    else
        echo "${RED}Overall health check: FAILED${NC}"
        exit 1
    fi
}

# Run main function
main "$@"