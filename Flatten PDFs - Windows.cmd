@echo off
setlocal EnableExtensions DisableDelayedExpansion
title PDF Flattener

set "SUCCEEDED=0"
set "FAILED=0"
set "IGNORED=0"
set "FOUND=0"
set "GS_EXE="

call :find_ghostscript
if not defined GS_EXE goto :ghostscript_missing

if "%~1"=="" goto :show_usage

echo PDF Flattener
echo Using: "%GS_EXE%"
echo.

:next_item
if "%~1"=="" goto :finished
call :process_item "%~f1"
shift
goto :next_item

:process_item
if exist "%~f1\" (
    for /r "%~f1" %%F in (*.pdf) do call :flatten_pdf "%%~fF"
    goto :eof
)

if exist "%~f1" (
    if /i "%~x1"==".pdf" (
        call :flatten_pdf "%~f1"
    ) else (
        set /a IGNORED+=1
        echo [SKIP] Not a PDF: "%~f1"
    )
) else (
    set /a IGNORED+=1
    echo [SKIP] Not found: "%~f1"
)
goto :eof

:flatten_pdf
rem Never process this tool's own output on a later folder scan.
for %%D in ("%~dp1.") do if /i "%%~nxD"=="Flattened" (
    goto :eof
)

set /a FOUND+=1

set "OUTPUT_DIR=%~dp1Flattened"
set "OUTPUT_FILE=%~dp1Flattened\%~nx1"

if not exist "%OUTPUT_DIR%\" mkdir "%OUTPUT_DIR%" >nul 2>&1
if not exist "%OUTPUT_DIR%\" (
    set /a FAILED+=1
    echo [FAIL] Could not create: "%OUTPUT_DIR%"
    goto :eof
)

rem Ghostscript writes a temporary file first, so a failed run cannot damage
rem an existing flattened copy. A successful run replaces that copy atomically.
set "TEMP_OUTPUT=%OUTPUT_DIR%\.__flattening_%RANDOM%_%RANDOM%_%RANDOM%.tmp"
set "LOG_FILE=%OUTPUT_DIR%\.__flattening_%RANDOM%_%RANDOM%_%RANDOM%.log"

"%GS_EXE%" -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -dPreserveAnnots=true -dShowAnnots=true -dShowAcroForm=true "-sOutputFile=%TEMP_OUTPUT%" "%~f1" >"%LOG_FILE%" 2>&1
if errorlevel 1 goto :flatten_failed
if not exist "%TEMP_OUTPUT%" goto :flatten_failed

move /y "%TEMP_OUTPUT%" "%OUTPUT_FILE%" >nul 2>&1
if errorlevel 1 goto :flatten_failed

del /q "%LOG_FILE%" >nul 2>&1
set /a SUCCEEDED+=1
echo [ OK ] "%~f1"
echo        -^> "%OUTPUT_FILE%"
goto :eof

:flatten_failed
set /a FAILED+=1
echo [FAIL] "%~f1"
if exist "%LOG_FILE%" type "%LOG_FILE%"
if exist "%TEMP_OUTPUT%" del /q "%TEMP_OUTPUT%" >nul 2>&1
if exist "%LOG_FILE%" del /q "%LOG_FILE%" >nul 2>&1
goto :eof

:find_ghostscript
for %%G in (gswin64c.exe gswin32c.exe) do (
    if not defined GS_EXE for /f "delims=" %%P in ('where %%G 2^>nul') do if not defined GS_EXE set "GS_EXE=%%~fP"
)

if not defined GS_EXE if exist "%ProgramFiles%\gs\" (
    for /d %%D in ("%ProgramFiles%\gs\gs*") do if exist "%%~fD\bin\gswin64c.exe" set "GS_EXE=%%~fD\bin\gswin64c.exe"
)

if not defined GS_EXE if exist "%ProgramFiles(x86)%\gs\" (
    for /d %%D in ("%ProgramFiles(x86)%\gs\gs*") do if exist "%%~fD\bin\gswin32c.exe" set "GS_EXE=%%~fD\bin\gswin32c.exe"
)
goto :eof

:finished
echo.
if "%FOUND%"=="0" echo No PDF files were found.
echo Complete. Succeeded: %SUCCEEDED%   Failed: %FAILED%   Ignored: %IGNORED%
echo.
pause
set "EXIT_CODE=0"
if not "%FAILED%"=="0" set "EXIT_CODE=1"
endlocal & exit /b %EXIT_CODE%

:show_usage
echo PDF Flattener
echo.
echo Drag one or more PDF files or folders onto this script.
echo PDFs inside dropped folders are processed recursively.
echo Each result is written to a Flattened folder beside its source PDF.
echo.
pause
endlocal & exit /b 2

:ghostscript_missing
echo PDF Flattener cannot start because Ghostscript was not found.
echo.
echo Install the current 64-bit Ghostscript release from:
echo https://ghostscript.com/releases/gsdnld.html
echo.
echo Then drag the PDFs or folders onto this script again.
echo.
pause
endlocal & exit /b 2
