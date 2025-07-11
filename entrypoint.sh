#!/bin/sh
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_info() {
    log "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    log "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# Signal handler for graceful shutdown
shutdown() {
    log_info "Received shutdown signal, terminating gracefully..."
    if [ ! -z "$SERVER_PID" ]; then
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

# Display startup information
log_info "Starting PowerPoint MCP Server"
log_info "Transport Mode: ${TRANSPORT_MODE}"
log_info "HTTP Port: ${HTTP_PORT}"
log_info "Template Path: ${PPT_TEMPLATE_PATH}"
log_info "Log Level: ${LOG_LEVEL}"
log_info "Python Path: ${PYTHONPATH}"

# Validate environment variables
if [ -z "$TRANSPORT_MODE" ]; then
    log_error "TRANSPORT_MODE environment variable is not set"
    exit 1
fi

if [ "$TRANSPORT_MODE" != "stdio" ] && [ "$TRANSPORT_MODE" != "http" ]; then
    log_error "TRANSPORT_MODE must be 'stdio' or 'http', got: $TRANSPORT_MODE"
    exit 1
fi

if [ "$TRANSPORT_MODE" = "http" ]; then
    if [ -z "$HTTP_PORT" ]; then
        log_error "HTTP_PORT must be set when using HTTP transport mode"
        exit 1
    fi
    
    # Validate port number
    if ! echo "$HTTP_PORT" | grep -q '^[0-9]\+$' || [ "$HTTP_PORT" -lt 1 ] || [ "$HTTP_PORT" -gt 65535 ]; then
        log_error "HTTP_PORT must be a valid port number (1-65535), got: $HTTP_PORT"
        exit 1
    fi
fi

# Validate template path
if [ ! -z "$PPT_TEMPLATE_PATH" ]; then
    if [ ! -d "$PPT_TEMPLATE_PATH" ]; then
        log_warn "Template directory $PPT_TEMPLATE_PATH does not exist, creating it..."
        mkdir -p "$PPT_TEMPLATE_PATH" 2>/dev/null || {
            log_error "Failed to create template directory: $PPT_TEMPLATE_PATH"
            exit 1
        }
    fi
    log_info "Template directory: $PPT_TEMPLATE_PATH"
fi

# Check if main application file exists
if [ ! -f "/app/ppt_mcp_server.py" ]; then
    log_error "Main application file not found: /app/ppt_mcp_server.py"
    exit 1
fi

# Verify Python and required modules
log_info "Verifying Python installation..."
python --version || {
    log_error "Python is not available"
    exit 1
}

# Check for required Python modules
log_info "Checking required Python modules..."
python -c "import mcp" || {
    log_error "Required module 'mcp' not found"
    exit 1
}

python -c "import pptx" || {
    log_error "Required module 'python-pptx' not found"
    exit 1
}

# Build command arguments
ARGS=""

# Handle command line arguments or use environment variables
if [ $# -gt 0 ]; then
    # Use command line arguments
    ARGS="$@"
else
    # Build arguments from environment variables
    ARGS="--transport $TRANSPORT_MODE"
    if [ "$TRANSPORT_MODE" = "http" ]; then
        ARGS="$ARGS --port $HTTP_PORT"
    fi
fi

# Additional environment-specific setup
if [ "$TRANSPORT_MODE" = "http" ]; then
    log_info "HTTP mode configuration:"
    log_info "  - Port: $HTTP_PORT"
    log_info "  - External access: enabled"
    log_info "  - Health check: enabled"
    
    # Check if port is available (basic check)
    if command -v netstat >/dev/null 2>&1; then
        if netstat -ln | grep -q ":$HTTP_PORT "; then
            log_warn "Port $HTTP_PORT appears to be in use"
        fi
    fi
else
    log_info "Stdio mode configuration:"
    log_info "  - Input/Output: standard streams"
    log_info "  - External access: disabled"
    log_info "  - Health check: process-based"
    
    # Debug TTY and stdin status
    if [ -t 0 ]; then
        log_info "  - TTY detected: YES (interactive terminal available)"
    else
        log_warn "  - TTY detected: NO (non-interactive mode)"
    fi
    
    if [ -p /dev/stdin ]; then
        log_info "  - Stdin pipe: YES"
    else
        log_warn "  - Stdin pipe: NO"
    fi
    
    # Check if stdin is connected
    if [ ! -t 0 ] && [ ! -p /dev/stdin ]; then
        log_error "STDIO mode requires an interactive terminal or stdin pipe!"
        log_error "Run with: docker run -it --name ppt-mcp-stdio ..."
        log_error "Or pipe input: echo '{}' | docker run -i --name ppt-mcp-stdio ..."
    fi
fi

# Set Python unbuffered output for better logging
export PYTHONUNBUFFERED=1

# Final startup message
log_info "Starting PowerPoint MCP Server with command: python ppt_mcp_server.py $ARGS"
log_info "Process ID: $$"
log_info "User: $(whoami)"
log_info "Working directory: $(pwd)"

# For stdio mode, run in foreground to maintain stdin/stdout connection
if [ "$TRANSPORT_MODE" = "stdio" ]; then
    log_info "Running in STDIO mode - server will run in foreground"
    exec python ppt_mcp_server.py $ARGS
else
    # For HTTP mode, run in background as before
    log_info "Running in HTTP mode - server will run in background"
    python ppt_mcp_server.py $ARGS &
    SERVER_PID=$!
    
    # Wait for the server to start
    log_info "Waiting for server to start..."
    sleep 3
    
    # Check if server is running
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        log_error "Server failed to start"
        exit 1
    fi
    
    log_info "Server is accessible on port $HTTP_PORT from outside the container"
    
    # Wait for server process to exit
    wait $SERVER_PID
    EXIT_CODE=$?
fi

# Log exit information
if [ $EXIT_CODE -eq 0 ]; then
    log_info "PowerPoint MCP Server exited normally"
else
    log_error "PowerPoint MCP Server exited with code: $EXIT_CODE"
fi

exit $EXIT_CODE