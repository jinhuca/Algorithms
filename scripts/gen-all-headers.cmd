@echo off
REM gen-all-headers.cmd - regenerate (or --check) every core's header-only .hpp twins
REM from its .ixx modules, across all studios, via the unified scripts\gen_hpp.py.
REM
REM   scripts\gen-all-headers.cmd            regenerate every core\include\<ns>\*.hpp
REM   scripts\gen-all-headers.cmd --check    CI: fail if any twin is stale
setlocal enabledelayedexpansion
cd /d "%~dp0.."

set PY=py -3
where py >nul 2>nul || set PY=python

set RC=0
for %%E in (search_algo:se sort_algo:sa tree_algo:tr graph_algo:ga foundation_algo:fo combinatorics_algo:cb numerics_algo:nu) do (
    for /f "tokens=1,2 delims=:" %%A in ("%%E") do (
        if exist "%%A\core\modules" (
            echo == %%A ^(ns %%B^) ==
            %PY% -I scripts\gen_hpp.py --project %%A --ns %%B %*
            if errorlevel 1 set RC=1
        ) else (
            echo skip %%A ^(no core\modules^)
        )
    )
)
exit /b %RC%
