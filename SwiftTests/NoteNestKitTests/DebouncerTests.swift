import Testing
import Foundation
@testable import NoteNestKit

@Test func debouncerCoalescesRapidCalls() async {
    let queue = DispatchQueue(label: "debouncer.test")
    let debouncer = Debouncer(interval: 0.05, queue: queue)

    // Use a local box to capture the counter — increment and read both happen on queue.
    final class Counter: @unchecked Sendable {
        var value = 0
    }
    let counter = Counter()

    for _ in 0..<5 {
        debouncer.call {
            counter.value += 1
        }
    }
    // Wait well past the interval for the single coalesced fire.
    try? await Task.sleep(nanoseconds: 300_000_000)

    let finalCount = queue.sync { counter.value }
    #expect(finalCount == 1)
}

@Test func debouncerFlushCancelPreventsFire() async {
    let queue = DispatchQueue(label: "debouncer.test2")
    let debouncer = Debouncer(interval: 0.05, queue: queue)

    final class Counter: @unchecked Sendable {
        var value = 0
    }
    let counter = Counter()

    debouncer.call { counter.value += 1 }
    debouncer.flushCancel()
    try? await Task.sleep(nanoseconds: 200_000_000)

    let finalCount = queue.sync { counter.value }
    #expect(finalCount == 0)
}
