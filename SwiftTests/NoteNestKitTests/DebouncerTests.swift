import Testing
import Foundation
@testable import NoteNestKit

@Test func debouncerCoalescesRapidCalls() async {
    let queue = DispatchQueue(label: "debouncer.test")
    let debouncer = Debouncer(interval: 0.05, queue: queue)
    nonisolated(unsafe) var count = 0

    for _ in 0..<5 {
        debouncer.call {
            count += 1
        }
    }
    // Wait well past the interval for the single coalesced fire.
    try? await Task.sleep(nanoseconds: 300_000_000)

    #expect(count == 1)
}

@Test func debouncerFlushCancelPreventsFire() async {
    let queue = DispatchQueue(label: "debouncer.test2")
    let debouncer = Debouncer(interval: 0.05, queue: queue)
    nonisolated(unsafe) var count = 0

    debouncer.call { count += 1 }
    debouncer.flushCancel()
    try? await Task.sleep(nanoseconds: 200_000_000)

    #expect(count == 0)
}
