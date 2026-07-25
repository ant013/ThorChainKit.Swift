import AppKit
import Foundation
import Vision

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAIL scan-s2-06-ocr: \(message)\n".utf8))
    exit(1)
}

func recognize(_ data: Data, source: String) -> String {
    guard let image = NSImage(data: data) else { fail("cannot decode \(source)") }
    var rect = NSRect(origin: .zero, size: image.size)
    guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
        fail("cannot create image representation for \(source)")
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    do {
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
    } catch {
        fail("Vision failed for \(source): \(error)")
    }
    guard let observations = request.results else { fail("Vision returned no results for \(source)") }
    return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
}

guard CommandLine.arguments.count == 3 else { fail("usage: scan-s2-06-ocr.swift <screenshots> <result>") }
let screenshots = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).standardizedFileURL
let result = URL(fileURLWithPath: CommandLine.arguments[2]).standardizedFileURL
let canary = "S206CANARY\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12))"
let image = NSImage(size: NSSize(width: 1200, height: 220))
image.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: image.size).fill()
canary.draw(at: NSPoint(x: 30, y: 80), withAttributes: [
    .font: NSFont.boldSystemFont(ofSize: 64),
    .foregroundColor: NSColor.black,
])
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fail("cannot create OCR self-test image")
}
let selfTest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(canary).png")
defer { try? FileManager.default.removeItem(at: selfTest) }
try? png.write(to: selfTest, options: .atomic)
guard recognize(png, source: selfTest.path).contains(canary) else { fail("OCR canary was missed") }

guard let enumerator = FileManager.default.enumerator(at: screenshots, includingPropertiesForKeys: [.isRegularFileKey]) else {
    fail("cannot enumerate screenshots")
}
var count = 0
for case let file as URL in enumerator where file.pathExtension.lowercased() == "png" {
    let data: Data
    do { data = try Data(contentsOf: file, options: .uncached) } catch { fail("cannot read \(file.path): \(error)") }
    _ = recognize(data, source: file.path)
    count += 1
}
guard count > 0 else { fail("no screenshots were scanned") }
guard let output = try? JSONSerialization.data(withJSONObject: [
    "images": count,
    "visionInitialized": true,
    "readable": true,
    "canariesMissed": false,
], options: [.sortedKeys]) else { fail("cannot encode OCR result") }
do { try output.write(to: result, options: .atomic) } catch { fail("cannot write OCR result: \(error)") }
print("PASS scan-s2-06-ocr (\(count) PNG)")
