// swift-tools-version: 5.9
// SquooshJPEGKit — JPEG encoder aligned with Google Squoosh's MozJPEG behavior
// Created by okooo5km(十里)

import PackageDescription

let package = Package(
    name: "SquooshJPEGKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SquooshJPEGKit", targets: ["SquooshJPEGKit"]),
    ],
    targets: [
        .target(
            name: "CMozJPEG",
            publicHeadersPath: "include",
            cSettings: [
                .define("NO_GETENV"),
            ]
        ),
        .target(
            name: "CSquooshRotate",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CSquooshResize",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SquooshJPEGKit",
            dependencies: ["CMozJPEG", "CSquooshRotate", "CSquooshResize"]
        ),
        .testTarget(
            name: "SquooshJPEGKitTests",
            dependencies: ["SquooshJPEGKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
