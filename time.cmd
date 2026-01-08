@echo off
title 时间同步工具
chcp 65001 >nul 2>&1

REM 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo 需要管理员权限，正在请求提升...
    echo.
    
    REM 使用mshta方式提权（兼容Win7）
    if exist "%temp%\getadmin.vbs" del /f /q "%temp%\getadmin.vbs"
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del /f /q "%temp%\getadmin.vbs"
    exit /b
)

echo ========================================
echo    Windows 时间同步工具
echo ========================================
echo.

echo [1/6] 正在停止Windows Time服务...
net stop w32time >nul 2>&1
if %errorlevel% equ 0 (
    echo       服务已停止
) else (
    echo       服务可能未运行，继续...
)

echo [2/6] 正在修改时间服务配置...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxPosPhaseCorrection /t REG_DWORD /d 0xffffffff /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxNegPhaseCorrection /t REG_DWORD /d 0xffffffff /f >nul 2>&1
echo       配置已更新

echo [3/6] 正在重新注册时间服务...
w32tm /unregister >nul 2>&1
w32tm /register >nul 2>&1
echo       服务已重新注册

echo [4/6] 正在启动Windows Time服务...
net start w32time >nul 2>&1
if %errorlevel% equ 0 (
    echo       服务已启动
) else (
    echo       警告：服务启动失败
)

echo [5/6] 正在配置时间服务器...
w32tm /config /manualpeerlist:"time.asia.apple.com,0x8 time.windows.com,0x8 ntp.aliyun.com,0x8" /syncfromflags:manual /reliable:yes /update >nul 2>&1
echo       时间服务器已配置

echo [6/6] 正在检测网络并同步时间...
set retry_count=0
:sync_loop
set /a retry_count+=1
if %retry_count% gtr 5 (
    echo       同步失败：已达到最大重试次数
    goto show_status
)

ping -n 1 -w 1000 time.asia.apple.com >nul 2>&1
if %errorlevel% neq 0 (
    echo       网络连接检测中... ^(尝试 %retry_count%/5^)
    timeout /t 2 /nobreak >nul
    goto sync_loop
)

w32tm /resync /force >nul 2>&1
if %errorlevel% equ 0 (
    echo       时间同步成功！
) else (
    echo       尝试备用同步方法...
    w32tm /resync /rediscover >nul 2>&1
    if %errorlevel% equ 0 (
        echo       备用方法同步成功！
    ) else (
        echo       同步失败，正在重试...
        timeout /t 2 /nobreak >nul
        goto sync_loop
    )
)

:show_status
echo.
echo ========================================
echo    当前时间状态
echo ========================================
w32tm /query /status 2>nul | findstr /C:"层" /C:"源" /C:"上次成功"
if %errorlevel% neq 0 (
    echo 无法获取详细状态
    echo 当前系统时间: %date% %time%
)
echo ========================================
