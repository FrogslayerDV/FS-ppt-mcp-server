#!/usr/bin/env python
"""
MCP Server for PowerPoint manipulation using python-pptx.
Consolidated version with 20 tools organized into multiple modules.
"""
import os
import argparse
from typing import Dict, Any
from fastmcp import FastMCP
from utils.resource_manager import get_resource_manager

# import utils  # Currently unused
from tools import (
    register_presentation_tools,
    register_content_tools,
    register_structural_tools,
    register_professional_tools,
    register_template_tools,
    register_hyperlink_tools,
    register_chart_tools,
    register_connector_tools,
    register_master_tools,
    register_transition_tools
)

# Initialize the FastMCP server
app = FastMCP(
    name="ppt-mcp-server"
)

# Global state to store presentations in memory
presentations = {}
current_presentation_id = None

# Template configuration
def get_template_search_directories():
    """
    Get list of directories to search for templates.
    Uses environment variable PPT_TEMPLATE_PATH if set, otherwise uses default directories.
    
    Returns:
        List of directories to search for templates
    """
    template_env_path = os.environ.get('PPT_TEMPLATE_PATH')
    
    if template_env_path:
        # If environment variable is set, use it as the primary template directory
        # Support multiple paths separated by colon (Unix) or semicolon (Windows)
        import platform
        separator = ';' if platform.system() == "Windows" else ':'
        env_dirs = [path.strip() for path in template_env_path.split(separator) if path.strip()]
        
        # Verify that the directories exist
        valid_env_dirs = []
        for dir_path in env_dirs:
            expanded_path = os.path.expanduser(dir_path)
            if os.path.exists(expanded_path) and os.path.isdir(expanded_path):
                valid_env_dirs.append(expanded_path)
        
        if valid_env_dirs:
            # Add default fallback directories
            return valid_env_dirs + ['.', './templates', './assets', './resources']
        else:
            print(f"Warning: PPT_TEMPLATE_PATH directories not found: {template_env_path}")
    
    # Default search directories when no environment variable or invalid paths
    return ['.', './templates', './assets', './resources']

# ---- Helper Functions ----

def get_current_presentation():
    """Get the current presentation object or raise an error if none is loaded."""
    if current_presentation_id is None or current_presentation_id not in presentations:
        raise ValueError("No presentation is currently loaded. Please create or open a presentation first.")
    return presentations[current_presentation_id]

def get_current_presentation_id():
    """Get the current presentation ID."""
    return current_presentation_id

def set_current_presentation_id(pres_id):
    """Set the current presentation ID."""
    global current_presentation_id
    current_presentation_id = pres_id

def validate_parameters(params):
    """
    Validate parameters against constraints.
    
    Args:
        params: Dictionary of parameter name: (value, constraints) pairs
        
    Returns:
        (True, None) if all valid, or (False, error_message) if invalid
    """
    for param_name, (value, constraints) in params.items():
        for constraint_func, error_msg in constraints:
            if not constraint_func(value):
                return False, f"Parameter '{param_name}': {error_msg}"
    return True, None

def is_positive(value):
    """Check if a value is positive."""
    return value > 0

def is_non_negative(value):
    """Check if a value is non-negative."""
    return value >= 0

def is_in_range(min_val, max_val):
    """Create a function that checks if a value is in a range."""
    return lambda x: min_val <= x <= max_val

def is_in_list(valid_list):
    """Create a function that checks if a value is in a list."""
    return lambda x: x in valid_list

def is_valid_rgb(color_list):
    """Check if a color list is a valid RGB tuple."""
    if not isinstance(color_list, list) or len(color_list) != 3:
        return False
    return all(isinstance(c, int) and 0 <= c <= 255 for c in color_list)

