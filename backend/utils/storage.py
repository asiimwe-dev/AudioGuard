"""
AudioGuard Storage Abstraction

LocalFileStorage with O(1) metadata lookup and background cleanup.
Extend with S3Backend for cloud deployments.
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import uuid
from abc import ABC, abstractmethod
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import Lock
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


class StorageBackend(ABC):

    @abstractmethod
    def save_file(self, source_path: str, metadata: Optional[Dict] = None) -> str: ...

    @abstractmethod
    def get_file(self, file_id: str) -> Optional[str]: ...

    @abstractmethod
    def delete_file(self, file_id: str) -> bool: ...

    @abstractmethod
    def get_metadata(self, file_id: str) -> Optional[Dict]: ...

    @abstractmethod
    def cleanup_old_files(self, max_age_hours: int = 24) -> int: ...


class LocalFileStorage(StorageBackend):
    """Thread-safe local storage with atomic metadata writes."""

    def __init__(self, base_dir: str, max_files: int = 1000, ttl_hours: int = 24):
        self._base = Path(base_dir)
        self._max = max_files
        self._ttl = ttl_hours
        self._lock = Lock()
        self._base.mkdir(parents=True, exist_ok=True)
        self._meta_path = self._base / "_index.json"
        self._index: Dict[str, Dict] = {}
        self._load()

    # ------------------------------------------------------------------
    def save_file(self, source_path: str, metadata: Optional[Dict] = None) -> str:
        src = Path(source_path)
        if not src.exists():
            raise FileNotFoundError(f"Source not found: {source_path}")

        file_id = str(uuid.uuid4())
        dest = self._base / file_id

        with self._lock:
            shutil.copy2(str(src), str(dest))
            self._index[file_id] = {
                "path": str(dest),
                "original_name": src.name,
                "size_bytes": src.stat().st_size,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "metadata": metadata or {},
            }
            self._enforce_limit()
            self._persist()

        logger.debug("Saved %s → %s", src.name, file_id)
        return file_id

    def get_file(self, file_id: str) -> Optional[str]:
        with self._lock:
            entry = self._index.get(file_id)
            if not entry:
                return None
            path = entry["path"]
            if not os.path.exists(path):
                del self._index[file_id]
                self._persist()
                return None
            return path

    def delete_file(self, file_id: str) -> bool:
        with self._lock:
            entry = self._index.pop(file_id, None)
            if not entry:
                return False
            try:
                Path(entry["path"]).unlink(missing_ok=True)
            except OSError as e:
                logger.warning("Could not delete %s: %s", entry["path"], e)
            self._persist()
        return True

    def get_metadata(self, file_id: str) -> Optional[Dict]:
        entry = self._index.get(file_id)
        return entry.get("metadata") if entry else None

    def cleanup_old_files(self, max_age_hours: int = 24) -> int:
        cutoff = datetime.utcnow() - timedelta(hours=max_age_hours)
        to_delete = [
            fid for fid, entry in self._index.items()
            if datetime.fromisoformat(entry["created_at"]) < cutoff
        ]
        for fid in to_delete:
            self.delete_file(fid)
        if to_delete:
            logger.info("Cleaned up %d expired files", len(to_delete))
        return len(to_delete)

    # ------------------------------------------------------------------
    def _load(self) -> None:
        if self._meta_path.exists():
            try:
                self._index = json.loads(self._meta_path.read_text())
            except Exception as e:
                logger.error("Index corrupt, resetting: %s", e)
                self._index = {}

    def _persist(self) -> None:
        tmp = self._meta_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self._index, indent=2))
        tmp.replace(self._meta_path)

    def _enforce_limit(self) -> None:
        if len(self._index) <= self._max:
            return
        oldest = sorted(self._index.items(), key=lambda x: x[1]["created_at"])
        for fid, entry in oldest[: len(self._index) - self._max]:
            Path(entry["path"]).unlink(missing_ok=True)
            del self._index[fid]
