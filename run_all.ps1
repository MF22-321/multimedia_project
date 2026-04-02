$projectRoot = "/home/febrian/development/multimedia_project"
$flutterRoot = "/home/febrian/development/multimedia_project/frontend"

Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot'; .\.drwosy\Scripts\python.exe -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000 --reload"

Start-Sleep -Seconds 2

Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$flutterRoot'; flutter run -d linux"
