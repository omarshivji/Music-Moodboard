import Foundation

struct HumanEntry: Identifiable {
  var id: UUID
  var date: String       // e.g. “Apr 22”
  var filename: String   // e.g. “[UUID]-[2025-04-22-13-45-02].md”
  var previewText: String
  
  static func createNew(with fullText: String) -> HumanEntry {
    let id = UUID()
    let now = Date()
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd-HH-mm-ss"
    let ts = df.string(from: now)
    df.dateFormat = "MMM d"
    let displayDate = df.string(from: now)
    let trimmed = fullText
      .replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let preview = trimmed.count > 60
      ? String(trimmed.prefix(60)) + "…"
      : trimmed
    return HumanEntry(
      id: id,
      date: displayDate,
      filename: "[\(id)]-[\(ts)].md",
      previewText: preview
    )
  }
}
