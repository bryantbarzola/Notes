from dataclasses import dataclass
from pathlib import Path

from notenest.notes_folder import NotesFolder


@dataclass
class Match:
    path: Path
    line_number: int
    preview: str


def search_notes(folder: NotesFolder, term: str) -> list[Match]:
    if not term:
        return []
    needle = term.lower()
    matches: list[Match] = []
    for note in folder.list_notes():
        try:
            text = folder.read(note)
        except OSError:
            continue
        for i, line in enumerate(text.splitlines(), start=1):
            if needle in line.lower():
                matches.append(Match(path=note, line_number=i, preview=line.strip()))
    return matches