def add_shape_direct(slide, shape_type: str, left: float, top: float, width: float, height: float) -> Any:
    """
    Add an auto shape to a slide using direct integer values instead of enum objects.
    
    This implementation provides a reliable alternative that bypasses potential 
    enum-related issues in the python-pptx library.
    
    Args:
        slide: The slide object
        shape_type: Shape type string (e.g., 'rectangle', 'oval', 'triangle')
        left: Left position in inches
        top: Top position in inches
        width: Width in inches
        height: Height in inches
        
    Returns:
        The created shape
    """
    from pptx.util import Inches
    
    # Direct mapping of shape types to their integer values
    # These values are directly from the MS Office VBA documentation
    shape_type_map = {
        'rectangle': 1,
        'rounded_rectangle': 2, 
        'oval': 9,
        'diamond': 4,
        'triangle': 5,  # This is ISOSCELES_TRIANGLE
        'right_triangle': 6,
        'pentagon': 56,
        'hexagon': 10,
        'heptagon': 11,
        'octagon': 12,
        'star': 12,  # This is STAR_5_POINTS (value 12)
        'arrow': 13,
        'cloud': 35,
        'heart': 21,
        'lightning_bolt': 22,
        'sun': 23,
        'moon': 24,
        'smiley_face': 17,
        'no_symbol': 19,
        'flowchart_process': 112,
        'flowchart_decision': 114,
        'flowchart_data': 115,
        'flowchart_document': 119
    }
    
    # Check if shape type is valid before trying to use it
    shape_type_lower = str(shape_type).lower()
    if shape_type_lower not in shape_type_map:
        available_shapes = ', '.join(sorted(shape_type_map.keys()))
        raise ValueError(f"Unsupported shape type: '{shape_type}'. Available shape types: {available_shapes}")
    
    # Get the integer value for the shape type
    shape_value = shape_type_map[shape_type_lower]
    
    # Create the shape using the direct integer value
    try:
        # The integer value is passed directly to add_shape
        shape = slide.shapes.add_shape(
            shape_value, Inches(left), Inches(top), Inches(width), Inches(height)
        )
        return shape
    except Exception as e:
        raise ValueError(f"Failed to create '{shape_type}' shape using direct value {shape_value}: {str(e)}")

# ---- Custom presentation management wrapper ----

class PresentationManager:
    """Wrapper to handle presentation state updates."""
    
    def __init__(self, presentations_dict):
        self.presentations = presentations_dict
    
    def store_presentation(self, pres, pres_id):
        """Store a presentation and set it as current."""
        self.presentations[pres_id] = pres
        set_current_presentation_id(pres_id)
        return pres_id

# ---- Register Tools ----

# Create presentation manager wrapper
presentation_manager = PresentationManager(presentations)

# Wrapper functions to handle state management
def create_presentation_wrapper(original_func):
    """Wrapper to handle presentation creation with state management."""
    def wrapper(*args, **kwargs):
        result = original_func(*args, **kwargs)
        if "presentation_id" in result and result["presentation_id"] in presentations:
            set_current_presentation_id(result["presentation_id"])
        return result
    return wrapper

def open_presentation_wrapper(original_func):
    """Wrapper to handle presentation opening with state management."""
    def wrapper(*args, **kwargs):
        result = original_func(*args, **kwargs)
        if "presentation_id" in result and result["presentation_id"] in presentations:
            set_current_presentation_id(result["presentation_id"])
        return result
    return wrapper

# Register all tool modules
register_presentation_tools(
    app, 
    presentations, 
    get_current_presentation_id, 
    get_template_search_directories
)

register_content_tools(
    app,
    presentations,
    get_current_presentation_id,
    validate_parameters,
    is_positive,
    is_non_negative,
    is_in_range,
    is_valid_rgb
)

register_structural_tools(
    app,
    presentations,
    get_current_presentation_id,
    validate_parameters,
    is_positive,
    is_non_negative,
    is_in_range,
    is_valid_rgb,
    add_shape_direct
)

register_professional_tools(
    app,
    presentations,
    get_current_presentation_id
)

register_template_tools(
    app,
    presentations,
    get_current_presentation_id
)

register_hyperlink_tools(
    app,
    presentations,
    get_current_presentation_id,
    validate_parameters,
    is_positive,
    is_non_negative,
    is_in_range,
    is_valid_rgb
)

register_chart_tools(
    app,
    presentations,
    get_current_presentation_id,
    validate_parameters,
    is_positive,
    is_non_negative,
    is_in_range,
    is_valid_rgb
)


register_connector_tools(
    app,
    presentations,
    get_current_presentation_id,
    validate_parameters,
    is_positive,
    is_non_negative,
    is_in_range,
    is_valid_rgb
)

register_master_tools(
    app,
    presentations,
    get_current_presentation_id,
    validate_parameters,
    is_positive,
    is_non_negative,
    is_in_range,
    is_valid_rgb
)

register_transition_tools(
    app,
    presentations,
    get_current_presentation_id,
    validate_parameters,
    is_positive,
    is_non_negative,
    is_in_range,
    is_valid_rgb
)


# ---- Additional Utility Tools ----

