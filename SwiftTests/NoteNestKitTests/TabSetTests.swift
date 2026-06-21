import Testing
@testable import NoteNestKit

@Test func openAppendsInOrder() {
    var t = TabSet()
    t.open("a"); t.open("b"); t.open("c")
    #expect(t.ids == ["a", "b", "c"])
}

@Test func openIsIdempotentNoDuplicates() {
    var t = TabSet()
    t.open("a"); t.open("a")
    #expect(t.ids == ["a"])
    #expect(t.contains("a"))
}

@Test func closeActiveActivatesLastRemaining() {
    var t = TabSet(ids: ["a", "b", "c"])
    // closing the active "b" → last remaining is "c"
    let next = t.close("b", active: "b")
    #expect(t.ids == ["a", "c"])
    #expect(next == "c")
}

@Test func closeActiveWhenLastRemovedActivatesNewLast() {
    var t = TabSet(ids: ["a", "b"])
    let next = t.close("b", active: "b")
    #expect(t.ids == ["a"])
    #expect(next == "a")
}

@Test func closeOnlyTabReturnsNil() {
    var t = TabSet(ids: ["a"])
    let next = t.close("a", active: "a")
    #expect(t.ids.isEmpty)
    #expect(next == nil)
}

@Test func closeNonActiveLeavesActiveUnchanged() {
    var t = TabSet(ids: ["a", "b", "c"])
    let next = t.close("a", active: "c")
    #expect(t.ids == ["b", "c"])
    #expect(next == "c")
}

@Test func clearEmptiesTheSet() {
    var t = TabSet(ids: ["a", "b"])
    t.clear()
    #expect(t.ids.isEmpty)
}

@Test func closeIdNotInSetLeavesIdsUnchanged() {
    var t = TabSet(ids: ["a", "b"])
    let next = t.close("zzz", active: "a")
    #expect(t.ids == ["a", "b"])   // nothing removed
    #expect(next == "a")            // active unchanged
}
