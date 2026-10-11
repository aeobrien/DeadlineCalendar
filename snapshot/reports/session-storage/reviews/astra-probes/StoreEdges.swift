import Foundation
@main struct StoreEdges {
 static func main() throws {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:folder, withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:folder) }
  var failures:[String]=[]
  let absentURL=folder.appendingPathComponent("Documents/DeadlineCalendar.json")
  let fresh=SharedDataStore(fileURL:absentURL)
  do {
   let existing=try fresh.loadSnapshot()
   print("Absent parent read: \(existing == nil)")
   try fresh.saveSnapshot(projects:[],templates:[],triggers:[],appSettings:AppSettings())
   print("PASS first save with absent parent")
  } catch { failures.append("First save with existing container but absent Documents: \(error)") }
  let url=folder.appendingPathComponent("existing.json")
  let initial=SharedData(projects:[],templates:[],triggers:[],appSettings:AppSettings(),lastModified:Date(timeIntervalSince1970:1000),lastModifiedBy:"cli")
  let encoder=JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
  let original=try encoder.encode(initial); try original.write(to:url)
  let first=SharedDataStore(fileURL:url); let second=SharedDataStore(fileURL:url)
  let doc=try first.loadSnapshot()!; _ = try second.loadSnapshot()
  try first.saveSnapshot(projects:doc.projects,templates:doc.templates,triggers:doc.triggers,appSettings:doc.appSettings)
  if try Data(contentsOf:url) != original { failures.append("Unchanged app save replaces exact bytes and lastModifiedBy") }
  do { try second.saveSnapshot(projects:[],templates:[],triggers:[],appSettings:AppSettings()); print("PASS second equivalent writer") }
  catch { failures.append("Unchanged first save invalidates another window: \(error)") }
  for failure in failures { print("FAIL: \(failure)") }
  if !failures.isEmpty { exit(1) }
 }
}
