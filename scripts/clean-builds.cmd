@echo off
rem ============================================================
rem clean-builds.cmd - remove all CMake/Qt/MSVC build output under
rem Algorithms (parent repo + every submodule). Source files are
rem never touched. Windows CMD equivalent of clean-builds.sh.
rem
rem Usage:
rem   scripts\clean-builds.cmd            delete build output
rem   scripts\clean-builds.cmd --dry-run  preview only, delete nothing
rem   scripts\clean-builds.cmd -n         same as --dry-run
rem ============================================================
setlocal EnableDelayedExpansion

set "DRY=0"
if /i "%~1"=="--dry-run" set "DRY=1"
if /i "%~1"=="-n"        set "DRY=1"
if /i "%~1"=="/dry-run"  set "DRY=1"
if not "%~1"=="" if "!DRY!"=="0" (
  echo Unknown option: %~1
  echo Usage: %~nx0 [--dry-run^|-n]
  exit /b 2
)

rem Run from the repo root regardless of where the script is called from.
pushd "%~dp0.." || exit /b 1
set "ROOT=%CD%"
echo Scanning for build output under: !ROOT!
if "!DRY!"=="1" echo (dry run - nothing will be deleted)

set "FOUND=0"

rem ---- build-output directories ----
for /f "delims=" %%D in ('dir /s /b /a:d 2^>nul') do (
  echo %%D| findstr /i /c:"\.git" >nul
  if errorlevel 1 (
    set "name=%%~nxD"
    set "match=0"
    for %%N in (build out CMakeFiles x64 Win32 Debug Release) do if /i "!name!"=="%%N" set "match=1"
    if /i "!name:~0,6!"=="build-"      set "match=1"
    if /i "!name:~0,12!"=="cmake-build-" set "match=1"
    if "!match!"=="1" if exist "%%D\" (
      set "FOUND=1"
      echo   dir   %%D
      if "!DRY!"=="0" rd /s /q "%%D" 2>nul
    )
  )
)

rem ---- stray CMake-generated config files ----
for %%F in (CMakeCache.txt cmake_install.cmake CTestTestfile.cmake) do (
  for /f "delims=" %%G in ('dir /s /b "%%F" 2^>nul') do (
    echo %%G| findstr /i /c:"\.git" >nul
    if errorlevel 1 if exist "%%G" (
      set "FOUND=1"
      echo   file  %%G
      if "!DRY!"=="0" del /f /q "%%G" 2>nul
    )
  )
)

if "!FOUND!"=="0" (
  echo Nothing to clean - already clean.
  popd
  exit /b 0
)

if "!DRY!"=="1" (
  echo Dry run complete. Re-run without --dry-run to delete.
) else (
  echo Done - build output removed.
)
popd
exit /b 0
