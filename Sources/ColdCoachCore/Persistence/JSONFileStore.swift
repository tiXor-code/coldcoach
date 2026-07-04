import Foundation

/// A dependency-free JSON file store. Playbooks and calls are kept as arrays,
/// upserted by id; settings is a single object. Suitable for a local single-user app
/// and fully testable by pointing `baseDirectory` at a temp directory.
public final class JSONFileStore: Store, @unchecked Sendable {
    private let baseDirectory: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseDirectory: URL, fileManager: FileManager = .default) throws {
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    /// Convenience: store under ~/Library/Application Support/ColdCoach.
    public static func applicationSupport(appName: String = "ColdCoach") throws -> JSONFileStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(appName, isDirectory: true)
        return try JSONFileStore(baseDirectory: base)
    }

    private var playbooksURL: URL { baseDirectory.appendingPathComponent("playbooks.json") }
    private var callsURL: URL { baseDirectory.appendingPathComponent("calls.json") }
    private var settingsURL: URL { baseDirectory.appendingPathComponent("settings.json") }

    // MARK: - Generic helpers

    private func readArray<T: Decodable>(_ url: URL, as type: T.Type) throws -> [T] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        if data.isEmpty { return [] }
        return try decoder.decode([T].self, from: data)
    }

    private func writeArray<T: Encodable>(_ items: [T], to url: URL) throws {
        let data = try encoder.encode(items)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Playbooks

    public func loadPlaybooks() throws -> [Playbook] {
        lock.lock(); defer { lock.unlock() }
        return try readArray(playbooksURL, as: Playbook.self)
    }

    public func savePlaybook(_ playbook: Playbook) throws {
        lock.lock(); defer { lock.unlock() }
        var items = try readArray(playbooksURL, as: Playbook.self)
        if let idx = items.firstIndex(where: { $0.id == playbook.id }) {
            items[idx] = playbook
        } else {
            items.append(playbook)
        }
        try writeArray(items, to: playbooksURL)
    }

    public func deletePlaybook(id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        var items = try readArray(playbooksURL, as: Playbook.self)
        items.removeAll { $0.id == id }
        try writeArray(items, to: playbooksURL)
    }

    // MARK: - Calls

    public func loadCalls() throws -> [CallRecord] {
        lock.lock(); defer { lock.unlock() }
        return try readArray(callsURL, as: CallRecord.self)
    }

    public func saveCall(_ call: CallRecord) throws {
        lock.lock(); defer { lock.unlock() }
        var items = try readArray(callsURL, as: CallRecord.self)
        if let idx = items.firstIndex(where: { $0.id == call.id }) {
            items[idx] = call
        } else {
            items.append(call)
        }
        try writeArray(items, to: callsURL)
    }

    public func deleteCall(id: UUID) throws {
        lock.lock(); defer { lock.unlock() }
        var items = try readArray(callsURL, as: CallRecord.self)
        items.removeAll { $0.id == id }
        try writeArray(items, to: callsURL)
    }

    // MARK: - Settings

    public func loadSettings() throws -> AppSettings {
        lock.lock(); defer { lock.unlock() }
        guard fileManager.fileExists(atPath: settingsURL.path) else { return .default }
        let data = try Data(contentsOf: settingsURL)
        if data.isEmpty { return .default }
        return try decoder.decode(AppSettings.self, from: data)
    }

    public func saveSettings(_ settings: AppSettings) throws {
        lock.lock(); defer { lock.unlock() }
        let data = try encoder.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }
}
