"""One headless fixture run with exact hashes and owned process/simulator cleanup."""
from pathlib import Path
import hashlib,json,subprocess,sys,os,signal,time,shlex
ROOT=Path('/Users/aidan/Dev/DeadlineCalendar-session-storage')
OUT=ROOT/'reports/session-storage/root-resume-20261006'
UDID='DDCF7C0E-E17C-47E3-9FB9-43DC69B7970F'
def save(name,value):(OUT/name).write_text(json.dumps(value,indent=2)+'\n')
def hashes():
 expected=json.loads((ROOT/'reports/session-storage/candidate-hashes-03.json').read_text())['files']
 current={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in expected}
 assert current==expected, [p for p in expected if current[p]!=expected[p]]
 return current
def processes():
 text=subprocess.check_output(['ps','-axo','pid=,pgid=,comm=,args='],text=True)
 rows=[]
 for line in text.splitlines():
  fields=line.strip().split(None,3)
  if len(fields)==4:rows.append({'pid':int(fields[0]),'pgid':int(fields[1]),'comm':fields[2],'args':fields[3]})
 return rows
def sim():
 data=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','--json'],text=True,timeout=20))
 found=[s for devices in data['devices'].values() for s in devices if s['udid']==UDID]
 assert len(found)==1 and found[0]['name']=='DeadlineStorageFixtures',found
 return {k:found[0].get(k) for k in ('udid','name','state','isAvailable')}
assert not (OUT/'preflight.json').exists(),'Never overwrite a prior run'
owned=[r for r in processes() if r['pid']!=os.getpid() and (('/private/tmp/deadline-storage-derived' in r['args'] and 'xcodebuild' in r['comm']) or ('run_ios_tests.py' in r['args'] and 'python' in r['comm']))]
state=sim();save('preflight.json',{'hashes':hashes(),'simulator':state,'existing_test_processes':owned})
assert not owned,owned
assert state['state']=='Shutdown' and state['isAvailable']
# Understudy launches this bootstrap in a new process group; record its identity.
bootstrap=OUT/'test_entry.py'
bootstrap.write_text("import os,json,runpy,sys\nfrom pathlib import Path\np=Path("+repr(str(OUT/'owned-group.json'))+")\np.write_text(json.dumps({'pid':os.getpid(),'pgid':os.getpgrp()}))\nsys.argv=['run_ios_tests.py','--evidence',"+repr(str(OUT/'ios-01'))+",'--expected-tests','14']\nrunpy.run_path("+repr(str(ROOT/'reports/session-storage/run_ios_tests.py'))+",run_name='__main__')\n")
cmd=['understudy','cli-run','--cmd','python3 '+shlex.quote(str(bootstrap)),'--cwd',str(ROOT),'--timeout','600','--expect-exit','0','--expect-stdout-contains','"passedTests": 14','--out',str(OUT/'understudy-01')]
save('understudy-argv.json',cmd)
rc=1;cleanup={};start=time.monotonic()
try:
 run=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True)
 (OUT/'understudy.stdout').write_text(run.stdout);(OUT/'understudy.stderr').write_text(run.stderr)
 rc=run.returncode
finally:
 if (OUT/'owned-group.json').exists():
  group=json.loads((OUT/'owned-group.json').read_text());assert group['pid']==group['pgid'] and group['pgid']!=os.getpgrp()
  residual=[r for r in processes() if r['pgid']==group['pgid']]
  cleanup['owned_group']=group;cleanup['residual_before_cleanup']=residual
  if residual:
   os.killpg(group['pgid'],signal.SIGTERM);time.sleep(1)
   residual2=[r for r in processes() if r['pgid']==group['pgid']]
   if residual2:
    try:os.killpg(group['pgid'],signal.SIGKILL)
    except ProcessLookupError:pass
    time.sleep(1)
  cleanup['residual_after_cleanup']=[r for r in processes() if r['pgid']==group['pgid']]
 current=sim();cleanup['simulator_before_shutdown']=current
 if current['state']!='Shutdown':
  stop=subprocess.run(['xcrun','simctl','shutdown',UDID],capture_output=True,text=True,timeout=30)
  cleanup['shutdown']={'exit':stop.returncode,'stderr':stop.stderr}
 cleanup['simulator_after_shutdown']=sim()
 save('cleanup.json',cleanup)
 save('after-hashes.json',hashes())
 result={'test_exit':rc,'elapsed_s':round(time.monotonic()-start,3),'hashes_match':True,'owned_processes_remaining':len(cleanup.get('residual_after_cleanup',[])),'simulator_shutdown':cleanup['simulator_after_shutdown']['state']=='Shutdown'}
 save('result.json',result);print(json.dumps(result,indent=2))
assert result['owned_processes_remaining']==0 and result['simulator_shutdown'],result
raise SystemExit(rc)
