import os
import pytest

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtWidgets import QApplication
from notenest.notes_folder import NotesFolder
from notenest.autosave import SaveTracker
from notenest.editor_tabs import EditorTabs


@pytest.fixture(scope="module")
def app():
    application = QApplication.instance() or QApplication([])
    yield application


def test_open_note_adds_tab_with_content(app, tmp_path):
    note = tmp_path / "a.md"
    note.write_text("hello")
    folder = NotesFolder(tmp_path)
    tracker = SaveTracker(lambda p, c: None)
    tabs = EditorTabs(folder, tracker)
    tabs.open_note(note)
    assert tabs.count() == 1
    assert tabs.current_path() == note
    assert tabs.current_content() == "hello"


def test_open_same_note_twice_focuses_not_duplicates(app, tmp_path):
    note = tmp_path / "a.md"
    note.write_text("hi")
    folder = NotesFolder(tmp_path)
    tracker = SaveTracker(lambda p, c: None)
    tabs = EditorTabs(folder, tracker)
    tabs.open_note(note)
    tabs.open_note(note)
    assert tabs.count() == 1


def test_editing_marks_dirty_and_titles_show_dot(app, tmp_path):
    note = tmp_path / "a.md"
    note.write_text("hi")
    folder = NotesFolder(tmp_path)
    tracker = SaveTracker(lambda p, c: None)
    tabs = EditorTabs(folder, tracker)
    tabs.open_note(note)
    editor = tabs.currentWidget()
    editor.setPlainText("changed")
    assert tracker.is_dirty(note) is True
    assert tabs.tabText(0).endswith("•")
    tabs.mark_tab_saved(note)
    assert not tabs.tabText(0).endswith("•")
