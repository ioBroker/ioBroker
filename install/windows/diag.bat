@echo off

REM iobroker diagnostics for Windows
REM Written to help getting information about the environment the ioBroker installation is running in
REM Must be exectuted in an ioBroker Cmd window in the ioBroker installation directory 

if not exist iob.bat (
  echo.
  echo Please run this script in a directory where ioBroker is installed!
  goto :end
)
if not exist log (
  mkdir log
)
cls
set logfile=log\ioBroker-diag.log
echo.
echo *** ioBroker Diagnosis ***>%logfile% 2>&1
echo *** ioBroker Diagnosis ***
echo.>>%logfile% 2>&1
echo.
echo *************************************************************************
echo *                                                                       *
echo * The following checks may give hints to potential malconfigurations    *
echo * or errors, please post them in our forum:                             *
echo *                                                                       *
echo * https://forum.iobroker.net                                            *
echo *                                                                       *
echo * Just copy and paste the content of the log file %logfile% *
echo * including ``` characters at start and end.                            *
echo * It helps us to help you!                                              *
echo *                                                                       *
echo * The output will be saved to the file %logfile% and        *
echo * displayed in notepad once the script has finished.                    *
echo *                                                                       *
echo *************************************************************************
echo.
pause
echo.
echo Please wait until the script is completed ...
echo ```>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo time and date:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
%windir%\System32\tzutil.exe /g>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo %date% %time%>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo Disks (letter, size, free, name):>>%logfile% 2>&1
echo.>>%logfile% 2>&1
for /f "tokens=1,2,3,4" %%a in ('wmic /node:localhost LogicalDisk Where DriveType^="3" Get DeviceID^,Size^,FreeSpace^,VolumeName^|find ":"') do @echo %%a	%%c	%%b	%%d>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo ioBroker Directory:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
dir /OGN>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo ioBroker Backups:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
dir backups /OGN>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo ioBroker-data:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
dir iobroker-data /OGN>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo ioBroker Hosts:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call iob list hosts>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo ioBroker Instances:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call iob list instances>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo ioBroker Update:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call iob update>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo ioBroker Service:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call setEnvIobServiceName.bat>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo Status:>>%logfile% 2>&1
sc queryex %iobServiceName%.exe>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo Node.js Version:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
node -v>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo npm Paths:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
where npm>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo npm Version:>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call npm -v>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo local installed node modules (overview):>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call npm ls>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo local installed node modules (all):>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call npm ls --all>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo global installed node modules (overview):>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call npm -g ls>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------->>%logfile% 2>&1
echo global installed node modules (all):>>%logfile% 2>&1
echo.>>%logfile% 2>&1
call npm -g ls --all>>%logfile% 2>&1
echo.>>%logfile% 2>&1
echo ```>>%logfile% 2>&1
echo.
echo The output is stored in the file %logfile%
echo.
start notepad %logfile%
:end
