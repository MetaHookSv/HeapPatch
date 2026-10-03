@echo off
setlocal
set "Configuration=Debug"
call "%~dp0build-HeapPatch-x86.bat" %*
exit /b %errorlevel%
