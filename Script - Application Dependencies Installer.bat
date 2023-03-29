::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: PockyBum522 (DSikes) Application Dependencies Installation Script
::
:: 1. Warns user if they run the script as admin
:: 2. Elevates to run some things as admin including UAC prompt
:: 3. Then runs some things as user
::  
:: To add things to be run as admin (Step 1) go to the :gotPrivileges function
::
:: To add things to be run as the user after that, go to the :finalStepsOnly function
::
::      - David Sikes
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

@echo off

: For checking for internet

ping -n 2 -w 700 8.8.8.8 | find "TTL="

IF %ERRORLEVEL% EQU 0 (
    SET internet=internet_connected
) ELSE (
    SET internet=internet_not_connected
)

: For detecting if we're running as admin for warning to user
cacls "%systemroot%\system32\config\system" 1>nul 2>&1

: ELEV argument present means we're calling this script again but with admin privs now
if "%1" neq "ELEV" (
	
		call :warnUserIfRunningAsAdministrator
		
		call :warnUserIfRunningWithoutInternet

		call :createElevatedActionsMutexFile
		
		call :initElevatedActions

		call :pauseUntilElevatedActionsFinish
		
		call :finalSteps

) else (

    call :gotPrivileges
    
)

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: THIS SECTION RUNS FIRST. EVERYTHING IN HERE RUNS AS ADMINISTRATOR.
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:gotPrivileges
    
    echo.
    echo Running admin stuff!
    echo.

    echo.
    echo Installing Chocolatey
    echo.

    powershell -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"

    echo.
    echo Setting Chocolatey confirmation prompts to not show
    echo.

    choco feature enable -n=allowGlobalConfirmation

    echo.
    echo If Chocolatey was previously installed, checking for updates
    echo.

    choco upgrade chocolatey

    echo.
    echo Installing (Or updating, if already installed) .NET 7 Windows Desktop Runtime
    echo.

    choco upgrade dotnet-7.0-desktopruntime

    echo.
    echo Refreshing environment variables for this shell instance
    echo.
    ::echo "RefreshEnv.cmd only works from cmd.exe, please install the Chocolatey Profile to take advantage of refreshenv from PowerShell"
    call :RefreshEnvironmentVariables

    echo.
    echo Deleting lockfile that represents admin stuff is running
    echo.

    del %PUBLIC%\Documents\dependenciesInstallScriptV01.lockfile

    exit 0

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: FINAL STEPS ONLY. THIS RUNS AFTER THE ADMIN PRIVS PART. THIS PART RUNS AS USER.
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:finalSteps
    echo.
    echo Running final steps!
    echo.
    

	echo.
    echo Finished installing dependencies on this computer
	echo.
	
    pause
    
    exit 0

::::::::::::::::::::::::::::::::::::::::::::::
:: SCRIPT UTILITY LOGIC ONLY BELOW HERE
::::::::::::::::::::::::::::::::::::::::::::::

:warnUserIfRunningAsAdministrator

    if "%errorlevel%" equ "0" (
    
        echo -------------------------------------------------------------
        echo ERROR: YOU ARE RUNNING THIS WITH ADMINISTRATOR PRIVILEGES
        echo -------------------------------------------------------------
        echo. 
        echo If you're seeing this, it means you are running this as admin user!
        echo.
        echo You will need to restart this program WITHOUT Administrator 
        echo privileges.
        echo. 
        echo Make sure to NOT Run As Administrator next time!
        echo. 
        echo Press any key to exit . . .

        pause> nul

        exit 1
    )

    exit /B
	
:warnUserIfRunningWithoutInternet

    if "%internet%" equ "internet_not_connected" (
    
        echo -------------------------------------------------------------
        echo ERROR: YOU ARE RUNNING THIS WITHOUT AN INTERNET CONNECTION
        echo -------------------------------------------------------------
        echo. 
        echo If you're seeing this, it means you are running this with no internet!
        echo.
        echo You will need to restart this program after connecting.
        echo. 
        echo Make sure to connect to the internet BEFORE re-running.
        echo. 
        echo Press any key to exit . . .

        pause> nul

        exit 1
    )

    exit /B

:createElevatedActionsMutexFile

    echo.
    echo Creating lockfile for waiting until elevated actions finish
    echo.

    copy /y NUL %PUBLIC%\Documents\dependenciesInstallScriptV01.lockfile >NUL
    
    exit /B

