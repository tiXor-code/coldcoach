import Foundation

/// Tolerant extraction of the first balanced JSON object from an LLM response.
///
/// LLMs sometimes wrap JSON in prose or ```json fences even when asked not to.
/// This finds the first `{ ... }` with balanced braces (respecting string literals
/// and escapes) so parsing does not depend on the model returning bare JSON.
public enum JSONExtraction {
    public static func firstJSONObject(in text: String) -> String? {
        let scalars = Array(text)
        guard let startIndex = scalars.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false

        var i = startIndex
        while i < scalars.count {
            let ch = scalars[i]
            if inString {
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    inString = false
                }
            } else {
                switch ch {
                case "\"": inString = true
                case "{": depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 {
                        return String(scalars[startIndex...i])
                    }
                default:
                    break
                }
            }
            i += 1
        }
        return nil
    }

    /// Decode `T` from the first JSON object found in `text`.
    public static func decodeFirst<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        guard let json = firstJSONObject(in: text) else {
            throw LLMError.decoding("No JSON object found in model response")
        }
        guard let data = json.data(using: .utf8) else {
            throw LLMError.decoding("Extracted JSON was not valid UTF-8")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw LLMError.decoding("Failed to decode \(T.self): \(error.localizedDescription)")
        }
    }
}
