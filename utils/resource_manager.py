"""
Resource management utilities for MCP Resource-based file delivery.
Handles resource registration, retrieval, and lifecycle management.
"""
import os
import threading
import time
from datetime import datetime, timedelta
from typing import Dict, Optional, List, Any
from pathlib import Path
import logging

logger = logging.getLogger(__name__)


class ResourceManager:
    """
    Manages MCP resources for presentation files.
    
    Handles registration, retrieval, and lifecycle management of presentation
    resources with automatic cleanup and configurable retention policies.
    """
    
    def __init__(self, 
                 retention_hours: int = 24,
                 max_storage_mb: int = 1000,
                 cleanup_interval: int = 3600,
                 base_path: str = "/app/resources"):
        """
        Initialize the ResourceManager.
        
        Args:
            retention_hours: How long to keep resources (default: 24 hours)
            max_storage_mb: Maximum storage for resources in MB (default: 1000MB)
            cleanup_interval: Cleanup check interval in seconds (default: 1 hour)
            base_path: Base path for storing resource files (default: /app/resources)
        """
        self.retention_hours = retention_hours
        self.max_storage_mb = max_storage_mb
        self.cleanup_interval = cleanup_interval
        self.base_path = Path(base_path)
        
        # Thread-safe resource registry
        self._resources: Dict[str, Dict[str, Any]] = {}
        self._lock = threading.Lock()
        
        # Ensure base path exists
        self.base_path.mkdir(parents=True, exist_ok=True)
        
        # Start cleanup thread
        self._cleanup_thread = None
        self._stop_cleanup = threading.Event()
        self._start_cleanup_thread()
    
    def _start_cleanup_thread(self):
        """Start the background cleanup thread."""
        if self._cleanup_thread is None or not self._cleanup_thread.is_alive():
            self._cleanup_thread = threading.Thread(
                target=self._cleanup_worker,
                daemon=True,
                name="ResourceCleanup"
            )
            self._cleanup_thread.start()
            logger.info("Resource cleanup thread started")
    
    def _cleanup_worker(self):
        """Background worker for resource cleanup."""
        while not self._stop_cleanup.wait(self.cleanup_interval):
            try:
                self.cleanup_expired_resources()
            except Exception as e:
                logger.error(f"Error in resource cleanup: {e}")
    
    def register(self, presentation_id: str, file_path: str, 
                 metadata: Optional[Dict] = None, 
                 server_name: str = "ppt-mcp-server") -> str:
        """
        Register a new presentation resource.
        
        Args:
            presentation_id: Unique identifier for the presentation
            file_path: Path to the presentation file
            metadata: Optional metadata about the resource
            server_name: Name of the MCP server (for URI generation)
            
        Returns:
            Resource URI for accessing the file
        """
        with self._lock:
            # Generate resource URI
            resource_uri = f"presentation://{server_name}/{presentation_id}/file"
            
            # Get file info
            file_info = self._get_file_info(file_path)
            
            # Store resource info
            self._resources[presentation_id] = {
                "file_path": file_path,
                "created_at": datetime.utcnow(),
                "last_accessed": datetime.utcnow(),
                "access_count": 0,
                "resource_uri": resource_uri,
                "file_size": file_info["size"],
                "file_name": file_info["name"],
                "metadata": metadata or {}
            }
            
            logger.info(f"Registered resource: {resource_uri}")
            return resource_uri
    
    def get_resource(self, presentation_id: str) -> Optional[Dict]:
        """
        Get resource information by presentation ID.
        
        Args:
            presentation_id: The presentation ID
            
        Returns:
            Resource information dictionary or None if not found
        """
        with self._lock:
            if presentation_id in self._resources:
                # Update access info
                resource = self._resources[presentation_id]
                resource["last_accessed"] = datetime.utcnow()
                resource["access_count"] += 1
                
                return resource.copy()
            return None
    
    def get_file_path(self, presentation_id: str) -> Optional[str]:
        """
        Get the file path for a presentation resource.
        
        Args:
            presentation_id: The presentation ID
            
        Returns:
            File path or None if not found
        """
        resource = self.get_resource(presentation_id)
        if resource and os.path.exists(resource["file_path"]):
            return resource["file_path"]
        return None
    
    def list_resources(self) -> List[Dict]:
        """
        List all registered resources.
        
        Returns:
            List of resource information dictionaries
        """
        with self._lock:
            return [
                {
                    "presentation_id": pres_id,
                    "resource_uri": info["resource_uri"],
                    "file_name": info["file_name"],
                    "file_size": info["file_size"],
                    "created_at": info["created_at"].isoformat(),
                    "last_accessed": info["last_accessed"].isoformat(),
                    "access_count": info["access_count"]
                }
                for pres_id, info in self._resources.items()
            ]
    
    def remove_resource(self, presentation_id: str) -> bool:
        """
        Remove a resource from the registry.
        
        Args:
            presentation_id: The presentation ID to remove
            
        Returns:
            True if resource was removed, False if not found
        """
        with self._lock:
            if presentation_id in self._resources:
                resource = self._resources.pop(presentation_id)
                logger.info(f"Removed resource: {resource['resource_uri']}")
                return True
            return False
    
    def cleanup_expired_resources(self) -> int:
        """
        Clean up expired resources based on retention policy.
        
        Returns:
            Number of resources cleaned up
        """
        if self.retention_hours <= 0:
            return 0
            
        cutoff_time = datetime.utcnow() - timedelta(hours=self.retention_hours)
        cleaned_count = 0
        
        with self._lock:
            expired_ids = []
            for pres_id, resource in self._resources.items():
                if resource["created_at"] < cutoff_time:
                    expired_ids.append(pres_id)
            
            for pres_id in expired_ids:
                self._resources.pop(pres_id, None)
                cleaned_count += 1
        
        if cleaned_count > 0:
            logger.info(f"Cleaned up {cleaned_count} expired resources")
        
        return cleaned_count
    
    def get_storage_usage(self) -> Dict[str, Any]:
        """
        Get current storage usage statistics.
        
        Returns:
            Dictionary with storage usage information
        """
        with self._lock:
            total_size = sum(info["file_size"] for info in self._resources.values())
            total_count = len(self._resources)
            
            return {
                "total_resources": total_count,
                "total_size_bytes": total_size,
                "total_size_mb": total_size / (1024 * 1024),
                "max_storage_mb": self.max_storage_mb,
                "usage_percentage": (total_size / (1024 * 1024)) / self.max_storage_mb * 100
            }
    
    def _get_file_info(self, file_path: str) -> Dict[str, Any]:
        """
        Get file information.
        
        Args:
            file_path: Path to the file
            
        Returns:
            Dictionary with file information
        """
        try:
            stat = os.stat(file_path)
            return {
                "name": os.path.basename(file_path),
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime)
            }
        except OSError as e:
            logger.error(f"Error getting file info for {file_path}: {e}")
            return {
                "name": os.path.basename(file_path),
                "size": 0,
                "modified": datetime.utcnow()
            }
    
    def shutdown(self):
        """Shutdown the resource manager and cleanup thread."""
        self._stop_cleanup.set()
        if self._cleanup_thread and self._cleanup_thread.is_alive():
            self._cleanup_thread.join(timeout=5)
        logger.info("Resource manager shutdown complete")


# Global resource manager instance
_resource_manager: Optional[ResourceManager] = None


def get_resource_manager() -> ResourceManager:
    """
    Get the global resource manager instance.
    
    Returns:
        ResourceManager instance
    """
    global _resource_manager
    if _resource_manager is None:
        # Initialize with environment variables
        retention_hours = int(os.environ.get('RESOURCE_RETENTION_HOURS', '24'))
        max_storage_mb = int(os.environ.get('RESOURCE_MAX_STORAGE_MB', '1000'))
        cleanup_interval = int(os.environ.get('RESOURCE_CLEANUP_INTERVAL', '3600'))
        base_path = os.environ.get('RESOURCE_BASE_PATH', '/app/resources')
        
        _resource_manager = ResourceManager(
            retention_hours=retention_hours,
            max_storage_mb=max_storage_mb,
            cleanup_interval=cleanup_interval,
            base_path=base_path
        )
    
    return _resource_manager


def shutdown_resource_manager():
    """Shutdown the global resource manager."""
    global _resource_manager
    if _resource_manager:
        _resource_manager.shutdown()
        _resource_manager = None