:pauseUntilElevatedActionsFinish

    echo.
    echo Waiting for elevated actions portion of script to finish.
    echo.
    echo This may take some time...
    echo.

    timeout /t 10

    IF EXIST %PUBLIC%\Documents\dependenciesInstallScriptV01.lockfile goto pauseUntilElevatedActionsFinish

    echo.
    echo Refreshing environment variables for this shell instance
    echo.
    ::echo "RefreshEnv.cmd only works from cmd.exe, please install the Chocolatey Profile to take advantage of refreshenv from PowerShell"
    call :RefreshEnvironmentVariables

    exit /B

::::::::::::::::::::::::::::::::::::::::::::
:: Elevate.cmd - Version 4
:: Automatically check & get admin rights
:: see "https://stackoverflow.com/a/12264592/1016343" for description
:: Modified by David Sikes
::::::::::::::::::::::::::::::::::::::::::::

:initElevatedActions
    	
    setlocal DisableDelayedExpansion
    set cmdInvoke=1
    set winSysFolder=System32
    set "batchPath=%~dpnx0"
    rem this works also from cmd shell, other than %~0
    for %%k in (%0) do set batchName=%%~nk
    set "vbsGetPrivileges=%temp%\OEgetPriv_batchScriptV01.vbs"
    setlocal EnableDelayedExpansion

    ECHO.
    ECHO **************************************
    ECHO Invoking UAC for Privilege Escalation
    ECHO **************************************
    ECHO.

    ECHO Set UAC = CreateObject^("Shell.Application"^) > "%temp%\OEgetPriv_batchScriptV01.vbs"
    ECHO args = "ELEV " >> "%temp%\OEgetPriv_batchScriptV01.vbs"
    ECHO For Each strArg in WScript.Arguments >> "%temp%\OEgetPriv_batchScriptV01.vbs"
    ECHO args = args ^& strArg ^& " "  >> "%temp%\OEgetPriv_batchScriptV01.vbs"
    ECHO Next >> "%temp%\OEgetPriv_batchScriptV01.vbs"
    ECHO UAC.ShellExecute "!batchPath!", args, "", "runas", 1 >> "%temp%\OEgetPriv_batchScriptV01.vbs"

    : Now run the file we just made
    "%SystemRoot%\%winSysFolder%\CScript.exe" "%temp%\OEgetPriv_batchScriptV01.vbs" ELEV

    exit /B

:: -------------------------------------------------------
:: BELOW HERE IS ALL CODE FROM CHOCOLATEY'S RefreshEnv.cmd
:: -------------------------------------------------------

:: Set one environment variable from registry key
:SetFromReg
    "%WinDir%\System32\Reg" QUERY "%~1" /v "%~2" > "%TEMP%\_envset.tmp" 2>NUL
    for /f "usebackq skip=2 tokens=2,*" %%A IN ("%TEMP%\_envset.tmp") do (
        echo/set "%~3=%%B"
    )
    goto :EOF

:: Get a list of environment variables from registry
:GetRegEnv
    "%WinDir%\System32\Reg" QUERY "%~1" > "%TEMP%\_envget.tmp"
    for /f "usebackq skip=2" %%A IN ("%TEMP%\_envget.tmp") do (
        if /I not "%%~A"=="Path" (
            call :SetFromReg "%~1" "%%~A" "%%~A"
        )
    )
    goto :EOF

:RefreshEnvironmentVariables
    echo/@echo off >"%TEMP%\_env.cmd"

    :: Slowly generating final file
    call :GetRegEnv "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" >> "%TEMP%\_env.cmd"
    call :GetRegEnv "HKCU\Environment">>"%TEMP%\_env.cmd" >> "%TEMP%\_env.cmd"

    :: Special handling for PATH - mix both User and System
    call :SetFromReg "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" Path Path_HKLM >> "%TEMP%\_env.cmd"
    call :SetFromReg "HKCU\Environment" Path Path_HKCU >> "%TEMP%\_env.cmd"

    :: Caution: do not insert space-chars before >> redirection sign
    echo/set "Path=%%Path_HKLM%%;%%Path_HKCU%%" >> "%TEMP%\_env.cmd"

    :: Cleanup
    del /f /q "%TEMP%\_envset.tmp" 2>nul
    del /f /q "%TEMP%\_envget.tmp" 2>nul

    :: capture user / architecture
    SET "OriginalUserName=%USERNAME%"
    SET "OriginalArchitecture=%PROCESSOR_ARCHITECTURE%"

    :: Set these variables
    call "%TEMP%\_env.cmd"

    :: Cleanup
    del /f /q "%TEMP%\_env.cmd" 2>nul

    :: reset user / architecture
    SET "USERNAME=%OriginalUserName%"
    SET "PROCESSOR_ARCHITECTURE=%OriginalArchitecture%"

    echo | set /p dummy="Finished refreshing environtment variables."
    echo.
    