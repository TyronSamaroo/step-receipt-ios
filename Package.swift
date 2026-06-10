// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "StepReceipt",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "StepReceiptCore", targets: ["StepReceiptCore"]),
        .executable(name: "StepReceiptCoreCheck", targets: ["StepReceiptCoreCheck"])
    ],
    targets: [
        .target(name: "StepReceiptCore"),
        .executableTarget(
            name: "StepReceiptCoreCheck",
            dependencies: ["StepReceiptCore"],
            path: "Tools/StepReceiptCoreCheck"
        ),
        .testTarget(
            name: "StepReceiptCoreTests",
            dependencies: ["StepReceiptCore"]
        )
    ]
)
