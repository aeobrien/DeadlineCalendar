import os,json,runpy,sys
from pathlib import Path
p=Path('/Users/aidan/Dev/DeadlineCalendar-session-storage/reports/session-storage/root-resume-20261006/owned-group.json')
p.write_text(json.dumps({'pid':os.getpid(),'pgid':os.getpgrp()}))
sys.argv=['run_ios_tests.py','--evidence','/Users/aidan/Dev/DeadlineCalendar-session-storage/reports/session-storage/root-resume-20261006/ios-01','--expected-tests','14']
runpy.run_path('/Users/aidan/Dev/DeadlineCalendar-session-storage/reports/session-storage/run_ios_tests.py',run_name='__main__')
