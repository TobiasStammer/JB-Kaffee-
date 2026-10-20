@echo off
cd /d "%~dp0"
py -m pip install -q flask
start "" http://127.0.0.1:5055
py app.py
pause
