import sys
from pathlib import Path

from PySide6.QtCore import QTimer, Qt
from PySide6.QtGui import QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QListWidget, QListWidgetItem,
    QHBoxLayout, QLineEdit, QVBoxLayout,
)

from notenest.notes_folder import NotesFolder
from notenest.autosave import SaveTracker
from notenest.editor_tabs import EditorTabs
from notenest import search, theme

AUTOSAVE_MS = 1500


class MainWindow(QMainWindow):
    def __init__(self, folder: NotesFolder):
        super().__init__()
        self.setWindowTitle("NoteNest")
        self.folder = folder
        self.tracker = SaveTracker(self.folder.write)

        self.sidebar = QListWidget()
        self.sidebar.itemClicked.connect(self._on_sidebar_click)

        self.tabs = EditorTabs(self.folder, self.tracker)

        self.search_box = QLineEdit()
        self.search_box.setPlaceholderText("Search all notes…")
        self.search_box.hide()
        self.search_box.returnPressed.connect(self._on_search_enter)
        self.search_results = QListWidget()
        self.search_results.hide()
        self.search_results.itemClicked.connect(self._on_result_click)

        left = QWidget()
        left_layout = QVBoxLayout(left)
        left_layout.setContentsMargins(0, 0, 0, 0)
        left_layout.addWidget(self.sidebar)
        left_layout.addWidget(self.search_box)
        left_layout.addWidget(self.search_results)

        central = QWidget()
        layout = QHBoxLayout(central)
        layout.addWidget(left, 1)
        layout.addWidget(self.tabs, 3)
        self.setCentralWidget(central)

        self.status = self.statusBar()
        self._update_status("Ready")

        self._timer = QTimer(self)
        self._timer.setInterval(AUTOSAVE_MS)
        self._timer.timeout.connect(self._autosave_tick)
        self._timer.start()

        QShortcut(QKeySequence("Ctrl+S"), self, self.save_current)
        QShortcut(QKeySequence("Meta+S"), self, self.save_current)
        QShortcut(QKeySequence("Ctrl+N"), self, self.new_note)
        QShortcut(QKeySequence("Meta+N"), self, self.new_note)
        QShortcut(QKeySequence("Ctrl+Shift+F"), self, self._toggle_search)
        QShortcut(QKeySequence("Meta+Shift+F"), self, self._toggle_search)

        self.refresh_sidebar()

    def _update_status(self, text: str) -> None:
        self.status.showMessage(f"{self.folder.path} · {text}")

    def refresh_sidebar(self) -> None:
        self.sidebar.clear()
        for note in self.folder.list_notes():
            item = QListWidgetItem(note.name)
            item.setData(Qt.UserRole, str(note))
            self.sidebar.addItem(item)

    def _on_sidebar_click(self, item: QListWidgetItem) -> None:
        self.tabs.open_note(Path(item.data(Qt.UserRole)))

    def save_current(self) -> None:
        path = self.tabs.current_path()
        if path is None:
            return
        content = self.tabs.current_content()
        self.tracker.mark_dirty(path, content)
        if self.tracker.flush(path):
            self.tabs.mark_tab_saved(path)
            self._update_status("Saved ✓")

    def new_note(self) -> None:
        path = self.folder.create_note("untitled")
        self.refresh_sidebar()
        self.tabs.open_note(path)

    def _autosave_tick(self) -> None:
        saved = self.tracker.flush_all()
        for path in saved:
            self.tabs.mark_tab_saved(path)
        if saved:
            self._update_status("Saved ✓")

    def _toggle_search(self) -> None:
        visible = not self.search_box.isVisible()
        self.search_box.setVisible(visible)
        self.search_results.setVisible(visible)
        if visible:
            self.search_box.setFocus()

    def run_search(self, term: str):
        return search.search_notes(self.folder, term)

    def _on_search_enter(self) -> None:
        self.search_results.clear()
        for m in self.run_search(self.search_box.text()):
            item = QListWidgetItem(f"{m.path.name}:{m.line_number}  {m.preview}")
            item.setData(Qt.UserRole, str(m.path))
            self.search_results.addItem(item)

    def _on_result_click(self, item: QListWidgetItem) -> None:
        self.tabs.open_note(Path(item.data(Qt.UserRole)))

    def closeEvent(self, event) -> None:
        self.tracker.flush_all()
        super().closeEvent(event)


def main() -> int:
    app = QApplication(sys.argv)
    app.setStyleSheet(theme.stylesheet())
    folder = NotesFolder(NotesFolder.default_path())
    folder.ensure_exists()
    window = MainWindow(folder)
    window.resize(900, 600)
    window.show()
    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
