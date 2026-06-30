import Foundation

/// Recovery helper for the SwiftData persistent store.
///
/// **Why this exists / the invariant it protects:**
/// DoseToData stores all health data locally — the on-disk SwiftData store is
/// the user's only copy. If `ModelContainer` fails to open (a migration bug,
/// transient file-system error, locked file, partial iOS restore, or a
/// SwiftData regression), we must NEVER delete that store. The previous
/// recovery path hard-deleted the store to let the app re-open with a fresh
/// database, which could silently and permanently erase years of mood,
/// medication, dose, adherence, and side-effect history.
///
/// Instead, this helper **quarantines** the store: it MOVES the store files
/// aside into a timestamped backup folder. The app can then re-open with a
/// fresh store (so it still launches), while the user's original data remains
/// on the device, recoverable by a future migration/recovery flow or by
/// support. Quarantine never destroys data.
enum SwiftDataStoreRecovery {

    /// UserDefaults key holding a breadcrumb (path + ISO timestamp) for the
    /// most recent quarantine, so a future recovery UI / support tooling can
    /// locate the set-aside store.
    static let lastQuarantineKey = "com.stewartsherpa.dosetodata.lastStoreQuarantine"

    /// True if `name` looks like a SwiftData/SQLite store file we manage.
    /// Matches SwiftData's default `default.store` plus its `-wal` / `-shm`
    /// journal siblings, and any `.sqlite*` files.
    static func isStoreFile(_ name: String) -> Bool {
        name.hasPrefix("default.store")
            || name.hasSuffix(".sqlite")
            || name.hasSuffix(".sqlite-wal")
            || name.hasSuffix(".sqlite-shm")
    }

    /// Moves (quarantines) any store files found in `directories` into a
    /// timestamped subfolder of `quarantineRoot`. Returns the destination
    /// URLs of the files that were successfully quarantined.
    ///
    /// Guarantees:
    /// - Files are MOVED, never deleted. If a move fails, the original is left
    ///   untouched (we never fall back to deletion).
    /// - The quarantine subfolder itself is skipped during enumeration so we
    ///   don't re-quarantine already-quarantined files.
    @discardableResult
    static func quarantineStoreFiles(
        in directories: [URL],
        quarantineRoot: URL,
        timestamp: Date,
        fileManager: FileManager = .default
    ) -> [URL] {
        let folderName = "QuarantinedStore-\(Self.stamp(from: timestamp))"
        let quarantineDir = quarantineRoot.appendingPathComponent(folderName, isDirectory: true)

        var moved: [URL] = []

        for dir in directories {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            ) else { continue }

            for url in contents where isStoreFile(url.lastPathComponent) {
                // Never touch the quarantine folder we may be creating inside
                // one of the scanned directories.
                if url.lastPathComponent == folderName { continue }

                // Create the quarantine dir lazily, only once we actually have
                // something to move.
                if !fileManager.fileExists(atPath: quarantineDir.path) {
                    guard (try? fileManager.createDirectory(
                        at: quarantineDir, withIntermediateDirectories: true
                    )) != nil else {
                        // Couldn't create the backup dir — do NOT delete; bail.
                        return moved
                    }
                }

                let destination = Self.uniqueDestination(
                    for: url.lastPathComponent,
                    in: quarantineDir,
                    fileManager: fileManager
                )
                // Move, not copy+delete: if this throws, the original stays put.
                if (try? fileManager.moveItem(at: url, to: destination)) != nil {
                    moved.append(destination)
                }
            }
        }
        return moved
    }

    /// Records a breadcrumb so a future recovery flow / support can find the
    /// quarantined store. No-op if nothing was quarantined.
    static func recordQuarantine(
        _ quarantined: [URL],
        timestamp: Date,
        defaults: UserDefaults = .standard
    ) {
        guard let first = quarantined.first else { return }
        let info: [String: String] = [
            "path": first.deletingLastPathComponent().path,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "fileCount": String(quarantined.count),
        ]
        defaults.set(info, forKey: lastQuarantineKey)
    }

    // MARK: - Private

    /// Avoids clobbering an existing file in the quarantine dir (e.g. repeated
    /// failures within the same second). Never overwrites.
    private static func uniqueDestination(
        for name: String,
        in dir: URL,
        fileManager: FileManager
    ) -> URL {
        var candidate = dir.appendingPathComponent(name)
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(name).\(counter)")
            counter += 1
        }
        return candidate
    }

    /// Filename-safe timestamp (no colons/spaces) for the quarantine folder.
    private static func stamp(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: date)
    }
}
