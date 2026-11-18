@echo off
rem Signs dist\SHA256SUMS.txt for the version given (default 0.3.1-fork.4)
rem with keys\stable.key. Run it, type the key's passphrase when asked, done.
rem   scripts\sign-fork-now.cmd 0.3.1-fork.5
setlocal
set VERSION=%~1
if "%VERSION%"=="" set VERSION=0.3.1-fork.4
cd /d "%~dp0.."
set MS=%LOCALAPPDATA%\Microsoft\WinGet\Links\minisign.exe
echo Signing dist\SHA256SUMS.txt for v%VERSION% (type the passphrase of keys\stable.key)...
"%MS%" -S -s "keys\stable.key" -m "dist\SHA256SUMS.txt" -t "yapfast v%VERSION% SHA256SUMS.txt" -c "Yapfast %VERSION%"
if errorlevel 1 (echo SIGN FAILED & pause & exit /b 1)
"%MS%" -V -p "packaging\keys\stable.pub" -m "dist\SHA256SUMS.txt" -x "dist\SHA256SUMS.txt.minisig"
if errorlevel 1 (echo the signature does NOT match the pub key in the app & pause & exit /b 1)
echo Signed and verified against packaging\keys\stable.pub. You can close this window.
pause
