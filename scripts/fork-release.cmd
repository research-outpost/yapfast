@echo off
rem Builds this fork's Windows release: the program, then the Inno Setup installer.
rem
rem   scripts\fork-release.cmd 0.5.0-fork.10
rem
rem The version names the tag the release will carry. Fork releases count up from
rem the upstream release they grew from, and the -fork.N tail keeps them sorting
rem above it: a bare 0.5.0-fork.N reads as a prerelease unless src/build_info.rs
rem names it Stable, which it does for "-fork.".
rem
rem The build sets YAPFAST_RELEASE, which is what makes Settings and --version
rem call this a release, and YAPFAST_VERSION, the tag's version, because
rem Cargo.toml stays at the upstream release. This script checks that it took.
setlocal enabledelayedexpansion

set VERSION=%~1
if "%VERSION%"=="" (
  echo usage: scripts\fork-release.cmd ^<0.5.0-fork.N^>
  exit /b 2
)
for /f "tokens=1 delims=-" %%v in ("%VERSION%") do set NUMVER=%%v

set ROOT=%~dp0..
set PATH=%USERPROFILE%\.cargo\bin;X:\Dev\tools\inno;X:\Dev\tools\llvm\bin;X:\Dev\tools\ninja;X:\Dev\tools\nasm;%PATH%
rem ffmpeg-src builds with clang-cl, and bindgen and thorvg want libclang
set LIBCLANG_PATH=X:\Dev\tools\llvm\bin
set YAPFAST_RELEASE=1
set YAPFAST_VERSION=%VERSION%

cd /d "%ROOT%"
echo Building %VERSION% as a release...
cargo build --release
if errorlevel 1 exit /b 1

for /f "delims=" %%l in ('target\release\yapfast.exe --version') do set BUILT=%%l
echo   %BUILT%
echo %BUILT% | "%SystemRoot%\System32\findstr.exe" /C:"Stable" >nul
if errorlevel 1 (
  echo It does not call itself a release, so About would never offer an update.
  exit /b 1
)
echo %BUILT% | "%SystemRoot%\System32\findstr.exe" /C:"%VERSION%" >nul
if errorlevel 1 (
  echo It does not name %VERSION%, so About would compare the wrong version.
  exit /b 1
)

set STAGE=%ROOT%\dist\Yapfast-%VERSION%
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%" 2>nul
copy /y "%ROOT%\target\release\yapfast.exe" "%STAGE%\" >nul
copy /y "%ROOT%\LICENSE" "%STAGE%\LICENSE.txt" >nul
> "%STAGE%\run-yapfast.cmd" (echo @echo off^& echo cd /d "%%~dp0"^& echo yapfast.exe %%*^& echo if errorlevel 1 pause)
> "%STAGE%\SOURCE.txt" echo Yapfast %VERSION%, a selective fork of Yapfast %NUMVER%.
>> "%STAGE%\SOURCE.txt" echo https://github.com/research-outpost/yapfast/tree/v%VERSION%
>> "%STAGE%\SOURCE.txt" echo Built from that tag on Windows; GPL-3.0, see LICENSE.txt.

echo Making the installer...
ISCC.exe /Q /O"%ROOT%\dist" /DAppVersion=%VERSION% /DVersionNumber=%NUMVER% /DSourceDir=%STAGE% /DLicenseFile=%ROOT%\LICENSE packaging\windows\yapfast.iss
if errorlevel 1 exit /b 1

rem The updater installs only releases whose SHA256SUMS.txt carries this fork's
rem minisign signature (src/update/signature.rs, packaging/keys\*.pub). The
rem trusted comment must read exactly: yapfast v<VERSION> SHA256SUMS.txt.
rem This asks for the passphrase of keys\stable.key; keep its backup offline.
set DIST=%ROOT%\dist
copy /y "%STAGE%\yapfast.exe" "%DIST%\Yapfast-%VERSION%-windows-x64.exe" >nul
echo Summing the release...
powershell -NoProfile -Command "Get-FileHash -Algorithm SHA256 '%DIST%\Yapfast-%VERSION%-windows-x64-setup.exe','%DIST%\Yapfast-%VERSION%-windows-x64.exe' | ForEach-Object { ('{0}  {1}' -f $_.Hash.ToLower(), (Split-Path -Leaf $_.Path)) } | Set-Content -Encoding ascii '%DIST%\SHA256SUMS.txt'"
if errorlevel 1 exit /b 1
echo Signing the sums (keys\stable.key; asks for its passphrase)...
set MINISIGN=X:\Dev\tools\minisign\minisign-win64\x86_64\minisign.exe
"%MINISIGN%" -S -s "%ROOT%\keys\stable.key" -m "%DIST%\SHA256SUMS.txt" -t "yapfast v%VERSION% SHA256SUMS.txt" -c "Yapfast %VERSION%"
if errorlevel 1 exit /b 1
"%MINISIGN%" -V -q -p "%ROOT%\packaging\keys\stable.pub" -m "%DIST%\SHA256SUMS.txt" -x "%DIST%\SHA256SUMS.txt.minisig"
if errorlevel 1 (echo signing key does not match the pub keys in the app & exit /b 1)

echo.
echo Built:
echo   %STAGE%\yapfast.exe
echo   %ROOT%\dist\Yapfast-%VERSION%-windows-x64-setup.exe
echo   %ROOT%\dist\Yapfast-%VERSION%-windows-x64.exe
echo   %ROOT%\dist\SHA256SUMS.txt + .minisig
echo.
echo To publish it:
echo   git tag -a v%VERSION% -m "Yapfast %VERSION%"
echo   git push gh refs/tags/v%VERSION%
echo   gh release create v%VERSION% -R research-outpost/yapfast "%ROOT%\dist\Yapfast-%VERSION%-windows-x64-setup.exe" "%DIST%\Yapfast-%VERSION%-windows-x64.exe" "%DIST%\SHA256SUMS.txt" "%DIST%\SHA256SUMS.txt.minisig"
endlocal
