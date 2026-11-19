@echo off
rem Builds this fork's Windows release: the program, then the Inno Setup installer.
rem
rem   scripts\fork-release.cmd 0.3.1-fork.2
rem
rem The version names the tag the release will carry. Fork releases count from
rem 0.3.1 so they sort above the upstream 0.3.0 this fork grew from: 0.3.0-fork.N
rem reads as a prerelease and About would never offer it (src/update.rs).
rem
rem The build sets YAPFAST_RELEASE, which is what makes Settings and --version
rem call this a release (src/build_info.rs) and lets About compare it with the
rem releases listed on GitHub. This script checks that it did.
setlocal enabledelayedexpansion

set VERSION=%~1
if "%VERSION%"=="" (
  echo usage: scripts\fork-release.cmd ^<0.3.1-fork.N^>
  exit /b 2
)
for /f "tokens=1 delims=-" %%v in ("%VERSION%") do set NUMVER=%%v

set ROOT=%~dp0..
set PATH=%USERPROFILE%\.cargo\bin;X:\Dev\tools\nasm;X:\Dev\tools\llvm\bin;X:\Dev\tools\ninja;X:\Dev\tools\inno;%PATH%
rem NASM must stay out of the environment: it re-fingerprints skia-bindings
set LIBCLANG_PATH=X:\Dev\tools\llvm\bin
rem The repacked Skia archive: exactly two slashes, forward ones, or cargo
rem silently falls back to a source build (scripts\prepare-windows-skia.py).
set SKIA_BINARIES_URL=file://%ROOT%\.local\windows\skia\prepared\skia-binaries-b7f043e0b1e2a850e702-x86_64-pc-windows-msvc-d3d-ganesh-gl-jpegd-jpege-pdf-static.tar.gz
set SKIA_BINARIES_URL=%SKIA_BINARIES_URL:\=/%
set YAPFAST_RELEASE=1
rem The tag's version, so About compares itself with this fork's releases
rem instead of the 0.3.0 that Cargo.toml still says (src/build_info.rs).
set YAPFAST_VERSION=%VERSION%

cd /d "%ROOT%"
rem Skia's bundled libjpeg and libwebrtc's both define jpeg_natural_order,
rem which the linker refuses (LNK2005/LNK1169); scripts\prepare-windows-skia.py
rem renames it in the archive, and this does the same to a Skia that was built
rem from source instead. Naming an already-renamed symbol is an error, hence 2>nul.
for /d %%d in (target\release\build\skia-bindings-*) do (
  if exist "%%d\out\skia\skia.lib" "X:\Dev\tools\llvm\bin\llvm-objcopy.exe" --redefine-sym jpeg_natural_order=yapfast_skia_jpeg_natural_order "%%d\out\skia\skia.lib" 2>nul
  if exist "%%d\out\skia\skia-bindings.lib" "X:\Dev\tools\llvm\bin\llvm-objcopy.exe" --redefine-sym jpeg_natural_order=yapfast_skia_jpeg_natural_order "%%d\out\skia\skia-bindings.lib" 2>nul
)
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

set STAGE=%ROOT%\dist\Yapfast-%VERSION%
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%\licenses" 2>nul
copy /y "%ROOT%\target\release\yapfast.exe" "%STAGE%\" >nul
copy /y "%ROOT%\LICENSE" "%STAGE%\LICENSE.txt" >nul
> "%STAGE%\run-yapfast.cmd" echo @echo off
>> "%STAGE%\run-yapfast.cmd" echo cd /d "%%~dp0"
>> "%STAGE%\run-yapfast.cmd" echo yapfast.exe %%*
>> "%STAGE%\run-yapfast.cmd" echo if errorlevel 1 pause
> "%STAGE%\SOURCE.txt" echo Yapfast %VERSION%, a selective fork of Yapfast 0.3.0.
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
