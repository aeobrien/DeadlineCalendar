"""Send only the prepared source/synthetic package through the normal review path."""
import json,sys,hashlib
from pathlib import Path
sys.path.insert(0,'/Users/aidan/.claude/lib')
from openrouter_client import OpenRouterClient
HERE=Path(__file__).resolve().parent;raw=(HERE/'fable-package-03.json').read_bytes();p=json.loads(raw);out=HERE/'fable-03';out.mkdir(exist_ok=False)
r=OpenRouterClient(logs_dir=out/'raw',budget_usd=p['budget_usd']).call(model=p['model'],system=p['system'],user=p['user'],max_tokens=p['max_tokens'],reasoning={'effort':'low'},temperature=0,read_timeout_s=180)
(out/'review.md').write_text(r.response_text+'\n');(out/'receipt.json').write_text(json.dumps({'package_sha256':hashlib.sha256(raw).hexdigest(),'model':p['model'],'source_hashes':p['hashes'],'executed_tests':False,'visible_review':bool(r.response_text.strip())},indent=2)+'\n');print(r.response_text or 'INCOMPLETE: no visible review')
