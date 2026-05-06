// =====================================================
// DVSM LINUX RUNTIME ADAPTER
// Drop-in file to make DVSMExecutionEngine runnable
// =====================================================

import Foundation
import Crypto

// =====================================================
// MARK: - CRYPTO (SHA256 IMPLEMENTATION)
// =====================================================

public struct LinuxCrypto: DVSMCryptoBridge {

    public init() {}

    public func hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// =====================================================
// MARK: - CONSENSUS (LOCAL QUORUM SIMULATION)
// Replace with real CCL layer later
// =====================================================

public final class LocalConsensus: DVSMConsensusBridge {

    private let threshold: Double

    public init(threshold: Double = 0.66) {
        self.threshold = threshold
    }

    public func validateCommit(id: String, root: String) -> Bool {

        // Simulated deterministic quorum
        let hash = root.hashValue
        let normalized = abs(Double(hash % 100)) / 100.0

        return normalized >= (1.0 - threshold)
    }
}

// =====================================================
// MARK: - PERSISTENCE (APPEND-ONLY FILE STORAGE)
// =====================================================

public final class FilePersistence: DVSMPersistenceBridge {

    private let baseURL: URL
    private let queue = DispatchQueue(label: "dvsm.persistence")

    public init(path: String = "./dvsm_data") {

        self.baseURL = URL(fileURLWithPath: path)

        try? FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )
    }

    public func store(
        id: String,
        payload: Data,
        root: String
    ) async throws {

        try await withCheckedThrowingContinuation { continuation in

            queue.async {

                do {
                    let fileURL = self.baseURL
                        .appendingPathComponent("\(id).log")

                    let record = """
                    ROOT:\(root)
                    PAYLOAD:\(payload.base64EncodedString())
                    ----
                    """

                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let handle = try FileHandle(forWritingTo: fileURL)
                        try handle.seekToEnd()
                        handle.write(Data(record.utf8))
                        try handle.close()
                    } else {
                        try record.write(to: fileURL, atomically: true, encoding: .utf8)
                    }

                    continuation.resume()

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// =====================================================
// MARK: - OPTIONAL: ZK (NO-OP PLACEHOLDER)
// =====================================================

public struct NoOpZKVerifier: DVSMZKVerifier {
    public init() {}
    public func verify(proof: Data) -> Bool {
        true
    }
}

// =====================================================
// MARK: - OPTIONAL: BLS (NO-OP PLACEHOLDER)
// =====================================================

public struct NoOpBLSAggregator: DVSMBLSAggregator {
    public init() {}
    public func aggregate(signatures: [Data]) -> Data {
        Data(signatures.joined())
    }
}

// =====================================================
// MARK: - DVSM SYSTEM FACTORY (READY-TO-RUN)
// =====================================================

public struct DVSMSystemFactory {

    public static func makeDefault(
        mode: DVSMExecutionMode = .hybrid
    ) -> DVSMExecutionEngine {

        let crypto = LinuxCrypto()
        let consensus = LocalConsensus()
        let persistence = FilePersistence()

        let policy = DVSMPolicy(
            maxInstability: 0.75,
            minConfidence: 0.4,
            minReliability: 0.6
        )

        return DVSMExecutionEngine(
            mode: mode,
            policy: policy,
            crypto: crypto,
            consensus: consensus,
            persistence: persistence,
            zk: NoOpZKVerifier(),
            bls: NoOpBLSAggregator()
        )
    }
}

// =====================================================
// MARK: - SIMPLE RUNNER (TEST / DEMO ENTRY)
// =====================================================

@main
struct DVSMRunner {

    static func main() async {

        let engine = DVSMSystemFactory.makeDefault(mode: .hybrid)

        let node = NodeContext(
            nodeID: "node-1",
            shardKey: "A"
        )

        do {

            let success = try await engine.ingest(
                id: "tx-1",
                vector: [0.1, 0.9, 0.3],
                entropy: 0.2,
                confidence: 0.8,
                reliability: 0.9,
                node: node
            )

            print("INGEST RESULT:", success)

        } catch {
            print("ERROR:", error)
        }
    }
}
