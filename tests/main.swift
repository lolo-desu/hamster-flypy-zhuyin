
func state(_ raw: String, _ caret: Int? = nil) -> FlypyZhuyin {
  FlypyZhuyin(enabled: true, rawInput: raw, caret: caret ?? raw.utf8.count)
}
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  if !condition() { fatalError(message) }
}
check(state("").label(for: "h") == "ㄏ", "Initial H")
check(state("h").label(for: "h") == "ㄤ", "Final H")
check(state("x").label(for: "l") == "ㄧㄤ", "xiang")
check(state("h").label(for: "l") == "ㄨㄤ", "huang")
check(state("j").label(for: "s") == "ㄩㄥ", "jiong")
check(state("d").label(for: "s") == "ㄨㄥ", "dong")
check(state("a").label(for: "a") == "ㄚ", "zero initial aa")
check(state("a").label(for: "h") == "ㄤ", "zero initial ang")
check(state("ni").label(for: "h") == "ㄏ", "complete syllable resets")
check(state("nih").label(for: "c") == "ㄠ", "continuous phrase")
check(state("nihc").pendingInitial == nil, "full phrase")
check(state("ni").pendingInitial == nil, "delete final syllable")
check(state("n").pendingInitial == "n", "delete to pending initial")
check(state("").pendingInitial == nil, "commit or clear")
check(state("nihc", 3).pendingInitial == "h", "caret inside phrase")
check(state("nihc", 2).pendingInitial == nil, "caret boundary")
check(state("n'h").pendingInitial == "h", "delimiter after odd segment")
check(state("n'").pendingInitial == nil, "trailing delimiter")
check(state("ni h").pendingInitial == "h", "space delimiter")
check(state("nihc", -1).pendingInitial == nil, "negative caret clamped")
check(state("ni", 99).pendingInitial == nil, "large caret clamped")
for raw in ["/fh", "`ab", "ni`ab", "ABC", "123", "你好"] {
  check(state(raw).label(for: "h") == nil, "recognizer and nonphonetic fallback: \(raw)")
}
check(FlypyZhuyin().label(for: "h") == nil, "disabled / other schema / English")
check(state("").label(for: "H") == nil, "uppercase action preserved")
check(state("").label(for: "空格") == nil, "function keys preserved")
for key in "qwertyuiopasdfghjklzxcvbnm" {
  check(state("").label(for: String(key)) != nil, "initial coverage")
  check(state("n").label(for: String(key)) != nil, "final coverage")
}
print("FlypyZhuyin: state and mapping checks passed")
