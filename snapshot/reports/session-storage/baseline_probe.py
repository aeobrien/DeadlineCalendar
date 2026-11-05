"""Compile baseline store with only hard-coded root redirected to disposable fixture."""
import json,os,subprocess,tempfile,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='deadline-baseline-') as tmp:
 p=Path(tmp);docs=p/'data';docs.mkdir()
 source=subprocess.check_output(['git','show','4857669:deadline-cli/Sources/DataStore.swift'],cwd=root,text=True)
 old='NSHomeDirectory() + "/Library/Mobile Documents/iCloud~AOTondra~Deadline-Calendar/Documents"'
 assert source.count(old)==1
 source=source.replace(old,'ProcessInfo.processInfo.environment["DEADLINE_FIXTURE_ROOT"]!')
 (p/'DataStore.swift').write_text(source)
 (p/'Main.swift').write_text('''import Foundation
@main struct Main {
 static func main() throws {
  let args=CommandLine.arguments; let store=try DataStore()
  if args[1]=="seed" {
   _ = try store.save(projects:[Project(title:"Synthetic one",finalDeadlineDate:Date()),Project(title:"Synthetic two",finalDeadlineDate:Date())],templates:[],triggers:[],appSettings:AppSettings());return
  }
  if args[1]=="mutate" {
   let index=Int(args[2])!; let dir=URL(fileURLWithPath:args[3]);
   _ = try store.mutate { projects,_,_,_ in
    try! Data().write(to:dir.appendingPathComponent("ready-\\(index)"))
    while !FileManager.default.fileExists(atPath:dir.appendingPathComponent("release").path) {Thread.sleep(forTimeInterval:0.01)}
    projects[index].title += " UPDATED"
   }
  }
 }
}
''')
 q=subprocess.run(['swiftc','-module-cache-path',str(p/'module-cache'),str(root/'deadline-cli/Sources/Models.swift'),str(p/'DataStore.swift'),str(p/'Main.swift'),'-o',str(p/'probe')],capture_output=True,text=True,timeout=90)
 if q.returncode:print(q.stderr);sys.exit(q.returncode)
 env={**os.environ,'DEADLINE_FIXTURE_ROOT':str(docs)}
 subprocess.run([str(p/'probe'),'seed'],env=env,check=True,capture_output=True)
 processes=[subprocess.Popen([str(p/'probe'),'mutate',str(i),str(p)],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for i in range(2)]
 import time
 end=time.monotonic()+10
 while not all((p/f'ready-{i}').exists() for i in range(2)):
  if time.monotonic()>end:raise RuntimeError('barrier timeout')
  time.sleep(.01)
 (p/'release').touch()
 for proc in processes:
  out,err=proc.communicate(timeout=10);assert proc.returncode==0,err
 data=json.loads((docs/'DeadlineCalendar.json').read_text());updated=sum('UPDATED' in x['title'] for x in data['projects'])
 print(json.dumps({'fixture_only':True,'path_only_source_instrumentation':True,'both_writers_exit':0,'expected_updates':2,'actual_updates':updated,'titles':[x['title'] for x in data['projects']]}))
 assert updated==2,'LOST UPDATE: both writes reported success, one independent change disappeared'
