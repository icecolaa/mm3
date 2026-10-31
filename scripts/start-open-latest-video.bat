@echo off
setlocal
set "PY=C:\Users\pc\AppData\Local\Programs\Python\Python313\python.exe"
set "PYW=C:\Users\pc\AppData\Local\Programs\Python\Python313\pythonw.exe"
set "SCRIPT=E:\mm3\scripts\open_latest_video.py"

"%PY%" -c "import socket,sys; s=socket.socket(); sys.exit(0 if s.connect_ex(('127.0.0.1',47831))==0 else 1)" >nul 2>&1
if not errorlevel 1 (
  echo 后台监听已经在运行，无需重复启动。
  ping -n 4 127.0.0.1 >nul
  exit /b 0
)

start "" "%PYW%" "%SCRIPT%"
echo 已启动后台监听：ComfyUI 生成的新 MP4 会用系统默认播放器自动打开。
echo 日志：E:\mm3\scripts\logs\open-latest-video.log
echo 停止监听：双击 stop-open-latest-video.bat
ping -n 5 127.0.0.1 >nul
