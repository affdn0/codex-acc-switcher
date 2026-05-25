import Foundation

public struct CodexLoginRunner {
    public var codexPath: String

    public init(codexPath: String = "/usr/bin/env") {
        self.codexPath = codexPath
    }

    public func runLogin() throws {
        let process = Process()
        if codexPath == "/usr/bin/env" {
            process.executableURL = URL(fileURLWithPath: codexPath)
            process.arguments = ["codex", "login"]
        } else {
            process.executableURL = URL(fileURLWithPath: codexPath)
            process.arguments = ["login"]
        }
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CodexLoginError.failed(Int(process.terminationStatus))
        }
    }
}

public enum CodexLoginError: Error, LocalizedError {
    case failed(Int)

    public var errorDescription: String? {
        switch self {
        case .failed(let status):
            "codex login exited with status \(status)."
        }
    }
}
