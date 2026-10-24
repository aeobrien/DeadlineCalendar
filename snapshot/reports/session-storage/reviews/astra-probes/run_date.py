from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[4]
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'probe'
 subprocess.run(['swiftc',str(root/'deadline-cli/Sources/Models.swift'),str(root/'deadline-cli/Sources/SnapshotFile.swift'),str(root/'DeadlineCalendar/SharedDataStore.swift'),str(Path(__file__).with_name('DateNoop.swift')),'-o',str(p)],check=True)
 raise SystemExit(subprocess.run([str(p)]).returncode)
