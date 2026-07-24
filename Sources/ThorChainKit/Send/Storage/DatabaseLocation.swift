import Darwin
import Foundation

struct DatabaseFileIdentity: Hashable, Sendable {
    let device: UInt64
    let inode: UInt64

    var rawValue: String { "\(device):\(inode)" }
}

private final class DatabaseFileDescriptor: @unchecked Sendable {
    let rawValue: Int32

    init(rawValue: Int32) { self.rawValue = rawValue }

    deinit { Darwin.close(rawValue) }
}

struct DatabaseLocation: Hashable, Sendable {
    let url: URL
    let identity: DatabaseFileIdentity
    private let descriptor: DatabaseFileDescriptor

    static func == (lhs: DatabaseLocation, rhs: DatabaseLocation) -> Bool {
        lhs.url == rhs.url && lhs.identity == rhs.identity
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(identity)
    }

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
        let descriptor = Darwin.open(fileURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw DatabaseLocationError.unavailable }
        let handle = DatabaseFileDescriptor(rawValue: descriptor)
        var fileStat = stat()
        guard fstat(handle.rawValue, &fileStat) == 0 else { throw DatabaseLocationError.unavailable }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        return DatabaseLocation(
            url: fileURL.resolvingSymlinksInPath(),
            identity: DatabaseFileIdentity(device: UInt64(fileStat.st_dev), inode: UInt64(fileStat.st_ino)),
            descriptor: handle
        )
    }

    func stillResolvesToSameIdentity() -> Bool {
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else { return false }
        defer { Darwin.close(descriptor) }
        var fileStat = stat()
        guard fstat(descriptor, &fileStat) == 0 else { return false }
        return DatabaseFileIdentity(device: UInt64(fileStat.st_dev), inode: UInt64(fileStat.st_ino)) == identity
    }
}

enum DatabaseLocationError: Error, Equatable {
    case unavailable
}