@app.tool()
def list_presentations() -> Dict:
    """List all loaded presentations."""
    return {
        "presentations": [
            {
                "id": pres_id,
                "slide_count": len(pres.slides),
                "is_current": pres_id == current_presentation_id
            }
            for pres_id, pres in presentations.items()
        ],
        "current_presentation_id": current_presentation_id,
        "total_presentations": len(presentations)
    }

@app.tool()
def switch_presentation(presentation_id: str) -> Dict:
    """Switch to a different loaded presentation."""
    if presentation_id not in presentations:
        return {
            "error": f"Presentation '{presentation_id}' not found. Available presentations: {list(presentations.keys())}"
        }
    
    global current_presentation_id
    old_id = current_presentation_id
    current_presentation_id = presentation_id
    
    return {
        "message": f"Switched from presentation '{old_id}' to '{presentation_id}'",
        "previous_presentation_id": old_id,
        "current_presentation_id": current_presentation_id
    }

@app.tool()
def get_server_info() -> Dict:
    """Get information about the MCP server."""
    return {
        "name": "PowerPoint MCP Server - Enhanced Edition with MCP Resources",
        "version": "2.3.0",
        "total_tools": 36,  # Organized into 11 specialized modules + 4 resource tools
        "loaded_presentations": len(presentations),
        "current_presentation": current_presentation_id,
        "features": [
            "Presentation Management (8 tools)",
            "Content Management (6 tools)",
            "Template Operations (7 tools)",
            "Structural Elements (4 tools)",
            "Professional Design (3 tools)",
            "Specialized Features (5 tools)",
            "MCP Resource Management (4 tools)"
        ],
        "improvements": [
            "36 specialized tools organized into 12 focused modules",
            "68+ utility functions across 8 organized utility modules",
            "Enhanced parameter handling and validation",
            "Unified operation interfaces with comprehensive coverage",
            "Advanced template system with auto-generation capabilities",
            "Professional design tools with multiple effects and styling",
            "Specialized features including hyperlinks, connectors, slide masters",
            "Dynamic text sizing and intelligent wrapping",
            "Advanced visual effects and styling",
            "Content-aware optimization and validation",
            "Complete PowerPoint lifecycle management",
            "Modular architecture for better maintainability",
            "MCP Resource-based file delivery system"
        ],
        "new_enhanced_features": [
            "Hyperlink Management - Add, update, remove, and list hyperlinks in text",
            "Advanced Chart Data Updates - Replace chart data with new categories and series",
            "Advanced Text Run Formatting - Apply formatting to specific text runs",
            "Shape Connectors - Add connector lines and arrows between points",
            "Slide Master Management - Access and manage slide masters and layouts",
            "Slide Transitions - Basic transition management (placeholder for future)",
            "MCP Resource File Delivery - Protocol-native file access via resource URIs",
            "MCP Resource Save Method - All files delivered via MCP resource URIs",
            "Automatic Resource Lifecycle Management - TTL-based cleanup and storage management"
        ]
    }

# ---- Resource Handlers ----

@app.resource("presentation://ppt-mcp-server/{presentation_id}/file")
def get_presentation_file(presentation_id: str) -> bytes:
    """Handle presentation file resource requests."""
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        logger.info(f"Resource handler called for presentation_id: {presentation_id}")
        
        # Get resource manager and look up the file path
        resource_manager = get_resource_manager()
        logger.info(f"Resource manager obtained: {resource_manager}")
        
        file_path = resource_manager.get_file_path(presentation_id)
        logger.info(f"File path resolved: {file_path}")
        
        if not file_path:
            logger.error(f"File path is None/empty for presentation_id: {presentation_id}")
            raise FileNotFoundError(f"Presentation resource not found: {presentation_id}")
        
        # Check if file exists and get size
        import os
        if not os.path.exists(file_path):
            logger.error(f"File does not exist at path: {file_path}")
            raise FileNotFoundError(f"File not found at path: {file_path}")
        
        file_size = os.path.getsize(file_path)
        logger.info(f"File exists, size: {file_size} bytes")
        
        # Read and return file content
        with open(file_path, 'rb') as f:
            content = f.read()
            logger.info(f"Successfully read {len(content)} bytes from file")
            logger.info(f"Content type: {type(content)}")
            logger.info(f"Content preview (first 50 bytes): {content[:50]}")
            return content
            
    except Exception as e:
        logger.error(f"Exception in resource handler: {str(e)}")
        raise RuntimeError(f"Failed to retrieve presentation file: {str(e)}")

