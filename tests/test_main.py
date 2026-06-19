import os
import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtWidgets import QApplication
from notenest.notes_folder import NotesFolder
from notenest.main import MainWindow


@pytest.fixture(scope="module")
def app():
    application = QApplication.instance() or QApplication([])
    yield application


def test_refresh_sidebar_lists_notes(app, tmp_path):
    (tmp_path / "a.md").write_text("x")
    (tmp_path / "b.txt").write_text("y")
    window = MainWindow(NotesFolder(tmp_path))
    window.refresh_sidebar()
    assert window.sidebar.count() == 2


def test_new_note_creates_and_opens(app, tmp_path):
    window = MainWindow(NotesFolder(tmp_path))
    window.new_note()
    assert (tmp_path / "untitled.md").exists()
    assert window.tabs.count() == 1


def test_save_current_writes_and_clears_dirty(app, tmp_path):
    note = tmp_path / "a.md"
    note.write_text("orig")
    folder = NotesFolder(tmp_path)
    window = MainWindow(folder)
    window.tabs.open_note(note)
    window.tabs.currentWidget().setPlainText("edited")
    window.save_current()
    assert note.read_text() == "edited"
    assert window.tracker.is_dirty(note) is False


def test_run_search_returns_matches(app, tmp_path):
    (tmp_path / "a.md").write_text("find me here")
    window = MainWindow(NotesFolder(tmp_path))
    results = window.run_search("find")
    assert len(results) == 1


def test_search_result_click_jumps_to_line(app, tmp_path):
    note = tmp_path / "match.md"
    note.write_text("line 1\nfind this\nline 3")
    window = MainWindow(NotesFolder(tmp_path))
    window.search_box.setText("find")
    window._on_search_enter()
    assert window.search_results.count() == 1
    # Simulate clicking the first result
    item = window.search_results.item(0)
    window._on_result_click(item)
    # Should open the tab and jump to line 2
    assert window.tabs.current_path() == note
    editor = window.tabs.currentWidget()
    assert editor.textCursor().blockNumber() == 1  # 0-based: line 2 is block 1


def test_save_on_quit_persists_changes(app, tmp_path):
    note = tmp_path / "quit.md"
    note.write_text("original")
    window = MainWindow(NotesFolder(tmp_path))
    window.tabs.open_note(note)
    window.tabs.currentWidget().setPlainText("edited on close")
    window.close()
    assert note.read_text() == "edited on close"


def test_open_initial_note_creates_note_when_empty(app, tmp_path):
    window = MainWindow(NotesFolder(tmp_path))
    assert window.tabs.count() == 1
    assert (tmp_path / "untitled.md").exists()


def test_open_initial_note_opens_existing_first_note(app, tmp_path):
    (tmp_path / "a.md").write_text("first")
    (tmp_path / "b.md").write_text("second")
    window = MainWindow(NotesFolder(tmp_path))
    assert window.tabs.count() == 1
    assert window.tabs.current_path().name == "a.md"
