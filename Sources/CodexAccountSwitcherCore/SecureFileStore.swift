import Foundation

public final class SecureFileStore {
    public let root: URL
    private let fileManager: FileManager

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public func preparePrivateDirectories() throws {
        try createPrivateDirectory(root)
        try createPrivateDirectory(snapshotsDirectory)
        try createPrivateDirectory(quotaDirectory)
    }

    public var snapshotsDirectory: URL { root.appendingPathComponent("Account Snapshots", isDirectory: true) }
    public var quotaDirectory: URL { root.appendingPathComponent("Quota Snapshots", isDirectory: true) }

    public func atomicWrite(_ data: Data, to url: URL) throws {
        try createPrivateDirectory(url.deletingLastPathComponent())
        let temp = url.deletingLastPathComponent().appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        fileManager.createFile(atPath: temp.path, contents: data, attributes: [.posixPermissions: 0o600])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temp.path)
        if fileManager.fileExists(atPath: url.path) {
            _ = try fileManager.replaceItemAt(url, withItemAt: temp, backupItemName: nil, options: .usingNewMetadataOnly)
        } else {
            try fileManager.moveItem(at: temp, to: url)
        }
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public func permissions(at url: URL) throws -> Int {
        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        return attrs[.posixPermissions] as? Int ?? 0
    }

    private func createPrivateDirectory(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
}

extension SecureFileStore: @unchecked Sendable {}
