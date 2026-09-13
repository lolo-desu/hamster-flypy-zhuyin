// SPDX-License-Identifier: MIT
// A display-only overlay. Never translate the characters passed to Rime.

public struct FlypyZhuyin: Equatable {
  public static let schemaID = "rime_frost_double_pinyin_flypy"
  public var enabled: Bool
  public var rawInput: String
  public var caret: Int

  public init(enabled: Bool = false, rawInput: String = "", caret: Int = 0) {
    self.enabled = enabled
    self.rawInput = rawInput
    self.caret = caret
  }

  // Rime's caret is a byte offset into raw input, not preedit (which expands
  // shuang to six letters). Explicit syllable delimiters reset the phase.
  // Recognizer commands, uppercase English and auxiliary codes use Latin caps.
  public var pendingInitial: Character? {
    let bytes = Array(rawInput.utf8)
    let prefix = bytes.prefix(max(0, min(caret, bytes.count)))
    guard prefix.allSatisfy({ (97...122).contains($0) || $0 == 39 || $0 == 32 }) else { return nil }
    let tail = prefix.split(omittingEmptySubsequences: false, whereSeparator: { $0 == 39 || $0 == 32 }).last ?? []
    guard tail.count % 2 == 1, let last = tail.last else { return nil }
    return Character(UnicodeScalar(last))
  }

  public var isPhoneticInput: Bool {
    let prefix = rawInput.utf8.prefix(max(0, caret))
    return prefix.allSatisfy { (97...122).contains($0) || $0 == 39 || $0 == 32 }
  }

  static let initials: [String: String] = [
    "q":"ㄑ", "w":"ㄨ", "e":"ㄜ", "r":"ㄖ", "t":"ㄊ", "y":"ㄧ", "u":"ㄕ", "i":"ㄔ", "o":"ㄛ", "p":"ㄆ",
    "a":"ㄚ", "s":"ㄙ", "d":"ㄉ", "f":"ㄈ", "g":"ㄍ", "h":"ㄏ", "j":"ㄐ", "k":"ㄎ", "l":"ㄌ",
    "z":"ㄗ", "x":"ㄒ", "c":"ㄘ", "v":"ㄓ", "b":"ㄅ", "n":"ㄋ", "m":"ㄇ"
  ]
  static let finals: [String: String] = [
    "q":"ㄧㄡ", "w":"ㄟ", "e":"ㄜ", "r":"ㄨㄢ／ㄩㄢ", "t":"ㄩㄝ", "y":"ㄨㄣ／ㄩㄣ", "u":"ㄨ", "i":"ㄧ", "o":"ㄛ／ㄨㄛ", "p":"ㄧㄝ",
    "a":"ㄚ", "s":"ㄨㄥ／ㄩㄥ", "d":"ㄞ", "f":"ㄣ", "g":"ㄥ", "h":"ㄤ", "j":"ㄢ", "k":"ㄧㄥ／ㄨㄞ", "l":"ㄧㄤ／ㄨㄤ",
    "z":"ㄡ", "x":"ㄧㄚ／ㄨㄚ", "c":"ㄠ", "v":"ㄩ／ㄨㄟ", "b":"ㄧㄣ", "n":"ㄧㄠ", "m":"ㄧㄢ"
  ]

  public func label(for key: String) -> String? {
    guard enabled, isPhoneticInput, key.count == 1, key == key.lowercased(), Self.initials[key] != nil else { return nil }
    guard let initial = pendingInitial else { return Self.initials[key] }
    // Zero-initial syllables retain Flypy's aa/ee/oo, ah/an/... encoding.
    if "aeo".contains(initial), key == String(initial) { return Self.initials[key] }
    // Resolve common shared finals without hiding/disabling any physical key.
    let palatal = "jqxy".contains(initial)
    switch key {
    case "r": return palatal ? "ㄩㄢ" : "ㄨㄢ"
    case "y": return palatal ? "ㄩㄣ" : "ㄨㄣ"
    case "s": return "jqx".contains(initial) ? "ㄩㄥ" : "ㄨㄥ"
    case "k": return "gkhvuirzcs".contains(initial) ? "ㄨㄞ" : "ㄧㄥ"
    case "l": return "jqxnlb".contains(initial) ? "ㄧㄤ" : "ㄨㄤ"
    case "x": return "gkhvuirzcs".contains(initial) ? "ㄨㄚ" : "ㄧㄚ"
    case "v": return "dtgkhvuirzcs".contains(initial) ? "ㄨㄟ" : "ㄩ"
    case "o": return "dtnlgkhvuirzcs".contains(initial) ? "ㄨㄛ" : "ㄛ"
    case "u": return palatal ? "ㄩ" : "ㄨ"
    default: return Self.finals[key]
    }
  }
}
