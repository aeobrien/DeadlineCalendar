import Foundation

@main struct AppStoreProbe {
 static func main() throws {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  let defaultStore = SharedDataStore(containerProvider: { folder })
  let absentDefault = try defaultStore.loadSnapshot(); precondition(absentDefault == nil)
  precondition(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("Documents").path))
  try defaultStore.saveSnapshot(projects: [], templates: [], triggers: [], appSettings: AppSettings())
  precondition(FileManager.default.fileExists(atPath: folder.appendingPathComponent("Documents/DeadlineCalendar.json").path))
  let badExplicit = SharedDataStore(fileURL: folder.appendingPathComponent("missing/fixture.json"))
  _ = try badExplicit.loadSnapshot()
  do { try badExplicit.saveSnapshot(projects: [], templates: [], triggers: [], appSettings: AppSettings()); fatalError("Explicit parent created") } catch { }
  precondition(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("missing").path))
  let url = folder.appendingPathComponent("fixture.json")
  let a = SharedDataStore(fileURL: url)
  let absent = try a.loadSnapshot(); precondition(absent == nil)
  try a.saveSnapshot(projects: [], templates: [], triggers: [], appSettings: AppSettings())
  let cli = Process()
  cli.executableURL = URL(fileURLWithPath: CommandLine.arguments[1])
  cli.arguments = ["add", "Other writer", "--date", "2030-02-01", "--id", "33333333-3333-4333-8333-333333333333", "--approved", "--data-file", url.path]
  cli.standardOutput = Pipe(); cli.standardError = Pipe()
  try cli.run(); cli.waitUntilExit(); precondition(cli.terminationStatus == 0)
  let before = try Data(contentsOf: url)
  do { try a.saveSnapshot(projects: [], templates: [], triggers: [], appSettings: AppSettings()); fatalError("Stale save accepted") }
  catch SnapshotError.conflict { }
  let after = try Data(contentsOf: url); precondition(after == before)
  let current = try a.loadSnapshot()!
  let equivalent = SharedDataStore(fileURL: url); _ = try equivalent.loadSnapshot()
  try a.saveSnapshot(projects: current.projects, templates: current.templates, triggers: current.triggers, appSettings: current.appSettings)
  let unchanged = try Data(contentsOf: url); precondition(unchanged == before)
  try equivalent.saveSnapshot(projects: current.projects, templates: current.templates, triggers: current.triggers, appSettings: current.appSettings)

  precondition(current.projects.count == 1)
  try a.saveSnapshot(projects: current.projects, templates: [], triggers: [], appSettings: AppSettings())
  let c = SharedDataStore(fileURL: url)
  do { try c.saveSnapshot(projects: [], templates: [], triggers: [], appSettings: AppSettings()); fatalError("Save without load accepted") }
  catch { }
  try Data("broken".utf8).write(to: url)
  do { _ = try a.loadSnapshot(); fatalError("Corruption accepted") } catch { }
  do { try a.saveSnapshot(projects: [], templates: [], triggers: [], appSettings: AppSettings()); fatalError("Failed load allowed save") } catch { }
  let broken = try String(contentsOf: url, encoding: .utf8); precondition(broken == "broken")
  print("PASS: missing initialization, actual CLI writer, stale rejection, reload, no-load refusal and corrupt load preservation")
 }
}
