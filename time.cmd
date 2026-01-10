@echo off
title Time Sync
chcp 65001 >nul 2>&1

:: 设置全局超时时间
set GLOBAL_TIMEOUT=100
set START_TIME=%time%

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%temp%\getadmin.vbs" del /f /q "%temp%\getadmin.vbs"
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del /f /q "%temp%\getadmin.vbs"
    exit /b
)

echo [%time%] 正在配置时间同步服务...

:: 停止并配置 Windows Time 服务
net stop w32time >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxPosPhaseCorrection /t REG_DWORD /d 0xffffffff /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxNegPhaseCorrection /t REG_DWORD /d 0xffffffff /f >nul 2>&1
w32tm /unregister >nul 2>&1
w32tm /register >nul 2>&1
net start w32time >nul 2>&1

:: 定义 NTP 服务器列表
set NTP_SERVERS=time.asia.apple.com ntp.aliyun.com cn.ntp.org.cn
set RETRY_COUNT=0
set MAX_RETRIES=3

:check_timeout
call :get_elapsed_time
if %ELAPSED_TIME% GEQ %GLOBAL_TIMEOUT% (
    echo [%time%] 错误: 操作超时 ^(超过 %GLOBAL_TIMEOUT% 秒^)
    goto end_fail
)

:check_network
echo [%time%] 检查网络连接...
ipconfig /all | findstr /C:"IPv4" >nul 2>&1
if %errorlevel% neq 0 (
    call :check_timeout
    timeout /t 2 /nobreak >nul
    goto check_network
)
echo [%time%] 网络连接正常

:: 遍历每个 NTP 服务器
for %%s in (%NTP_SERVERS%) do (
    call :check_timeout
    call :sync_with_server %%s
    if !errorlevel! equ 0 goto end_success
)

echo [%time%] 错误: 所有 NTP 服务器同步失败
goto end_fail

:sync_with_server
set CURRENT_SERVER=%1
echo.
echo [%time%] 正在尝试服务器: %CURRENT_SERVER%

:: 测试服务器连通性
echo [%time%] 测试连通性...
set PING_COUNT=0
:ping_test
call :check_timeout
ping -n 1 -w 2000 %CURRENT_SERVER% >nul 2>&1
if %errorlevel% equ 0 goto ping_success
set /a PING_COUNT+=1
if %PING_COUNT% GEQ 3 (
    echo [%time%] 服务器 %CURRENT_SERVER% 无法访问
    exit /b 1
)
timeout /t 1 /nobreak >nul
goto ping_test

:ping_success
echo [%time%] 服务器可访问

:: 配置 NTP 服务器
echo [%time%] 配置服务器...
w32tm /config /manualpeerlist:"%CURRENT_SERVER%,0x8" /syncfromflags:manual /reliable:yes /update >nul 2>&1
if %errorlevel% neq 0 (
    echo [%time%] 配置失败
    exit /b 1
)

:: 重启服务确保配置生效
net stop w32time >nul 2>&1
net start w32time >nul 2>&1
timeout /t 1 /nobreak >nul

:: 同步时间
echo [%time%] 正在同步时间...
set SYNC_COUNT=0
:sync_time
call :check_timeout
w32tm /resync /force >nul 2>&1
set SYNC_ERROR=%errorlevel%

:: 检查同步结果
if %SYNC_ERROR% equ 0 (
    echo [%time%] 时间同步成功！
    w32tm /query /status | findstr /C:"Source:" /C:"上次成功同步时间"
    exit /b 0
)

set /a SYNC_COUNT+=1
if %SYNC_COUNT% GEQ %MAX_RETRIES% (
    echo [%time%] 服务器 %CURRENT_SERVER% 同步失败
    exit /b 1
)

timeout /t 2 /nobreak >nul
goto sync_time

:: 计算运行时长的子程序
:get_elapsed_time
for /f "tokens=1-4 delims=:.," %%a in ("%START_TIME%") do (
    set /a START_SEC=^(^(%%a*60+1%%b-100^)*60+1%%c-100^)
)
for /f "tokens=1-4 delims=:.," %%a in ("%time%") do (
    set /a END_SEC=^(^(%%a*60+1%%b-100^)*60+1%%c-100^)
)
set /a ELAPSED_TIME=END_SEC-START_SEC
if %ELAPSED_TIME% LSS 0 set /a ELAPSED_TIME+=86400
exit /b

:end_success
echo.
echo ========================================
echo [%time%] 时间同步完成！
echo ========================================
timeout /t 2 >nul
exit /b 0

:end_fail
echo.
echo ========================================
echo [%time%] 时间同步失败，请检查网络连接
echo ========================================
timeout /t 3 >nul
exit /b 1
