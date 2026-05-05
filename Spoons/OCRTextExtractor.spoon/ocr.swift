import Foundation
import Vision
import AppKit

func eprint(_ message: String) {
  FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

guard CommandLine.arguments.count >= 2 else {
  eprint("Usage: ocr.swift <imagePath>")
  exit(2)
}

let imagePath = CommandLine.arguments[1]
guard let nsImage = NSImage(contentsOfFile: imagePath) else {
  eprint("Failed to read image: \(imagePath)")
  exit(3)
}

var rect = NSRect(origin: .zero, size: nsImage.size)
guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
  eprint("Failed to convert image to CGImage")
  exit(4)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
  try handler.perform([request])
} catch {
  eprint("Vision error: \(error)")
  exit(5)
}

guard let results = request.results else {
  exit(0)
}

let lines: [String] = results.compactMap { obs in
  obs.topCandidates(1).first?.string
}

print(lines.joined(separator: "\n"))
