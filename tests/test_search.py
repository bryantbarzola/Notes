from notenest.notes_folder import NotesFolder
from notenest.search import search_notes, Match


def test_empty_term_returns_nothing(tmp_path):
    (tmp_path / "a.md").write_text("hello world")
    folder = NotesFolder(tmp_path)
    assert search_notes(folder, "") == []


def test_finds_case_insensitive_with_line_number(tmp_path):
    (tmp_path / "a.md").write_text("first line\nHello There\nlast")
    folder = NotesFolder(tmp_path)
    results = search_notes(folder, "hello")
    assert len(results) == 1
    assert results[0].line_number == 2
    assert results[0].preview == "Hello There"
    assert results[0].path.name == "a.md"


def test_multiple_matches_across_files(tmp_path):
    (tmp_path / "a.md").write_text("todo: x\nnope")
    (tmp_path / "b.txt").write_text("another todo here")
    folder = NotesFolder(tmp_path)
    results = search_notes(folder, "todo")
    assert len(results) == 2


def test_no_match_returns_empty(tmp_path):
    (tmp_path / "a.md").write_text("nothing here")
    folder = NotesFolder(tmp_path)
    assert search_notes(folder, "zzz") == []
