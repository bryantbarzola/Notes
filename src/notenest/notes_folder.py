from pathlib import Path

NOTE_EXTENSIONS = {".txt", ".md"}


class NotesFolder:
    def __init__(self, path: Path):
        self.path = Path(path)

    @staticmethod
    def default_path() -> Path:
        return Path.home() / "Notes"

    def ensure_exists(self) -> None:
        self.path.mkdir(parents=True, exist_ok=True)

    def list_notes(self) -> list[Path]:
        if not self.path.is_dir():
            return []
        notes = [
            p for p in self.path.iterdir()
            if p.is_file() and p.suffix.lower() in NOTE_EXTENSIONS
        ]
        return sorted(notes, key=lambda p: p.name)

    def read(self, path: Path) -> str:
        return Path(path).read_text(encoding="utf-8")

    def write(self, path: Path, content: str) -> None:
        Path(path).write_text(content, encoding="utf-8")

    def create_note(self, name: str) -> Path:
        if Path(name).suffix.lower() not in NOTE_EXTENSIONS:
            name = name + ".md"
        target = self.path / name
        if not target.exists():
            target.write_text("", encoding="utf-8")
        return target
