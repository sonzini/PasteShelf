import Foundation

/// Localized string lookup. Keys are the English text; translations live in `Resources/<lang>.lproj/Localizable.strings`.
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Localized format string (`%@`, `%d`, …).
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}
