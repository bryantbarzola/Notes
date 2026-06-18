BACKGROUND = "#1e1e1e"
FOREGROUND = "#d4d4d4"
ACCENT = "#264f78"
FONT_FAMILY = "Menlo"
FONT_SIZE = 14


def stylesheet() -> str:
    return f"""
    QWidget {{
        background-color: {BACKGROUND};
        color: {FOREGROUND};
        font-family: {FONT_FAMILY};
        font-size: {FONT_SIZE}px;
    }}
    QPlainTextEdit, QListWidget {{
        background-color: {BACKGROUND};
        color: {FOREGROUND};
        border: none;
    }}
    QTabBar::tab {{
        background: {BACKGROUND};
        color: {FOREGROUND};
        padding: 6px 12px;
    }}
    QTabBar::tab:selected {{
        background: {ACCENT};
    }}
    QLineEdit {{
        background-color: {BACKGROUND};
        color: {FOREGROUND};
        border: 1px solid {ACCENT};
        padding: 4px;
    }}
    """
