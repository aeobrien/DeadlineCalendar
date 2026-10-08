import Foundation
@main struct StoreFinal {
 static func main() throws {
  let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:folder) }
  let actual=SharedDataStore(containerProvider:{folder})
  guard try actual.loadSnapshot() == nil else { fatalError("Expected absence") }
  precondition(!FileManager.default.fileExists(atPath:folder.appendingPathComponent("Documents").path))
  try actual.saveSnapshot(projects:[],templates:[],triggers:[],appSettings:AppSettings())
  precondition(FileManager.default.fileExists(atPath:folder.appendingPathComponent("Documents/DeadlineCalendar.json").path))
  print("PASS default missing directory initialized only on save")
  let explicit=SharedDataStore(fileURL:folder.appendingPathComponent("arbitrary/missing.json"))
  _ = try explicit.loadSnapshot()
  var denied=false
  do { try explicit.saveSnapshot(projects:[],templates:[],triggers:[],appSettings:AppSettings()) } catch { denied=true }
  precondition(denied);precondition(!FileManager.default.fileExists(atPath:folder.appendingPathComponent("arbitrary").path))
  print("PASS explicit missing parent remains untouched")
  let blockedFolder=folder.appendingPathComponent("unavailable-container")
  try FileManager.default.createDirectory(at:blockedFolder,withIntermediateDirectories:false)
  let unavailable=SharedDataStore(availabilityCheck:{_ in throw SnapshotError.unavailable},containerProvider:{blockedFolder})
  denied=false;do {_ = try unavailable.loadSnapshot()}catch{denied=true};precondition(denied)
  denied=false;do{try unavailable.saveSnapshot(projects:[],templates:[],triggers:[],appSettings:AppSettings())}catch{denied=true};precondition(denied)
  let contents = try FileManager.default.contentsOfDirectory(atPath:blockedFolder.path); precondition(contents.isEmpty)
  print("PASS unavailable load neither initializes nor authorizes save")
  let missingContainer=SharedDataStore(containerProvider:{nil})
  denied=false;do{_ = try missingContainer.loadSnapshot()}catch{denied=true};precondition(denied)
  print("PASS absent provider refuses safely")
 }
}
