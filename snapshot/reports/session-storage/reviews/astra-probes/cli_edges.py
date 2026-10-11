import importlib.util,json,subprocess,unittest,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location('fixture',ROOT/'reports/session-storage/cli_probe.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
class Edges(unittest.TestCase):
 def setUp(self):
  self.f=fixture.CLI(); self.f.setUp()
 def tearDown(self):self.f.tearDown()
 def test_reused_deleted_id_cannot_use_old_approval(self):
  f=self.f;f.add();p=json.loads(f.call('delete','--project-id',fixture.PID,'--deadline-id',fixture.DID,'--preview').stdout)
  f.call('delete','--project-id',fixture.PID,'--deadline-id',fixture.DID,'--revision',p['revision'],'--approved')
  f.call('add','Replacement content','--date','2031-01-01','--id',fixture.DID,'--approved')
  before=f.file.read_bytes();f.call('delete','--project-id',fixture.PID,'--deadline-id',fixture.DID,'--revision',p['revision'],'--approved',ok=False)
  self.assertEqual(before,f.file.read_bytes())
 def test_identical_concurrent_retries_create_one_record(self):
  f=self.f;args=[str(fixture.BIN),'add','Same','--date','2030-02-01','--project-id',fixture.PID,'--id',fixture.DID,'--approved','--data-file',str(f.file)]
  jobs=[subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for _ in range(3)]
  for job in jobs:
   out,err=job.communicate(timeout=20);self.assertEqual(job.returncode,0,err)
  self.assertEqual(len(json.loads(f.file.read_bytes())['projects'][0]['subDeadlines']),1)
 def test_duplicate_project_ids_refuse_all_exact_mutations(self):
  f=self.f;f.add();doc=json.loads(f.file.read_bytes());doc['projects'].append(dict(doc['projects'][0]));f.file.write_text(json.dumps(doc));before=f.file.read_bytes()
  f.call('update','--project-id',fixture.PID,'--deadline-id',fixture.DID,'--title','Wrong',ok=False)
  f.call('delete','--project-id',fixture.PID,'--deadline-id',fixture.DID,'--preview',ok=False)
  self.assertEqual(before,f.file.read_bytes())
 def test_symlinked_store_never_follows_target(self):
  f=self.f;target=f.file.with_name('original.json');f.file.rename(target);before=target.read_bytes();f.file.symlink_to(target)
  f.call('export',ok=False);f.call('add','Forbidden','--date','2030-02-01','--approved',ok=False)
  self.assertEqual(before,target.read_bytes());self.assertTrue(f.file.is_symlink())
if __name__=='__main__':unittest.main()
