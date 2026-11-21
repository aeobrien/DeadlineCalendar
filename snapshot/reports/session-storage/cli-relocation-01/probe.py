"""Relocate an existing artifact; this cannot certify an unrecorded compilation."""
import hashlib, importlib.util, json, os, pathlib, shutil, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[3]
OUT=pathlib.Path(__file__).resolve().parent
manifest=json.loads((ROOT/'reports/session-storage/candidate-hashes-03.json').read_text())['files']
prior=json.loads((ROOT/'reports/session-storage/candidate-hashes-01.json').read_text())['files']
subset={f:h for f,h in manifest.items() if f.startswith('deadline-cli/')}
for f,h in subset.items():
 assert hashlib.sha256((ROOT/f).read_bytes()).hexdigest()==h, f
 assert prior.get(f)==h, f
binary=ROOT/'deadline-cli/.build/debug/deadline-cli'
binary_hash=hashlib.sha256(binary.read_bytes()).hexdigest()
expected=json.loads((ROOT/'reports/session-storage/rollout-plan/metadata-01.json').read_text())['candidate_binary_sha256']
assert binary_hash==expected
provenance={'binary_sha256':binary_hash,'source_subset':subset,'same_subset_as_candidate01':True,'binary_matches_prior_metadata':True,'source_files':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'deadline-cli/Sources').glob('*.swift')},'limitation':'Earlier successful compilation receipt has no binary digest. This run proves the recorded existing artifact and current unchanged CLI source subset separately; it does not cryptographically attest that this binary was compiled from that subset. No recompile, release install, final app acceptance or default-store access is claimed.'}
(OUT/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
spec=importlib.util.spec_from_file_location('retained_fixture',ROOT/'reports/session-storage/cli_probe.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
commands=[]
with tempfile.TemporaryDirectory(prefix='deadline-cli-relocated-') as tmp:
 target=pathlib.Path(tmp)/'portable-cli';shutil.copy2(binary,target)
 assert hashlib.sha256(target.read_bytes()).hexdigest()==binary_hash
 fixture.BIN=target
 os.chdir(tmp)
 original=fixture.CLI.call
 def call(self,*args,**kwargs):
  q=original(self,*args,**kwargs)
  commands.append({'argv':[str(target),*args,'--data-file',str(self.file)],'cwd':tmp,'exit_code':q.returncode,'stdout':q.stdout,'stderr':q.stderr})
  return q
 fixture.CLI.call=call
 cases=['test_full_exact_id_crud_and_retries','test_add_without_approval_preserves_file','test_stale_delete_preview_refuses','test_wrong_target_and_bad_date_preserve_file','test_missing_corrupt_and_unapproved_delete_do_not_write','test_delete_keeps_recurrence_siblings_and_repeated_delete_is_noop']
 result=unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(fixture.CLI(n) for n in cases))
 assert all('--data-file' in c['argv'] for c in commands)
 (OUT/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
 (OUT/'summary.json').write_text(json.dumps({'tests_run':result.testsRun,'success':result.wasSuccessful(),'failures':len(result.failures),'errors':len(result.errors),'actual_cli_calls':len(commands),'all_explicit_synthetic_store':True,'copied_binary_sha256':binary_hash,'source_checkout_is_not_cwd':tmp!=str(ROOT)},indent=2)+'\n')
 os.chdir(ROOT)
 raise SystemExit(0 if result.wasSuccessful() else 1)
