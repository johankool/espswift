// The manual pairing code as Matter apps show it, in plain Swift: tested on
// the Mac (see Tests/LightColorTests: Cmd+U).

/// An 11-digit manual pairing code in the groups of digits Matter apps show
/// it in: 3497-011-2332 for 34970112332. Other codes are left as they are.
public func formattedPairingCode(_ code: String) -> String {
    let digits = Array(code.utf8)
    guard digits.count == 11 else { return code }
    let groups = [digits[0..<4], digits[4..<7], digits[7..<11]].map { String(decoding: $0, as: UTF8.self) }
    return "\(groups[0])-\(groups[1])-\(groups[2])"
}
