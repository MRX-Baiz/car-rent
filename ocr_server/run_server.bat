@echo off
set PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python313\python.exe
if not exist "%PYTHON_EXE%" set PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python312\python.exe
if not exist "%PYTHON_EXE%" set PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python311\python.exe
if not exist "%PYTHON_EXE%" (
    echo Python introuvable. Installez Python depuis python.org
    pause
    exit /b 1
)

cd /d "%~dp0"
echo Installation des dependances...
"%PYTHON_EXE%" -m pip install -r requirements.txt -q
echo Demarrage du serveur OCR...
"%PYTHON_EXE%" server.py
pause
