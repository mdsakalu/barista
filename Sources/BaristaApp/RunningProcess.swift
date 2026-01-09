import Foundation

struct RunningProcess: Identifiable, Hashable {
    let id: Int
    let name: String
    let command: String

    var displayLabel: String {
        if name.isEmpty {
            return "PID \(id)"
        }
        return "\(name) (PID \(id))"
    }
}

struct ProcessLister {
    static func fetch(limit: Int = 50) -> [RunningProcess] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,comm="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        var results: [RunningProcess] = []
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let pidPart = parts.first, let pid = Int(pidPart) else { continue }
            let commandPath = parts.count > 1 ? String(parts[1]) : ""
            let name = commandPath.split(separator: "/").last.map(String.init) ?? commandPath
            results.append(RunningProcess(id: pid, name: name, command: commandPath))
        }

        results.sort {
            if $0.name == $1.name {
                return $0.id < $1.id
            }
            if $0.name.isEmpty { return false }
            if $1.name.isEmpty { return true }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        if results.count > limit {
            return Array(results.prefix(limit))
        }
        return results
    }
}
