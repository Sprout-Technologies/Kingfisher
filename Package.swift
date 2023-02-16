// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Kingfisher",
    platforms: [.iOS(.v12)],
    products: [
        .library(name: "Kingfisher", targets: ["Kingfisher"])
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/APNGKit.git", from: "2.2.1")
    ],
    targets: [
        .target(
            name: "Kingfisher",
            dependencies: ["APNGKit"],
            path: "Sources"
        )
    ]
)
