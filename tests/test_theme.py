from notenest import theme


def test_colors_are_hex_strings():
    for color in (theme.BACKGROUND, theme.FOREGROUND, theme.ACCENT):
        assert isinstance(color, str)
        assert color.startswith("#")
        assert len(color) == 7


def test_stylesheet_includes_background_color():
    css = theme.stylesheet()
    assert theme.BACKGROUND in css
    assert isinstance(css, str)
