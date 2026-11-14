"""Supplemental native execution of the exact ViewModel class; not iOS UI proof."""
from pathlib import Path
import hashlib,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
source=(ROOT/'DeadlineCalendar/ContentView.swift').read_text()
viewmodel=source.split('// MARK: - ShakeEffect (Generic Animation)')[0]
assert viewmodel.count('class DeadlineViewModel:')==1
print('Source SHA256:',hashlib.sha256(source.encode()).hexdigest(),flush=True)
with tempfile.TemporaryDirectory() as tmp:
 tmp=Path(tmp);vm=tmp/'ViewModel.swift';vm.write_text(viewmodel)
 stub=tmp/'DisabledBackup.swift';stub.write_text('''import Foundation
final class iCloudBackupManager {
 static var shared:iCloudBackupManager {fatalError("Backup must not run in fixture")}
 var iCloudAvailable:Bool {fatalError("Backup must not run")}
 var lastBackupDate:Date? {fatalError("Backup must not run")}
 func createBackup(projects:[Project],templates:[Template],triggers:[Trigger],appSettings:AppSettings) async throws {fatalError("Backup must not run")}
}
''')
 binary=tmp/'legacy-probe'
 subprocess.run(['swiftc',str(ROOT/'Models.swift'),str(ROOT/'deadline-cli/Sources/SnapshotFile.swift'),str(ROOT/'DeadlineCalendar/SharedDataStore.swift'),str(vm),str(stub),str(ROOT/'reports/session-storage/legacy_probe.swift'),'-o',str(binary)],check=True)
 raise SystemExit(subprocess.run([str(binary)]).returncode)
