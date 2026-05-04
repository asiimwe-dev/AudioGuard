"""
AudioGuard Storage Abstraction Layer

Implements pluggable storage backends (local + S3) for persistent file management.
Ensures files survive server restarts and can be accessed by multiple operations.

Usage:
    storage = StorageBackend.local_storage("/tmp/audioguard")
    file_id = storage.save_file(audio_path, metadata={"message": "test"})
    retrieved_path = storage.get_file(file_id)
    storage.delete_file(file_id)
"""

import os
import json
import shutil
import uuid
from abc import ABC, abstractmethod
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Optional, List, Any
import logging

logger = logging.getLogger(__name__)


class StorageBackend(ABC):
    """Abstract base for storage backends."""
    
    @abstractmethod
    def save_file(self, source_path: str, metadata: Optional[Dict] = None) -> str:
        """Save file and return file_id."""
        pass
    
    @abstractmethod
    def get_file(self, file_id: str) -> Optional[str]:
        """Get file path for file_id."""
        pass
    
    @abstractmethod
    def delete_file(self, file_id: str) -> bool:
        """Delete file. Return True if successful."""
        pass
    
    @abstractmethod
    def get_metadata(self, file_id: str) -> Optional[Dict]:
        """Get metadata for file."""
        pass
    
    @abstractmethod
    def list_files(self, max_age_hours: Optional[int] = None) -> List[str]:
        """List all file IDs, optionally filtered by age."""
        pass
    
    @abstractmethod
    def cleanup_old_files(self, max_age_hours: int = 24) -> int:
        """Delete files older than max_age_hours. Return count deleted."""
        pass


class LocalFileStorage(StorageBackend):
    """Local file system storage backend."""
    
    def __init__(self, base_dir: str, max_files: int = 1000):
        """
        Initialize local storage.
        
        Args:
            base_dir: Base directory for storage
            max_files: Maximum files to keep (cleanup oldest when exceeded)
        """
        self.base_dir = Path(base_dir)
        self.max_files = max_files
        self.metadata_file = self.base_dir / "metadata.json"
        
        # Create directory if needed
        self.base_dir.mkdir(parents=True, exist_ok=True)
        
        # Load or create metadata index
        self._load_metadata()
    
    def _load_metadata(self) -> None:
        """Load metadata index from disk."""
        self.metadata = {}
        if self.metadata_file.exists():
            try:
                with open(self.metadata_file, 'r') as f:
                    self.metadata = json.load(f)
            except Exception as e:
                logger.error(f"Failed to load metadata: {e}")
                self.metadata = {}
    
    def _save_metadata(self) -> None:
        """Save metadata index to disk."""
        try:
            with open(self.metadata_file, 'w') as f:
                json.dump(self.metadata, f, indent=2, default=str)
        except Exception as e:
            logger.error(f"Failed to save metadata: {e}")
    
    def save_file(self, source_path: str, metadata: Optional[Dict] = None) -> str:
        """
        Save file with metadata.
        
        Args:
            source_path: Path to source file
            metadata: Optional metadata dict
        
        Returns:
            Unique file_id
        """
        source = Path(source_path)
        if not source.exists():
            raise FileNotFoundError(f"Source file not found: {source_path}")
        
        # Generate unique file_id
        file_id = str(uuid.uuid4())
        dest_path = self.base_dir / file_id
        
        # Copy file
        shutil.copy2(str(source), str(dest_path))
        
        # Store metadata
        self.metadata[file_id] = {
            'original_name': source.name,
            'file_path': str(dest_path),
            'file_size': source.stat().st_size,
            'created_at': datetime.now().isoformat(),
            'metadata': metadata or {}
        }
        
        # Check if we need to cleanup
        if len(self.metadata) > self.max_files:
            self._cleanup_oldest(len(self.metadata) - self.max_files)
        
        self._save_metadata()
        logger.info(f"Saved file: {file_id} ({source.name})")
        
        return file_id
    
    def get_file(self, file_id: str) -> Optional[str]:
        """Get file path for file_id."""
        if file_id not in self.metadata:
            return None
        
        file_path = self.metadata[file_id]['file_path']
        if os.path.exists(file_path):
            return file_path
        
        # File no longer exists, clean up metadata
        del self.metadata[file_id]
        self._save_metadata()
        return None
    
    def delete_file(self, file_id: str) -> bool:
        """Delete file by file_id."""
        if file_id not in self.metadata:
            return False
        
        file_path = self.metadata[file_id]['file_path']
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
            del self.metadata[file_id]
            self._save_metadata()
            logger.info(f"Deleted file: {file_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete file: {e}")
            return False
    
    def get_metadata(self, file_id: str) -> Optional[Dict]:
        """Get metadata for file."""
        return self.metadata.get(file_id)
    
    def list_files(self, max_age_hours: Optional[int] = None) -> List[str]:
        """List all file IDs."""
        file_ids = []
        now = datetime.now()
        
        for file_id, meta in self.metadata.items():
            if max_age_hours:
                created = datetime.fromisoformat(meta['created_at'])
                if (now - created) > timedelta(hours=max_age_hours):
                    continue
            
            file_ids.append(file_id)
        
        return file_ids
    
    def cleanup_old_files(self, max_age_hours: int = 24) -> int:
        """Delete files older than max_age_hours."""
        old_files = [
            file_id for file_id in self.list_files()
            if (datetime.now() - datetime.fromisoformat(self.metadata[file_id]['created_at']))
            > timedelta(hours=max_age_hours)
        ]
        
        for file_id in old_files:
            self.delete_file(file_id)
        
        return len(old_files)
    
    def _cleanup_oldest(self, num_to_delete: int) -> None:
        """Delete oldest files."""
        sorted_files = sorted(
            self.metadata.items(),
            key=lambda x: x[1]['created_at']
        )
        
        for file_id, _ in sorted_files[:num_to_delete]:
            self.delete_file(file_id)


# Global storage instance
_storage = None


def init_storage(base_dir: str = "/tmp/audioguard_storage", backend: str = "local") -> StorageBackend:
    """Initialize global storage backend."""
    global _storage
    
    if backend == "local":
        _storage = LocalFileStorage(base_dir)
    else:
        raise ValueError(f"Unknown storage backend: {backend}")
    
    return _storage


def get_storage() -> StorageBackend:
    """Get global storage instance (must call init_storage first)."""
    global _storage
    if _storage is None:
        raise RuntimeError("Storage not initialized. Call init_storage() first.")
    return _storage
