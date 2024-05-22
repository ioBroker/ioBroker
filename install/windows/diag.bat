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
echo *** ioBroker Diagnosis *** > %logfile% 2>&1
echo. >> %logfile% 2>&1
echo **************************************************************************************************************** >> %logfile% 2>&1
echo *                                                                                                              * >> %logfile% 2>&1
echo * Please stretch the window of your command window as wide as possible or switch to full screen                * >> %logfile% 2>&1
echo *                                                                                                              * >> %logfile% 2>&1
echo * The following checks may give hints to potential malconfigurations or errors, please post them in our forum: * >> %logfile% 2>&1
echo *                                                                                                              * >> %logfile% 2>&1
echo * https://forum.iobroker.net                                                                                   * >> %logfile% 2>&1
echo *                                                                                                              * >> %logfile% 2>&1
echo * Just copy and paste the conent of the log file %logfile% ``` characters at start and end.        * >> %logfile% 2>&1
echo * It helps us to help you!                                                                                     * >> %logfile% 2>&1
echo *                                                                                                              * >> %logfile% 2>&1
echo * The output will be saved to the file %logfile% and displayed in this window once the script      * >> %logfile% 2>&1
echo * has finished.                                                                                                * >> %logfile% 2>&1
echo *                                                                                                              * >> %logfile% 2>&1
echo **************************************************************************************************************** >> %logfile% 2>&1
echo. >> %logfile% 2>&1
type %logfile%
pause
echo.
echo Please wait until the script is completed ...
echo. >> %logfile% 2>&1
echo ``` >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo Disks: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
for /f "tokens=1,2,3,4" %%a in ('wmic /node:localhost LogicalDisk Where DriveType^="3" Get DeviceID^,Size^,FreeSpace^,VolumeName^') do @echo %%a	%%c	%%b	%%d >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo ioBroker Directory: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
dir /OGN >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo ioBroker Backups: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
dir backups /OGN >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo ioBroker-data: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
dir iobroker-data /OGN >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo ioBroker Hosts: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call iob list hosts >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo ioBroker Instances: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call iob list instances >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo ioBroker Update: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call iob update >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo ioBroker Service: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call setEnvIobServiceName.bat >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo Status: >> %logfile% 2>&1
sc queryex %iobServiceName%.exe >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo Node.js Version: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
node -v >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo npm Paths: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
where npm >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo npm Version: >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call npm -v >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo local installed node modules (overview): >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call npm ls >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo local installed node modules (all): >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call npm ls --all >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo global installed node modules (overview): >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call npm -g ls >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo -------------------------------------------------------------------------------------------------------------------------------------------------------------------- >> %logfile% 2>&1
echo global installed node modules (all): >> %logfile% 2>&1
echo. >> %logfile% 2>&1
call npm -g ls --all >> %logfile% 2>&1
echo. >> %logfile% 2>&1
echo ``` >> %logfile% 2>&1
type %logfile% | more
echo.
echo.
echo The output is stored in the file %logfile%
echo.
echo.
:end