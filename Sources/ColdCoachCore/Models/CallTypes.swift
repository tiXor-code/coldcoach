import Foundation

/// How the app captures the two sides of a call.
public enum AudioMode: String, Codable, CaseIterable, Sendable {
    /// Mode A: phone on speaker next to the Mac; everything captured through the mic (one mixed stream).
    case speakerphoneMic
    /// Mode B: prospect via ScreenCaptureKit system audio, rep via mic (two clean streams).
    case systemPlusMic

    public var displayName: String {
        switch self {
        case .speakerphoneMic: return "Speakerphone (mic only)"
        case .systemPlusMic: return "System audio + mic"
        }
    }
}

/// Who is speaking in a transcript segment.
public enum Role: String, Codable, Sendable {
    case rep
    case prospect
    case unknown
}

/// The result of a call, logged after it ends. Drives playbook re-weighting.
public enum CallOutcome: String, Codable, CaseIterable, Sendable {
    case booked                 // meeting / next step secured
    case interested             // positive, no commitment yet
    case objectionUnresolved    // lost to an objection we could not turn
    case notInterested          // hard no
    case gatekeeperBlocked      // never reached the decision maker
    case voicemail
    case noAnswer
    case other

    public var displayName: String {
        switch self {
        case .booked: return "Booked / next step"
        case .interested: return "Interested"
        case .objectionUnresolved: return "Lost to objection"
        case .notInterested: return "Not interested"
        case .gatekeeperBlocked: return "Gatekeeper blocked"
        case .voicemail: return "Voicemail"
        case .noAnswer: return "No answer"
        case .other: return "Other"
        }
    }

    /// Whether this outcome counts as a "win" for weighting purposes.
    public var isPositive: Bool {
        switch self {
        case .booked, .interested: return true
        default: return false
        }
    }
}
