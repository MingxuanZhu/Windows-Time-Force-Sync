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

set max_attempts=50
set attempt=1

:ping_test
echo  %attempt% , %max_attempts%
ping -n 1 -w 5000 www.baidu.com >nul 2>&1

if %errorlevel% equ 0 (
    echo Continue
    goto success
)

if %attempt% geq %max_attempts% (
    echo Reached %max_attempts%
    goto failure
)

timeout /t 2 /nobreak >nul
set /a attempt+=1
goto ping_test

:success
echo Continue
goto sync_time_apple

:failure
goto end

echo Sync Time from apple
w32tm /config /manualpeerlist:"time.asia.apple.com,0x8" /syncfromflags:manual /reliable:yes /update >nul 2>&1
w32tm /resync /force >nul 2>&1
if %errorlevel% eq 0 (
    goto end
)

timeout /t 2 /nobreak >nul

w32tm /config /manualpeerlist:"ntp.aliyun.com,0x8" /syncfromflags:manual /reliable:yes /update >nul 2>&1
w32tm /resync /force >nul 2>&1
if %errorlevel% eq 0 (
    goto end
)

timeout /t 2 /nobreak >nul

echo Sync Time from orgcn
w32tm /config /manualpeerlist:"cn.ntp.org.cn,0x8" /syncfromflags:manual /reliable:yes /update >nul 2>&1
w32tm /resync /force >nul 2>&1
if %errorlevel% eq 0 (
    goto end
)

timeout /t 2 /nobreak >nul

echo Sync Time from accn
w32tm /config /manualpeerlist:"ntp.ntsc.ac.cn,0x8" /syncfromflags:manual /reliable:yes /update >nul 2>&1
w32tm /resync /force >nul 2>&1
if %errorlevel% eq 0 (
    goto end
)

timeout /t 2 /nobreak >nul

echo Sync Time from org
w32tm /config /manualpeerlist:"cn.pool.ntp.org,0x8" /syncfromflags:manual /reliable:yes /update >nul 2>&1
w32tm /resync /force >nul 2>&1
if %errorlevel% eq 0 (
    goto end
)

:end
exit
