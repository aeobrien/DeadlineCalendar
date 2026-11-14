"""Run only the injected fixture XCTest target and verify its actual result count."""
import argparse,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--evidence',required=True);p.add_argument('--expected-tests',type=int,required=True);p.add_argument('--only',action='append',default=[]);a=p.parse_args()
out=Path(a.evidence).resolve();out.mkdir(parents=True,exist_ok=False)
result=out/'tests.xcresult'
command=['xcodebuild','-quiet','-project','DeadlineCalendar.xcodeproj','-scheme','Deadline Calendar','-destination','platform=iOS Simulator,id=DDCF7C0E-E17C-47E3-9FB9-43DC69B7970F','-derivedDataPath','/private/tmp/deadline-storage-derived','-resultBundlePath',str(result)]
command += ['-only-testing:Deadline CalendarTests'+('/Deadline_CalendarTests/'+name if name else '') for name in (a.only or [''])]
command += ['test','CODE_SIGNING_ALLOWED=NO']
(out/'argv.json').write_text(json.dumps(command,indent=2)+'\n')
run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
(out/'stdout.log').write_text(run.stdout);(out/'stderr.log').write_text(run.stderr)
summary=subprocess.run(['xcrun','xcresulttool','get','test-results','summary','--path',str(result),'--format','json'],capture_output=True,text=True)
(out/'summary-stderr.log').write_text(summary.stderr)
if summary.returncode:
 print(run.stderr[-2000:]);print(summary.stderr);raise SystemExit(run.returncode or summary.returncode)
data=json.loads(summary.stdout);(out/'summary.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps({k:data.get(k) for k in ['result','totalTestCount','passedTests','failedTests','skippedTests','testFailures']},indent=2))
assert data['totalTestCount']==a.expected_tests, data
assert data['passedTests']==a.expected_tests and data['failedTests']==0 and data['skippedTests']==0,data
raise SystemExit(run.returncode)
