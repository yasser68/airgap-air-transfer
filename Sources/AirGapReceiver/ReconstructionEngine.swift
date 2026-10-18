import Foundation
import CryptoKit
import Compression
import UIKit

public final class ReconstructionEngine: ObservableObject {
    @Published public var totalChunks: Int = 0
    @Published public var receivedChunks: [Int: String] = [:]
    @Published public var fileName: String = ""
    @Published public var origSize: Int = 0
    @Published public var shortHash: String = ""
    @Published public var isComplete: Bool = false
    @Published public var isVerifying: Bool = false
    @Published public var savedFileURL: URL? = nil
    @Published public var errorMessage: String? = nil

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let successGenerator = UINotificationFeedbackGenerator()
    private let processingQueue = DispatchQueue(label: "com.airgap.processing", qos: .userInitiated)

    public init() {
        feedbackGenerator.prepare()
        successGenerator.prepare()
    }

    public var progress: Double {
        guard totalChunks > 0 else { return 0.0 }
        return Double(receivedChunks.count) / Double(totalChunks)
    }

    public var progressPercentString: String {
        guard totalChunks > 0 else { return "0%" }
        let pct = Int(progress * 100)
        return "\(pct)%"
    }

    public func isChunkReceived(_ index: Int) -> Bool {
        return receivedChunks[index] != nil
    }

    public func processScannedCode(_ rawString: String) {
        guard !isComplete && !isVerifying else { return }

        // Must start with protocol header "AG1|"
        guard rawString.hasPrefix("AG1|") else { return }

        let parts = rawString.components(separatedBy: "|")
        // Expected format: AG1|total_chunks|chunk_index|filename|orig_size|short_hash|chunk_data
        guard parts.count == 7 else { return }

        guard let total = Int(parts[1]),
              let index = Int(parts[2]),
              let size = Int(parts[4]) else { return }

        let name = parts[3]
        let hash = parts[5]
        let payload = parts[6]

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.totalChunks == 0 {
                self.totalChunks = total
                self.fileName = name
                self.origSize = size
                self.shortHash = hash
            }

            // Only register if we haven't received this chunk yet
            if self.receivedChunks[index] == nil {
                self.receivedChunks[index] = payload
                self.feedbackGenerator.impactOccurred()

                // Check if we reached 100% completion
                if self.receivedChunks.count == self.totalChunks {
                    self.finalizeReconstruction()
                }
            }
        }
    }

    private func finalizeReconstruction() {
        isVerifying = true
        let chunksCopy = self.receivedChunks
        let total = self.totalChunks
        let expectedHash = self.shortHash
        let targetName = self.fileName
        let expectedSize = self.origSize

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            // 1. Reassemble chunks in sequential order 1..total
            var combinedBase64 = ""
            for i in 1...total {
                if let part = chunksCopy[i] {
                    combinedBase64.append(part)
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "نقص في الإطار رقم \(i)"
                        self.isVerifying = false
                    }
                    return
                }
            }

            // 2. Decode Base64 into compressed bytes
            guard let compressedData = Data(base64Encoded: combinedBase64) else {
                DispatchQueue.main.async {
                    self.errorMessage = "فشل في فك تشفير Base64"
                    self.isVerifying = false
                }
                return
            }

            // 3. Decompress zlib
            guard let decompressedData = self.decompress(data: compressedData, expectedSize: expectedSize) else {
                DispatchQueue.main.async {
                    self.errorMessage = "فشل في فك ضغط zlib"
                    self.isVerifying = false
                }
                return
            }

            // 4. Verify SHA-256 hash
            let computedHash = SHA256.hash(data: decompressedData)
            let computedHashHex = computedHash.map { String(format: "%02x", $0) }.joined()

            guard computedHashHex.hasPrefix(expectedHash) else {
                DispatchQueue.main.async {
                    self.errorMessage = "رمز التحقق غير متطابق! قد يكون الملف تالفاً."
                    self.isVerifying = false
                }
                return
            }

            // 5. Save to app's Documents directory
            let docsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileUrl = docsUrl.appendingPathComponent(targetName)

            do {
                try decompressedData.write(to: fileUrl, options: .atomic)
                DispatchQueue.main.async {
                    self.savedFileURL = fileUrl
                    self.isVerifying = false
                    self.isComplete = true
                    self.successGenerator.notificationOccurred(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "فشل حفظ الملف: \(error.localizedDescription)"
                    self.isVerifying = false
                }
            }
        }
    }

    private func decompress(data: Data, expectedSize: Int) -> Data? {
        let isXZ = data.starts(with: [0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00])
        let algorithm = isXZ ? COMPRESSION_LZMA : COMPRESSION_ZLIB

        let bufferSize = max(expectedSize, data.count * 10)
        var destinationData = Data(count: bufferSize)

        let decodedSize = destinationData.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { srcBuffer in
                compression_decode_buffer(
                    destBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    bufferSize,
                    srcBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    algorithm
                )
            }
        }

        if decodedSize > 0 {
            return destinationData.prefix(decodedSize)
        }

        // Fallback to the other algorithm if primary failed
        let fallbackAlgorithm = isXZ ? COMPRESSION_ZLIB : COMPRESSION_LZMA
        let fallbackSize = destinationData.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { srcBuffer in
                compression_decode_buffer(
                    destBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    bufferSize,
                    srcBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    fallbackAlgorithm
                )
            }
        }
        if fallbackSize > 0 {
            return destinationData.prefix(fallbackSize)
        }

        return nil
    }

    public func reset() {
        totalChunks = 0
        receivedChunks.removeAll()
        fileName = ""
        origSize = 0
        shortHash = ""
        isComplete = false
        isVerifying = false
        savedFileURL = nil
        errorMessage = nil
    }
}
