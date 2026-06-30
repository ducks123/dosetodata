import XCTest
@testable import DoseToData

/// Tests for the C1 fix: store-open failure must QUARANTINE (move) the user's
/// SwiftData store, never delete it.
final class SwiftDataStoreRecoveryTests: XCTestCase {

    private var tempRoot: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        tempRoot = fm.temporaryDirectory
            .appendingPathComponent("StoreRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: tempRoot)
    }

    private func write(_ name: String, in dir: URL, contents: String = "x") throws -> URL {
        let url = dir.appendingPathComponent(name)
        try contents.data(using: .utf8)!.write(to: url)
        return url
    }

    // MARK: - isStoreFile

    func testIsStoreFileMatchesSwiftDataAndSQLiteFiles() {
        XCTAssertTrue(SwiftDataStoreRecovery.isStoreFile("default.store"))
        XCTAssertTrue(SwiftDataStoreRecovery.isStoreFile("default.store-wal"))
        XCTAssertTrue(SwiftDataStoreRecovery.isStoreFile("default.store-shm"))
        XCTAssertTrue(SwiftDataStoreRecovery.isStoreFile("MyApp.sqlite"))
        XCTAssertTrue(SwiftDataStoreRecovery.isStoreFile("MyApp.sqlite-wal"))
        XCTAssertTrue(SwiftDataStoreRecovery.isStoreFile("MyApp.sqlite-shm"))
    }

    func testIsStoreFileIgnoresUnrelatedFiles() {
        XCTAssertFalse(SwiftDataStoreRecovery.isStoreFile("notes.txt"))
        XCTAssertFalse(SwiftDataStoreRecovery.isStoreFile("MedicationLibrary.json"))
        XCTAssertFalse(SwiftDataStoreRecovery.isStoreFile("QuarantinedStore-20260628-120000"))
    }

    // MARK: - Quarantine moves, never deletes

    func testQuarantineMovesStoreFilesAndPreservesData() throws {
        let storeDir = tempRoot.appendingPathComponent("store", isDirectory: true)
        let quarantineRoot = tempRoot.appendingPathComponent("quarantine", isDirectory: true)
        try fm.createDirectory(at: storeDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: quarantineRoot, withIntermediateDirectories: true)

        let mainStore = try write("default.store", in: storeDir, contents: "PRECIOUS_HEALTH_DATA")
        let wal = try write("default.store-wal", in: storeDir)
        let shm = try write("default.store-shm", in: storeDir)
        let unrelated = try write("notes.txt", in: storeDir, contents: "keep me")

        let ts = Date(timeIntervalSince1970: 1_780_000_000)
        let moved = SwiftDataStoreRecovery.quarantineStoreFiles(
            in: [storeDir],
            quarantineRoot: quarantineRoot,
            timestamp: ts
        )

        // Three store files quarantined.
        XCTAssertEqual(moved.count, 3, "Expected the 3 store files to be quarantined")

        // Originals are GONE from the source dir (moved, not copied)...
        XCTAssertFalse(fm.fileExists(atPath: mainStore.path))
        XCTAssertFalse(fm.fileExists(atPath: wal.path))
        XCTAssertFalse(fm.fileExists(atPath: shm.path))

        // ...but they were NOT deleted — they exist in quarantine with data intact.
        let quarantinedMain = moved.first { $0.lastPathComponent == "default.store" }
        XCTAssertNotNil(quarantinedMain)
        let recovered = try String(contentsOf: quarantinedMain!, encoding: .utf8)
        XCTAssertEqual(recovered, "PRECIOUS_HEALTH_DATA", "Quarantined data must be byte-for-byte preserved")

        // Unrelated file is untouched.
        XCTAssertTrue(fm.fileExists(atPath: unrelated.path))
    }

    func testQuarantineWithNoStoreFilesIsNoOp() throws {
        let storeDir = tempRoot.appendingPathComponent("empty", isDirectory: true)
        let quarantineRoot = tempRoot.appendingPathComponent("q2", isDirectory: true)
        try fm.createDirectory(at: storeDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: quarantineRoot, withIntermediateDirectories: true)
        _ = try write("notes.txt", in: storeDir)

        let moved = SwiftDataStoreRecovery.quarantineStoreFiles(
            in: [storeDir],
            quarantineRoot: quarantineRoot,
            timestamp: Date(timeIntervalSince1970: 1_780_000_000)
        )

        XCTAssertTrue(moved.isEmpty)
        // No quarantine folder should have been created when there was nothing to move.
        let quarantineContents = try fm.contentsOfDirectory(at: quarantineRoot, includingPropertiesForKeys: nil)
        XCTAssertTrue(quarantineContents.isEmpty)
    }

    func testRecordQuarantineWritesBreadcrumb() {
        let defaults = UserDefaults(suiteName: "StoreRecoveryTests-\(UUID().uuidString)")!
        let ts = Date(timeIntervalSince1970: 1_780_000_000)
        let files = [tempRoot.appendingPathComponent("QuarantinedStore-x/default.store")]

        SwiftDataStoreRecovery.recordQuarantine(files, timestamp: ts, defaults: defaults)

        let info = defaults.dictionary(forKey: SwiftDataStoreRecovery.lastQuarantineKey) as? [String: String]
        XCTAssertNotNil(info)
        XCTAssertEqual(info?["fileCount"], "1")
        XCTAssertNotNil(info?["path"])
        XCTAssertNotNil(info?["timestamp"])
    }
}
