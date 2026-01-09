@echo off
title Time Sync
chcp 65001 >nul 2>&1

net session >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%temp%\getadmin.vbs" del /f /q "%temp%\getadmin.vbs"
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del /f /q "%temp%\getadmin.vbs"
    exit /b
)

net stop w32time >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxPosPhaseCorrection /t REG_DWORD /d 0xffffffff /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxNegPhaseCorrection /t REG_DWORD /d 0xffffffff /f >nul 2>&1
w32tm /unregister >nul 2>&1
w32tm /register >nul 2>&1
net start w32time >nul 2>&1
w32tm /config /manualpeerlist:"time.asia.apple.com,0x8" /syncfromflags:manual /reliable:yes /update >nul 2>&1

:check_network
ipconfig /all | findstr /C:"IPv4" >nul 2>&1
if %errorlevel% neq 0 (
    timeout /t 2 /nobreak >nul
    goto check_network
)

:ping_test
ping -n 1 -w 1000 time.asia.apple.com >nul 2>&1
if %errorlevel% neq 0 (
    timeout /t 2 /nobreak >nul
    goto ping_test
)

:sync_time
w32tm /resync /force >nul 2>&1
if %errorlevel% neq 0 (
    timeout /t 2 /nobreak >nul
    goto sync_time
)

exit
