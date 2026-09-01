@echo off
setlocal
set "ROOT=%APPDATA%\Claude\claude-code"
set "EXE="
for /f "delims=" %%d in ('dir /b /ad /o-d "%ROOT%" 2^>nul') do (
  if not defined EXE if exist "%ROOT%\%%d\claude.exe" set "EXE=%ROOT%\%%d\claude.exe"
)
if not defined EXE (
  echo [cc] claude.exe nahi mila: "%ROOT%"
  exit /b 1
)
"%EXE%" %*
