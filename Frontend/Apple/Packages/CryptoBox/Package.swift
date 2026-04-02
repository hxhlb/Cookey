// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CryptoBox",
    products: [
        .library(name: "CryptoBox", targets: ["CryptoBox"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/jedisct1/swift-sodium.git",
            revision: "2b2f23c75ebcc40162dce904881c1be11d730cc7"
        ),
    ],
    targets: [
        .target(
            name: "CryptoBox",
            dependencies: [
                .product(name: "Sodium", package: "swift-sodium"),
                .product(name: "Clibsodium", package: "swift-sodium"),
            ]
        ),
        .testTarget(
            name: "CryptoBoxTests",
            dependencies: [
                "CryptoBox",
                .product(name: "Sodium", package: "swift-sodium"),
                .product(name: "Clibsodium", package: "swift-sodium"),
            ]
        ),
    ]
)
