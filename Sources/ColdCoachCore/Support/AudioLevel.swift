import Foundation

/// Pure audio-level helpers used to drive the input meter and the "no audio detected"
/// warning. Kept in the Core so the math is unit-testable without any audio hardware.
public enum AudioLevel {
    /// Root-mean-square amplitude of PCM float samples (0 = silence, ~1 = full scale).
    public static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }

    /// Map an RMS value to a 0...1 meter reading on a rough dB curve, so quiet speech is
    /// still visibly above the floor. Clamped to 0...1.
    public static func meter(rms: Float, floorDb: Float = -60, ceilDb: Float = -6) -> Float {
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        let clamped = min(max(db, floorDb), ceilDb)
        return (clamped - floorDb) / (ceilDb - floorDb)
    }

    /// Whether a window is essentially silent (below the capture floor). Used to detect
    /// "the mic is not hearing anything" independently of transcription.
    public static func isSilent(rms: Float, floor: Float = 0.004) -> Bool {
        rms < floor
    }
}
