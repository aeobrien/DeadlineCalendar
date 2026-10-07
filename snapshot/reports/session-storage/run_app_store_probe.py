import pathlib, subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as folder:
 binary=pathlib.Path(folder)/'app-store-probe'
 subprocess.run(['swiftc',str(root/'deadline-cli/Sources/Models.swift'),str(root/'deadline-cli/Sources/SnapshotFile.swift'),str(root/'DeadlineCalendar/SharedDataStore.swift'),str(root/'reports/session-storage/app_store_probe.swift'),'-o',str(binary)],check=True)
 subprocess.run([str(binary),str(root/'deadline-cli/.build/debug/deadline-cli')],check=True)
