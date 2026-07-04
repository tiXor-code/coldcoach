import Foundation

/// Local persistence for playbooks, calls, and settings. The default implementation
/// is a Foundation JSON file store (no database, no framework coupling).
public protocol Store: AnyObject {
    func loadPlaybooks() throws -> [Playbook]
    func savePlaybook(_ playbook: Playbook) throws
    func deletePlaybook(id: UUID) throws

    func loadCalls() throws -> [CallRecord]
    func saveCall(_ call: CallRecord) throws
    func deleteCall(id: UUID) throws

    func loadSettings() throws -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
}
