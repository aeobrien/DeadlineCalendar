import Foundation
@main struct ModelFinal {
 @MainActor static func main() throws {
  let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  defer {try? FileManager.default.removeItem(at:folder)}
  let suite="astra-model-"+UUID().uuidString;let defaults=UserDefaults(suiteName:suite)!
  defer {defaults.removePersistentDomain(forName:suite)}
  let url=folder.appendingPathComponent("fixture.json")
  var effects=0;var notices=0
  let model=DeadlineViewModel(store:SharedDataStore(fileURL:url),defaults:defaults,effectsEnabled:false,onCommit:{effects += 1},onNotifications:{notices += 1})
  let malformed=try JSONSerialization.data(withJSONObject:[["id":UUID().uuidString,"name":"Bad","subDeadlines":[],"templateTriggers":NSNull()]])
  defaults.set(malformed,forKey:"templates_key")
  precondition(!model.reloadCurrentData());model.updateNotifications();precondition(notices==0 && effects==0)
  precondition(defaults.data(forKey:"templates_key")==malformed);precondition(!FileManager.default.fileExists(atPath:url.path))
  print("PASS present malformed legacy field preserved with no notifications or initialization")
  defaults.removeObject(forKey:"templates_key")
  precondition(model.reloadCurrentData())
  let project=Project(title:"First",finalDeadlineDate:Date(timeIntervalSince1970:1900000000.125))
  precondition(model.addProject(project));let before=try Data(contentsOf:url);let e=effects;let n=notices
  precondition(model.saveAll());let after=try Data(contentsOf:url);precondition(after==before && effects==e && notices==n)
  print("PASS fractional project readback preserves unchanged save and effects")
  let other=SharedDataStore(fileURL:url);let doc=try other.loadSnapshot()!
  var projects=doc.projects;projects.append(Project(title:"Other",finalDeadlineDate:Date(timeIntervalSince1970:1910000000)))
  try other.saveSnapshot(projects:projects,templates:doc.templates,triggers:doc.triggers,appSettings:doc.appSettings)
  let current=try Data(contentsOf:url);let cache=defaults.data(forKey:"projects_v2_key")
  model.projects=[];model.templates=[];model.triggers=[]
  precondition(!model.saveAll());model.updateNotifications()
  let retained=try Data(contentsOf:url);precondition(retained==current && effects==e && notices==n)
  precondition(defaults.data(forKey:"projects_v2_key")==cache && model.projects.count==1 && model.pendingSnapshot?.projects.count==0)
  print("PASS stale restore-shaped save retains attempt and original displayed data without cache/notifications")
  let generation=model.editorGeneration;precondition(model.reloadCurrentData());precondition(model.projects.count==2 && generation != model.editorGeneration)
  precondition(model.pendingSnapshot?.projects.count==0)
  let count=notices;model.handleExternalSharedDataChange();model.updateNotifications();precondition(notices==count)
  print("PASS explicit reload retains failed attempt, invalidates editors; newer-data notice suppresses notifications")
 }
}
