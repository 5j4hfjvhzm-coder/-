@echo off
rem Build EditMaker.exe (needs Python 3.10+). Output: dist\EditMaker.exe
cd /d "%~dp0"
python -m pip install -q -r requirements.txt pyinstaller
pyinstaller --noconfirm --onefile --windowed --name EditMaker --icon ui\icon.ico ^
  --add-data "ui;ui" --add-data "editmaker\ae_template.jsx;editmaker" ^
  --collect-data imageio_ffmpeg --collect-all webview app.py
