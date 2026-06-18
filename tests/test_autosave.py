from pathlib import Path
from notenest.autosave import SaveTracker


def make_tracker():
    saved = {}
    tracker = SaveTracker(lambda p, c: saved.__setitem__(p, c))
    return tracker, saved


def test_mark_dirty_then_flush_saves_latest_content():
    tracker, saved = make_tracker()
    p = Path("/tmp/a.md")
    tracker.mark_dirty(p, "v1")
    tracker.mark_dirty(p, "v2")
    assert tracker.is_dirty(p) is True
    assert tracker.flush(p) is True
    assert saved[p] == "v2"
    assert tracker.is_dirty(p) is False


def test_flush_clean_path_does_nothing():
    tracker, saved = make_tracker()
    p = Path("/tmp/a.md")
    assert tracker.flush(p) is False
    assert saved == {}


def test_flush_all_saves_every_dirty_path():
    tracker, saved = make_tracker()
    a, b = Path("/tmp/a.md"), Path("/tmp/b.md")
    tracker.mark_dirty(a, "1")
    tracker.mark_dirty(b, "2")
    flushed = tracker.flush_all()
    assert set(flushed) == {a, b}
    assert saved == {a: "1", b: "2"}
    assert tracker.dirty_paths() == set()
