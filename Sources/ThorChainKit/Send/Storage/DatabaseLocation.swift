import Foundation

struct DatabaseFileIdentity: Hashable, Sendable {
    let rawValue: String
}

struct DatabaseLocation: Hashable, Sendable {
    let url: URL
    let identity: DatabaseFileIdentity

    static func resolve(path: String) throws -> DatabaseLocation {
        let requestedURL = URL(fileURLWithPath: path).standardizedFileURL
        let directory = requestedURL.deletingLastPathComponent().resolvingSymlinksInPath()
        let fileURL = directory.appendingPathComponent(requestedURL.lastPathComponent)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else { throw DatabaseLocationError.unavailable }
        } else {
            guard FileManager.default.createFile(atPath: fileURL.path, contents: nil) else {
                throw DatabaseLocationError.unavailable
            }
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        let resource = try fileURL.resourceValues(forKeys: [.fileResourceIdentifierKey])
        let identity = resource.fileResourceIdentifier.map { String(describing: $0) } ?? fileURL.path
        return DatabaseLocation(url: fileURL, identity: DatabaseFileIdentity(rawValue: identity))
    }
}

enum DatabaseLocationError: Error, Equatable {
    case unavailable
}
