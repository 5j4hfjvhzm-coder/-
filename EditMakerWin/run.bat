@echo off
rem Run from source (needs Python 3.10+)
cd /d "%~dp0"
python -m pip install -q -r requirements.txt
python app.py