@app.resource("presentation://ppt-mcp-server/{presentation_id}/metadata")
async def get_presentation_metadata(presentation_id: str) -> str:
    """Handle presentation metadata resource requests."""
    try:
        # Get resource manager and metadata
        resource_manager = get_resource_manager()
        resource_info = resource_manager.get_resource(presentation_id)
        
        if not resource_info:
            raise FileNotFoundError(f"Presentation resource not found: {presentation_id}")
        
        # Return metadata as JSON string
        import json
        metadata = {
            "presentation_id": presentation_id,
            "file_name": resource_info["file_name"],
            "file_size": resource_info["file_size"],
            "created_at": resource_info["created_at"].isoformat(),
            "last_accessed": resource_info["last_accessed"].isoformat(),
            "access_count": resource_info["access_count"],
            "resource_uri": resource_info["resource_uri"],
            "metadata": resource_info["metadata"]
        }
        
        return json.dumps(metadata, indent=2)
            
    except Exception as e:
        raise RuntimeError(f"Failed to retrieve presentation metadata: {str(e)}")

# ---- Additional Resource Tools ----

@app.tool()
def list_presentation_resources() -> Dict:
    """List all presentation resources."""
    try:
        resource_manager = get_resource_manager()
        resources = resource_manager.list_resources()
        storage_info = resource_manager.get_storage_usage()
        
        return {
            "resources": resources,
            "storage_usage": storage_info,
            "total_resources": len(resources)
        }
    except Exception as e:
        return {
            "error": f"Failed to list resources: {str(e)}"
        }

@app.tool()
def get_resource_info(presentation_id: str) -> Dict:
    """Get detailed information about a specific resource."""
    try:
        resource_manager = get_resource_manager()
        resource_info = resource_manager.get_resource(presentation_id)
        
        if not resource_info:
            return {
                "error": f"Resource not found: {presentation_id}"
            }
        
        return {
            "presentation_id": presentation_id,
            "file_name": resource_info["file_name"],
            "file_size": resource_info["file_size"],
            "created_at": resource_info["created_at"].isoformat(),
            "last_accessed": resource_info["last_accessed"].isoformat(),
            "access_count": resource_info["access_count"],
            "resource_uri": resource_info["resource_uri"],
            "metadata": resource_info["metadata"]
        }
    except Exception as e:
        return {
            "error": f"Failed to get resource info: {str(e)}"
        }

@app.tool()
def cleanup_resources(max_age_hours: int = 24) -> Dict:
    """Manually clean up old resources."""
    try:
        resource_manager = get_resource_manager()
        
        # Temporarily set retention policy and cleanup
        original_retention = resource_manager.retention_hours
        resource_manager.retention_hours = max_age_hours
        
        cleaned_count = resource_manager.cleanup_expired_resources()
        
        # Restore original retention policy
        resource_manager.retention_hours = original_retention
        
        return {
            "message": f"Cleaned up {cleaned_count} resources older than {max_age_hours} hours",
            "cleaned_count": cleaned_count
        }
    except Exception as e:
        return {
            "error": f"Failed to cleanup resources: {str(e)}"
        }

# ---- Main Function ----
def main(transport: str = "stdio", port: int = 8000):
    if transport == "http":
        import asyncio
        import logging
        
        # Set logging level from environment
        log_level = os.environ.get('LOG_LEVEL', 'INFO').upper()
        logging.getLogger().setLevel(getattr(logging, log_level, logging.INFO))
        
        # Get host from environment variable, default to localhost
        host = os.environ.get('HTTP_HOST', 'localhost')
        print(f"Starting HTTP server on {host}:{port}...")
        
        # Start the FastMCP server with HTTP transport
        try:
            # FastMCP supports direct host/port binding
            app.run(transport='sse', host=host, port=port)
        except asyncio.exceptions.CancelledError:
            print("Server stopped by user.")
        except KeyboardInterrupt:
            print("Server stopped by user.")
        except Exception as e:
            print(f"Error starting server: {e}")
            import traceback
            traceback.print_exc()

    else:
        # Run the FastMCP server with stdio transport
        app.run(transport='stdio')

if __name__ == "__main__":
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="MCP Server for PowerPoint manipulation using python-pptx")

    parser.add_argument(
        "-t",
        "--transport",
        type=str,
        default="stdio",
        choices=["stdio", "http"],
        help="Transport method for the MCP server (default: stdio)"
    )

    parser.add_argument(
        "-p",
        "--port",
        type=int,
        default=8000,
        help="Port to run the MCP server on (default: 8000)"
    )
    args = parser.parse_args()
    main(args.transport, args.port)