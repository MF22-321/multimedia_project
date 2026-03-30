$projectRoot = "D:\A_Office\TMMIN\multimedia_project"
$flutterRoot = "D:\A_Office\TMMIN\multimedia_project\Face_Drowsiness_project\frontend_face_drowsiness"

Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$projectRoot'; .\.venv311\Scripts\python.exe -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000 --reload"

Start-Sleep -Seconds 2

Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$flutterRoot'; flutter run -d windows"
