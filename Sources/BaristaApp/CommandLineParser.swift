import Foundation

struct CommandLineParser {
    static func parse(_ input: String) -> [String]? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return []
        }

        var args: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var isEscaped = false
        var argumentStarted = false

        for char in input {
            if isEscaped {
                current.append(char)
                argumentStarted = true
                isEscaped = false
                continue
            }

            if char == "\\" && !inSingleQuote {
                argumentStarted = true
                isEscaped = true
                continue
            }

            if char == "\"" && !inSingleQuote {
                argumentStarted = true
                inDoubleQuote.toggle()
                continue
            }

            if char == "'" && !inDoubleQuote {
                argumentStarted = true
                inSingleQuote.toggle()
                continue
            }

            if char.isWhitespace && !inSingleQuote && !inDoubleQuote {
                if argumentStarted {
                    args.append(current)
                    current = ""
                    argumentStarted = false
                }
                continue
            }

            current.append(char)
            argumentStarted = true
        }

        if isEscaped || inSingleQuote || inDoubleQuote {
            return nil
        }

        if argumentStarted {
            args.append(current)
        }

        return args
    }
}
