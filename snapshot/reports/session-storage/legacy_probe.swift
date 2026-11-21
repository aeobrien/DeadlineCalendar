import Foundation
@main struct LegacyProbe {
 @MainActor static func main() throws {
  let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  defer { try? FileManager.default.removeItem(at:folder) }
  var failures:[String]=[]
  for scenario in ["template","projects","trigger"] {
   let suite="legacy-fixture-"+UUID().uuidString;let defaults=UserDefaults(suiteName:suite)!
   defer { defaults.removePersistentDomain(forName:suite) }
   let project=Project(title:"Legacy",finalDeadlineDate:Date(timeIntervalSince1970:1900000000))
   let id=UUID()
   if scenario=="template" {
    defaults.set(try JSONSerialization.data(withJSONObject:[["id":id.uuidString,"name":"Legacy template","subDeadlines":[]]]),forKey:"templates_key")
   } else if scenario=="projects" {
    defaults.set(try JSONEncoder().encode([project]),forKey:"SavedProjects")
   } else {
    defaults.set(try JSONEncoder().encode([project]),forKey:"projects_v2_key")
    defaults.set(try JSONEncoder().encode([Trigger(name:"Old",projectID:project.id)]),forKey:"triggers_v1_key")
   }
   let model=DeadlineViewModel(store:SharedDataStore(fileURL:folder.appendingPathComponent(scenario+".json")),defaults:defaults,effectsEnabled:false)
   if !model.reloadCurrentData() { failures.append(scenario+": rejected supported legacy data");continue }
   if scenario=="template" && model.templates.first?.id != id {failures.append("template missing")}
   if scenario=="projects" && model.projects.first?.id != project.id {failures.append("SavedProjects lost")}
   if scenario=="trigger" && model.triggers.first?.date != Calendar.current.date(byAdding:.day,value:-7,to:project.finalDeadlineDate) {failures.append("missing trigger date not migrated")}
  }
  for failure in failures {print("FAIL: "+failure)}
  if !failures.isEmpty {exit(1)}
  print("PASS three real ViewModel legacy paths; platform notifications/backup disabled")
 }
}
