// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NoteNest",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NoteNestKit", path: "Sources/NoteNestKit"),
        .executableTarget(
            name: "NoteNest",
            dependencies: ["NoteNestKit"],
            path: "Sources/NoteNest"
        ),
        .testTarget(
            name: "NoteNestKitTests",
            dependencies: ["NoteNestKit"],
            path: "SwiftTests/NoteNestKitTests"
        ),
    ]
)
