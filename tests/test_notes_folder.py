from pathlib import Path
from notenest.notes_folder import NotesFolder


def test_ensure_exists_creates_folder(tmp_path):
    folder = NotesFolder(tmp_path / "Notes")
    folder.ensure_exists()
    assert (tmp_path / "Notes").is_dir()


def test_list_notes_only_txt_and_md_sorted(tmp_path):
    (tmp_path / "b.md").write_text("b")
    (tmp_path / "a.txt").write_text("a")
    (tmp_path / "ignore.png").write_text("x")
    folder = NotesFolder(tmp_path)
    names = [p.name for p in folder.list_notes()]
    assert names == ["a.txt", "b.md"]


def test_read_and_write_roundtrip(tmp_path):
    folder = NotesFolder(tmp_path)
    target = tmp_path / "note.md"
    folder.write(target, "hello")
    assert folder.read(target) == "hello"


def test_create_note_appends_md_and_is_empty(tmp_path):
    folder = NotesFolder(tmp_path)
    p = folder.create_note("ideas")
    assert p.name == "ideas.md"
    assert p.read_text() == ""


def test_create_note_keeps_existing_extension(tmp_path):
    folder = NotesFolder(tmp_path)
    p = folder.create_note("log.txt")
    assert p.name == "log.txt"


def test_create_note_returns_existing_without_clobber(tmp_path):
    folder = NotesFolder(tmp_path)
    (tmp_path / "keep.md").write_text("original")
    p = folder.create_note("keep")
    assert p.read_text() == "original"


def test_list_notes_case_insensitive_extensions(tmp_path):
    (tmp_path / "upper.MD").write_text("a")
    (tmp_path / "mixed.TxT").write_text("b")
    (tmp_path / "lower.md").write_text("c")
    folder = NotesFolder(tmp_path)
    names = [p.name for p in folder.list_notes()]
    assert sorted(names) == ["lower.md", "mixed.TxT", "upper.MD"]
