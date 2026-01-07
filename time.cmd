@echo off
title 时间同步

REM 检测Windows版本
for /f "tokens=4-5 delims=. " %%i in ('ver') do set /a major=%%i, minor=%%j >nul 2>&1

REM Windows Vista/7/8使用不同的提权方式
if %major% LSS 6 (
    echo 不支持的操作系统版本
    pause
    exit
)

if %major% EQU 6 (
    REM Windows Vista/7/8 使用Shell.Application
    if not "%1"=="admin" (
        >nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
        if '%errorlevel%' NEQ '0' (
            echo 请求管理员权限...
            set params=%*
            set params=%params:"=%
            mshta vbscript:createobject("shell.application").shellexecute("""%~s0""","admin","","runas",1)(window.close)
            exit /b
        )
    )
) else (
    REM Windows 8.1+ 使用powershell
    if not "%1"=="admin" (
        powershell "Start-Process '%~s0' 'admin' -Verb RunAs" >nul 2>&1
        if errorlevel 1 (
            echo 请右键以管理员身份运行此脚本
            pause
        )
        exit /b
    )
)

echo 正在停止Windows Time服务...
net stop w32time >nul 2>&1
if errorlevel 1 (
    echo 警告：无法停止Windows Time服务，但将继续执行...
)

echo 正在修改时间服务配置...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxPosPhaseCorrection /t DWORD /d 4294967295 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Config" /v MaxNegPhaseCorrection /t DWORD /d 4294967295 /f >nul 2>&1

echo 正在重新注册时间服务...
w32tm /unregister >nul 2>&1
w32tm /register >nul 2>&1

echo 正在启动Windows Time服务...
net start w32time >nul 2>&1
if errorlevel 1 (
    echo 警告：无法启动Windows Time服务，但将继续执行...
)

echo 正在配置时间服务器...
w32tm /config /manualpeerlist:"time.asia.apple.com" /syncfromflags:manual /reliable:yes /update >nul 2>&1

echo 正在检测网络连接...
:check
ping -n 1 time.asia.apple.com >nul 2>&1
if errorlevel 1 (
    echo 网络连接失败，2秒后重试...
    timeout /t 2 /nobreak >nul
    goto check
)

echo 正在强制同步时间...
w32tm /resync /force >nul 2>&1
if errorlevel 1 (
    echo 时间同步失败，正在尝试其他方法...
    
    REM 备用方法：使用net time命令（适用于Win7）
    net time \\time.asia.apple.com /set /y >nul 2>&1
    if errorlevel 1 (
        echo 警告：无法同步时间，请检查网络连接
    ) else (
        echo 已使用备用方法同步时间
    )
) else (
    echo 时间同步完成！
)

echo.
echo 当前时间信息：
w32tm /query /status | findstr /C:"上次成功同步时间"
w32tm /query /status | findstr /C:"源"

echo.
pause