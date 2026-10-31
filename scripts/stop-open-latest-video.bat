@echo off
setlocal
set "PY=C:\Users\pc\AppData\Local\Programs\Python\Python313\python.exe"
set "SCRIPT=E:\mm3\scripts\open_latest_video.py"

"%PY%" "%SCRIPT%" --stop
ping -n 4 127.0.0.1 >nul
