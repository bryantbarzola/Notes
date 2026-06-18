from pathlib import Path
from typing import Callable


class SaveTracker:
    def __init__(self, save_fn: Callable[[Path, str], None]):
        self._save_fn = save_fn
        self._dirty: dict[Path, str] = {}

    def mark_dirty(self, path: Path, content: str) -> None:
        self._dirty[path] = content

    def is_dirty(self, path: Path) -> bool:
        return path in self._dirty

    def dirty_paths(self) -> set[Path]:
        return set(self._dirty.keys())

    def flush(self, path: Path) -> bool:
        if path not in self._dirty:
            return False
        self._save_fn(path, self._dirty.pop(path))
        return True

    def flush_all(self) -> list[Path]:
        paths = list(self._dirty.keys())
        for p in paths:
            self.flush(p)
        return paths
