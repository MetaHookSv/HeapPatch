@echo off
setlocal
set "Configuration=Release"
call "%~dp0build-HeapPatch-x86.bat" %*
exit /b %errorlevel%
