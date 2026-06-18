from pathlib import Path

from PySide6.QtWidgets import QTabWidget, QPlainTextEdit

from notenest.notes_folder import NotesFolder
from notenest.autosave import SaveTracker


class EditorTabs(QTabWidget):
    def __init__(self, folder: NotesFolder, tracker: SaveTracker, parent=None):
        super().__init__(parent)
        self._folder = folder
        self._tracker = tracker
        self.setTabsClosable(True)
        self.setMovable(True)
        self.tabCloseRequested.connect(self._close_tab)

    def _index_for_path(self, path: Path) -> int:
        for i in range(self.count()):
            if self.path_at(i) == path:
                return i
        return -1

    def path_at(self, index: int):
        widget = self.widget(index)
        return widget.property("note_path") if widget else None

    def open_note(self, path: Path) -> None:
        existing = self._index_for_path(path)
        if existing != -1:
            self.setCurrentIndex(existing)
            return
        editor = QPlainTextEdit()
        editor.setPlainText(self._folder.read(path))
        editor.setProperty("note_path", path)
        index = self.addTab(editor, path.name)
        editor.textChanged.connect(lambda e=editor: self._on_changed(e))
        self.setCurrentIndex(index)

    def _on_changed(self, editor) -> None:
        path = editor.property("note_path")
        self._tracker.mark_dirty(path, editor.toPlainText())
        index = self.indexOf(editor)
        if index != -1 and not self.tabText(index).endswith("•"):
            self.setTabText(index, f"{path.name} •")

    def mark_tab_saved(self, path: Path) -> None:
        index = self._index_for_path(path)
        if index != -1:
            self.setTabText(index, path.name)

    def current_path(self):
        widget = self.currentWidget()
        return widget.property("note_path") if widget else None

    def current_content(self):
        widget = self.currentWidget()
        return widget.toPlainText() if widget else None

    def _close_tab(self, index: int) -> None:
        self.removeTab(index)
