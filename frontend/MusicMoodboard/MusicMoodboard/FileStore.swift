import Foundation

class FileStore {
  static let shared = FileStore()
  let journalDir: URL

  private init() {
    let docs = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("MyJournal")
    try? FileManager.default.createDirectory(at: docs,
      withIntermediateDirectories: true)
    journalDir = docs
  }

  func save(_ entry: HumanEntry, fullText: String) throws {
    let url = journalDir.appendingPathComponent(entry.filename)
    try fullText.write(to: url, atomically: true, encoding: .utf8)
  }

  func loadAll() -> [HumanEntry] {
    let urls = (try? FileManager.default.contentsOfDirectory(
       at: journalDir, includingPropertiesForKeys: nil)) ?? []
    return urls
      .filter { $0.pathExtension == "md" }
      .compactMap { url in
        let name = url.lastPathComponent
        // extract UUID + timestamp; then read file and build HumanEntry
        // (see code in previous message for full regex parsing)
        // for brevity here assume HumanEntry.createNew(with:) and overwrite fields
        guard let text = try? String(contentsOf: url) else { return nil }
        var e = HumanEntry.createNew(with: text)
        e.filename = name
        // reformat e.id and e.date from filename if you like
        e.previewText = text
          .replacingOccurrences(of: "\n", with: " ")
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .prefix(60) + "…"
        return e
      }
      .sorted { $0.date > $1.date }
  }
}
