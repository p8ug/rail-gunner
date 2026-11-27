@echo off
setlocal DisableDelayedExpansion
pushd "%~dp0" || exit /b 1
set "P8ROOT=%CD%\tools\windows\p8p8"
set "PATH=%CD%\tools\windows\64tass;%PATH%"
if not exist "build\" mkdir "build" || goto failed
"%P8ROOT%\bin\p8c.exe" -lib "%P8ROOT%\lib\p8p8" -target cx16 -out build ionbreak.p8
if errorlevel 1 goto failed
copy /y "build\ionbreak.prg" "build\RAILGUN.PRG" >nul || goto failed
echo Built build\RAILGUN.PRG
popd
exit /b 0
:failed
popd
exit /b 1
