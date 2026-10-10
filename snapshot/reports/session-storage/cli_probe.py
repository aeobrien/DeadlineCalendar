import json,subprocess,tempfile,uuid,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BIN=ROOT/'deadline-cli/.build/debug/deadline-cli'
PID='00000000-0000-0000-0000-000000000001';DID='33333333-3333-4333-8333-333333333333'
class CLI(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.file=Path(self.tmp.name)/'fixture.json'
  settings={'colorSettings':{'greenThreshold':21,'orangeThreshold':7,'redThreshold':0},'notificationFormatSettings':{'titleFormat':'Upcoming','itemFormat':'{title}','showProjectName':True,'showDate':False,'dateFormat':'MMM d','maxItems':3}}
  self.file.write_text(json.dumps({'projects':[{'id':PID,'title':'Standalone Deadlines','finalDeadlineDate':'2030-01-01T00:00:00Z','subDeadlines':[],'triggers':[]}],'templates':[],'triggers':[],'appSettings':settings,'lastModified':'2026-01-01T00:00:00Z','lastModifiedBy':'fixture'}))
 def tearDown(self):self.tmp.cleanup()
 def call(self,*args,ok=True):
  q=subprocess.run([str(BIN),*args,'--data-file',str(self.file)],capture_output=True,text=True,timeout=10)
  if ok:self.assertEqual(q.returncode,0,q.stderr)
  else:self.assertNotEqual(q.returncode,0,q.stdout)
  return q
 def add(self,approved=True):return self.call('add','Synthetic','--date','2030-02-01','--project-id',PID,'--id',DID,*(['--approved'] if approved else []),ok=approved)
 def test_full_exact_id_crud_and_retries(self):
  self.add();self.add();doc=json.loads(self.call('export').stdout);self.assertEqual(len(doc['projects'][0]['subDeadlines']),1)
  self.call('update','--project-id',PID,'--deadline-id',DID,'--title','Revised','--completed','true')
  doc=json.loads(self.call('export').stdout);self.assertTrue(doc['projects'][0]['subDeadlines'][0]['isCompleted'])
  preview=json.loads(self.call('delete','--project-id',PID,'--deadline-id',DID,'--preview').stdout)
  self.call('delete','--project-id',PID,'--deadline-id',DID,'--revision',preview['revision'],'--approved')
  self.assertEqual(json.loads(self.call('export').stdout)['projects'][0]['subDeadlines'],[])
 def test_add_without_approval_preserves_file(self):
  before=self.file.read_bytes();self.add(False);self.assertEqual(self.file.read_bytes(),before)
 def test_wrong_target_and_bad_date_preserve_file(self):
  self.add();before=self.file.read_bytes()
  self.call('update','--project-id',PID,'--deadline-id',str(uuid.uuid4()),'--title','Wrong',ok=False)
  self.call('add','Invalid','--date','2030-02-31','--approved',ok=False)
  self.assertEqual(self.file.read_bytes(),before)
 def test_stale_delete_preview_refuses(self):
  self.add();p=json.loads(self.call('delete','--project-id',PID,'--deadline-id',DID,'--preview').stdout)
  self.call('update','--project-id',PID,'--deadline-id',DID,'--title','Changed')
  before=self.file.read_bytes();self.call('delete','--project-id',PID,'--deadline-id',DID,'--revision',p['revision'],'--approved',ok=False);self.assertEqual(self.file.read_bytes(),before)
 def test_read_commands_keep_human_default_and_machine_json(self):
  self.add();self.assertIn('Standalone Deadlines',self.call('list').stdout)
  self.assertEqual(len(json.loads(self.call('list','--json').stdout)),1)
  self.assertIn('All clear',self.call('status').stdout)
  self.assertEqual(json.loads(self.call('status','--json').stdout),[])
  self.assertEqual(json.loads(self.call('export').stdout)['lastModifiedBy'],'cli')
 def test_empty_existing_store_can_add_standalone(self):
  doc=json.loads(self.file.read_text());doc['projects']=[];self.file.write_text(json.dumps(doc))
  self.call('add','First','--date','2030-02-01','--id',DID,'--approved')
  doc=json.loads(self.call('export').stdout);self.assertEqual(doc['projects'][0]['id'].lower(),PID);self.assertEqual(len(doc['projects'][0]['subDeadlines']),1)
 def test_concurrent_independent_adds_survive(self):
  jobs=[];ids=[str(uuid.uuid4()) for _ in range(8)]
  for index,record_id in enumerate(ids):
   jobs.append(subprocess.Popen([str(BIN),'add',f'Parallel {index}','--date','2030-02-01','--project-id',PID,'--id',record_id,'--approved','--data-file',str(self.file)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True))
  for job in jobs:
   out,err=job.communicate(timeout=20);self.assertEqual(job.returncode,0,err)
  doc=json.loads(self.call('export').stdout);self.assertEqual({d['id'].lower() for d in doc['projects'][0]['subDeadlines']},set(ids))
 def test_ambiguous_titles_duplicate_ids_and_conflicting_repeat_do_not_write(self):
  self.add();doc=json.loads(self.file.read_text());d=dict(doc['projects'][0]['subDeadlines'][0]);d['id']=str(uuid.uuid4());doc['projects'][0]['subDeadlines'].append(d);self.file.write_text(json.dumps(doc));before=self.file.read_bytes()
  self.call('complete','Standalone','Synthetic',ok=False)
  self.call('add','Different','--date','2030-02-01','--id',DID,'--approved',ok=False)
  self.assertEqual(self.file.read_bytes(),before)
  doc['projects'][0]['subDeadlines'][1]['id']=DID;self.file.write_text(json.dumps(doc));before=self.file.read_bytes()
  self.call('update','--project-id',PID,'--deadline-id',DID,'--title','Wrong',ok=False)
  self.assertEqual(self.file.read_bytes(),before)
 def test_delete_keeps_recurrence_siblings_and_repeated_delete_is_noop(self):
  self.add();doc=json.loads(self.file.read_text());d=dict(doc['projects'][0]['subDeadlines'][0]);d['id']=str(uuid.uuid4());d['repetitionSourceID']=DID;doc['projects'][0]['subDeadlines'].append(d);self.file.write_text(json.dumps(doc))
  p=json.loads(self.call('delete','--project-id',PID,'--deadline-id',DID,'--preview').stdout)
  self.call('delete','--project-id',PID,'--deadline-id',DID,'--revision',p['revision'],'--approved')
  before=self.file.read_bytes();self.call('delete','--project-id',PID,'--deadline-id',DID,'--revision',p['revision'],'--approved');self.assertEqual(self.file.read_bytes(),before)
  self.assertEqual(len(json.loads(before)['projects'][0]['subDeadlines']),1)
 def test_missing_corrupt_and_unapproved_delete_do_not_write(self):
  self.add();before=self.file.read_bytes();self.call('delete','--project-id',PID,'--deadline-id',DID,ok=False);self.assertEqual(before,self.file.read_bytes())
  self.file.write_text('broken');self.call('add','No','--date','2030-02-01','--approved',ok=False);self.assertEqual(self.file.read_text(),'broken')
  self.file.unlink();self.call('add','No','--date','2030-02-01','--approved',ok=False);self.assertFalse(self.file.exists())
if __name__=='__main__':unittest.main()
