"""Invoke the existing autonomy completion path for this original build only."""
import importlib.machinery,importlib.util,json,sys
from pathlib import Path
p=Path('/Users/aidan/.claude/bin/autonomy')
loader=importlib.machinery.SourceFileLoader('original_autonomy_completion',str(p));spec=importlib.util.spec_from_loader(loader.name,loader);module=importlib.util.module_from_spec(spec);loader.exec_module(module)
sentinel=Path('/Users/aidan/.claude/autonomy/active-01a0fcb2-7788-7d21-9627-c24c34f60149-deadline-storage.json')
state=json.loads(sentinel.read_text());assert state['build_id']=='0ce3c0c89cab1aeb1740'
sys.path.insert(0,'/Users/aidan/.claude/bin');import done_gate
code,report=module._gate_check_build_mode(state,done_gate,state['manifest'],state['repo'])
result={'exit_code':code,'report':str(report),'build_id':state['build_id'],'manifest':state['manifest']}
Path(sys.argv[1] if len(sys.argv)>1 else 'reports/session-storage/root-resume-20261006/canonical-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));raise SystemExit(code)
