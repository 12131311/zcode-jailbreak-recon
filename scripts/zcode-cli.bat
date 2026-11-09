@echo off
rem ---------------------------------------------------------------------------
rem zcode-cli.bat - run the ZCode engine from the command line.
rem
rem Same zcode.cjs the desktop app uses, so the same prompt-layer patches apply,
rem but the request does not go through the desktop account gate
rem (provider account:<plan>), which is the channel that answers
rem "request has been blocked due to unusual activity".
rem
rem Usage:
rem   zcode-cli -p "your prompt"
rem   zcode-cli -p "your prompt" --cwd D:\some\project
rem   zcode-cli                      (no args = interactive TUI)
rem
rem Locating the engine, in order:
rem   1. %ZCODE_ENGINE%  (a zcode.cjs path, or a ZCode install dir)
rem   2. %ZCODE_DIR%\resources\glm\zcode.cjs
rem   3. %LOCALAPPDATA%\Programs\ZCode\resources\glm\zcode.cjs
rem   4. %ProgramFiles%\ZCode\resources\glm\zcode.cjs
rem   5. <drive>:\zcode\resources\glm\zcode.cjs  for C: D: E: F:
rem Override with:  set ZCODE_ENGINE=D:\apps\ZCode
rem ---------------------------------------------------------------------------
setlocal

set "ELECTRON_RUN_AS_NODE=1"

rem ---- node ----------------------------------------------------------------
set "NODE_EXE="
for /f "delims=" %%N in ('where node.exe 2^>nul') do if not defined NODE_EXE set "NODE_EXE=%%N"
if not defined NODE_EXE if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
if not defined NODE_EXE if exist "%LOCALAPPDATA%\Programs\nodejs\node.exe" set "NODE_EXE=%LOCALAPPDATA%\Programs\nodejs\node.exe"
if not defined NODE_EXE (
  echo [zcode-cli] node.exe not found. Install Node.js 18+ or put it on PATH.
  exit /b 1
)

rem ---- engine --------------------------------------------------------------
set "ENGINE="
if defined ZCODE_ENGINE if exist "%ZCODE_ENGINE%" set "ENGINE=%ZCODE_ENGINE%"
if not defined ENGINE if defined ZCODE_ENGINE if exist "%ZCODE_ENGINE%\resources\glm\zcode.cjs" set "ENGINE=%ZCODE_ENGINE%\resources\glm\zcode.cjs"
if not defined ENGINE if defined ZCODE_DIR if exist "%ZCODE_DIR%\resources\glm\zcode.cjs" set "ENGINE=%ZCODE_DIR%\resources\glm\zcode.cjs"
if not defined ENGINE if exist "%LOCALAPPDATA%\Programs\ZCode\resources\glm\zcode.cjs" set "ENGINE=%LOCALAPPDATA%\Programs\ZCode\resources\glm\zcode.cjs"
if not defined ENGINE if exist "%ProgramFiles%\ZCode\resources\glm\zcode.cjs" set "ENGINE=%ProgramFiles%\ZCode\resources\glm\zcode.cjs"
if not defined ENGINE if exist "F:\zcode\resources\glm\zcode.cjs" set "ENGINE=F:\zcode\resources\glm\zcode.cjs"
if not defined ENGINE if exist "E:\zcode\resources\glm\zcode.cjs" set "ENGINE=E:\zcode\resources\glm\zcode.cjs"
if not defined ENGINE if exist "D:\zcode\resources\glm\zcode.cjs" set "ENGINE=D:\zcode\resources\glm\zcode.cjs"
if not defined ENGINE if exist "C:\zcode\resources\glm\zcode.cjs" set "ENGINE=C:\zcode\resources\glm\zcode.cjs"
if not defined ENGINE (
  echo [zcode-cli] zcode.cjs not found.
  echo            Set ZCODE_ENGINE to your ZCode install dir, e.g.
  echo              set ZCODE_ENGINE=D:\apps\ZCode
  exit /b 1
)

echo [zcode-cli] engine: %ENGINE%
"%NODE_EXE%" "%ENGINE%" %*
exit /b %ERRORLEVEL%
