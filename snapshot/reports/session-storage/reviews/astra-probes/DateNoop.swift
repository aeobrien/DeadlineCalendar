import Foundation
@main struct DateNoop {
 static func main() throws {
  let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:folder) }
  let url=folder.appendingPathComponent("fixture.json")
  let first=SharedDataStore(fileURL:url); _ = try first.loadSnapshot()
  let project=Project(title:"Fractional date",finalDeadlineDate:Date(timeIntervalSince1970:1900000000.125))
  try first.saveSnapshot(projects:[project],templates:[],triggers:[],appSettings:AppSettings())
  let before=try Data(contentsOf:url)
  let second=SharedDataStore(fileURL:url); let secondDoc=try second.loadSnapshot()!
  Thread.sleep(forTimeInterval:1.1)
  try first.saveSnapshot(projects:[project],templates:[],triggers:[],appSettings:AppSettings())
  let after=try Data(contentsOf:url)
  print("Unchanged original input preserves bytes: \(before == after)")
  do {
   try second.saveSnapshot(projects:secondDoc.projects,templates:[],triggers:[],appSettings:AppSettings())
   print("PASS second window remains current")
  } catch { print("FAIL unchanged fractional-date input invalidated second window: \(error)"); exit(1) }
  if before != after { exit(1) }
 }
}
