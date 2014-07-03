@If "%echoon%"=="" @echo off
If "%local%"=="" setlocal
set NOPAUSE=
set NOCLS=
If "%pauseon%"=="" set NOPAUSE=::
If not "%clson%"=="" set NOCLS=::
::=============================
::
:: Automated emcreports using
:: psexec to run the emcreports
:: tool on a remote server
::
:: Aaron Baldie
:: EMC (c)
:: Version 1.34
:: 08/13/08
:: 01/21/09 (Fixed Loop Bug)
:: 04/25/09 (Fixed part of dedup bug)
:: 07/13/09 (Fixed dedup I think)
:: 10/20/09 (Updated to v34 EMC Reports)
::=============================

::------------------------------
:: Setup logging files and paths
::------------------------------
set LOCAL_DIR="%~dp0%"
set LOG="%~dp0%~n0.log"

::-------------------------------
:: Setup time and date stamp in logs
:: for each run of the batch file
::-------------------------------
ECHO ========================================== >> %LOG%
date /t >> %LOG%
time /t >> %LOG%
ECHO ------------- >> %LOG%

::--------------------------------
:: Start the applications that are 
:: supposed to run
:: if pauseon has a value run with 
:: pauses
::--------------------------------
:START
%NOPAUSE%pause

IF /i "%1"=="/h" GOTO :HELP
IF /i "%1"=="-h" GOTO :HELP
IF /I "%1"=="/help" GOTO :HELP
IF /I "%1"=="-help" GOTO :HELP

::--------------------------------
:: Erase all env vars to be safe
::--------------------------------
SET PSTOOLS_URL=http://technet.microsoft.com/en-us/sysinternals/bb896649.aspx
SET EMCREPORT_URL=https://powerlink.emc.com
SET IPLIST=
SET DATETIME=
SET SP=
SET DATADIR=
IF "%COUNT%"=="" SET COUNT=15
SET COUNTER=1
IF "%DELAY%"=="" SET DELAY=120
SET PASS=
SET FILENAME=
SET USER=
SET PWD=
SET NO_FLATFILE=
SET APM=
set HOST_ARCH=
set HOST_NAME=
SET NO_HOST=
SET current=
IF "%EMCREPORTS_DIR%"=="" SET EMCREPORTS_DIR=%LOCAL_DIR%
IF "%EMCREPORTS_EXE%"=="" SET EMCREPORTS_EXE=EMCRPTS_V34_
set X64_EMCREPORTS=%EMCREPORTS_DIR%EMCRPTS_V34_X64.EXE
SET X86_EMCREPORTS=%EMCREPORTS_DIR%EMCRPTS_V34_X86.EXE
set pslist=%LOCAL_DIR%pslist.exe
set pskill=%LOCAL_DIR%pskill.exe
set psexec=%LOCAL_DIR%psexec.exe
set EULA=%LOCAL_DIR%firstrun.1st
::--------------------------------
:: If there is a command line param
:: Go ahead and set it
::--------------------------------
SET USER=%1
SET PWD=%2
SET SP=%3

::--------------------------------
:: Ah, the infamous date/time
:: loop to create stamped file 
:: names
::--------------------------------
for /f "tokens=1-4 delims=/, " %%w in ('date /t') do set MONTH=%%x&& set DAY=%%y&& set YEAR=%%z
for /f "tokens=1,2 delims=:, " %%a in ('time /t') do set HOUR=%%a&& set MINUTE=%%b
set DATETIME=%YEAR%_%MONTH%_%DAY%_%HOUR%-%MINUTE%
echo Starting %0 at %DATETIME%
%NOPAUSE%pause

::--------------------------------
:: Trap everything that is needed
:: for this tool to work.
:: 
:: These tools include:
:: 	pslist.exe
::	pskill.exe
:: 	psexec.exe
:: 	EMCReports_Version_Arch.exe
::--------------------------------
If not exist %pslist% goto :NO_PSLIST
If not exist %pskill% goto :NO_PSKILL
If not exist %psexec% goto :NO_PSEXEC
If not exist %X64_EMCREPORTS% goto :NO_EMCREPORTS
If not exist %X86_EMCREPORTS% goto :NO_EMCREPORTS

::--------------------------------
:: Automate the setup process
:: for this tool so it can be 
:: distributed to other groups
::--------------------------------
If exist %EULA% goto :ACCEPT_EULA

::--------------------------------
:: Check that there is SP address
:: Or if /f is %1, if so use 
:: flat file mode instead of 
:: Clariion capture mode
::--------------------------------
If /i "%USER%"=="/f" set FILENAME=%PWD%&& SET SP=%PWD%

::--------------------------------
:: Set up a working directory for
:: This arrays collection based on
:: date/time stamp
::--------------------------------
set DATADIR=%DATETIME%_%SP%
mkdir %DATADIR%
set ARCH_LOG=%DATADIR%\%SP%_arch.log

::--------------------------------
:: If bad syntax goto help
:: -------------------------------
If "%SP%"=="" GOTO :HELP

::--------------------------------
:: Skip Clariion collect if the 
:: script is running in flat file
:: mode.
::--------------------------------
If /i "%USER%"=="/f" goto :EXECUTE


::--------------------------------
:: Setup static env vars
::--------------------------------
If Exist "c:\Program Files\emc\Navisphere CLI\naviseccli.exe" set NAVICLI=c:\Program Files\emc\Navisphere CLI\naviseccli.exe
If Exist "c:\Program Files (x86)\emc\Navisphere CLI\naviseccli.exe" set NAVICLI=c:\Program Files (x86)\emc\Navisphere CLI\naviseccli.exe

::--------------------------------
:: Check for the navicli.exe file
:: If not present error out and 
:: give the help screen
::--------------------------------
If "%NAVICLI%"=="" goto :NOCLI

::--------------------------------
:: Now set up the extended command
:: for seccli with -user -password
::--------------------------------
set NAVICLI="%NAVICLI%" -User %user% -Password %pwd% -Scope 0

:STARTCOLLECT

::--------------------------------
:: Get the list of servers that are
:: currently attached to the array
::--------------------------------
if exist %DATADIR%\%SP%_HOSTS.log del %DATADIR%\%SP%_HOSTS.log
if exist %DATADIR%\%SP%_HOSTS.lst del %DATADIR%\%SP%_HOSTS.lst

%NOPAUSE%pause
echo.
echo ===========================================
echo =					       
echo = Collecting host names from the Clariion!
echo =					       
echo ===========================================
echo Starting at:
time /t
echo.

ECHO Running: %NAVICLI% -Address %SP% getagent -serial
for /f "tokens=3 delims=: " %%w in ('%NAVICLI% -Address %SP% getagent -serial') do set APM=%%w

ECHO.
ECHO Running: %NAVICLI% -Address %SP% port -list
%NAVICLI% -Address %SP% port -list | findstr /c:"Server Name:" >> %DATADIR%\%SP%_HOSTS.log

pushd %DATADIR%
call :FILE_SIZE %SP%_HOSTS.log
popd

echo.
if "%FILESIZE%"=="0" echo ================ ALERT ================&& echo = %SP% can not be contacted&& ECHO =================== END ALERT ===============

if "%FILESIZE%"=="0" echo ================ ALERT ================ >> %LOG%&& echo %SP% can not be contacted >> %LOG%&& ECHO ================== END ALERT ================ >> %LOG% && goto :END

set current=
set NO_FLATFILE=::

ECHO.
echo ===========================================
ECHO = Deduping the Clarrion List.
ECHO = If a server is not registered it will show 
ECHO = up as a 2 digit number and will be ignored
ECHO = when the emcreport is run.
echo ===========================================

for /f "tokens=1,2,3 delims=: " %%x in (%DATADIR%\%SP%_HOSTS.log) do call :DEDUPE %%z

:EXECUTE
::--------------------------------
:: Create Directory on remote host
:: called EMC to store EMCReports
:: Locally
::
:: Then psexec EMCReports from that
:: directory and wait for the prompt
:: to return.
::
:: Finally copy the zip file from
:: c:\windows\emcreports\collection\zip\
::
::--------------------------------

::--------------------------------
:: Used for flatfile mode, skip
:: all of the clariion gather stuff
::--------------------------------
%NO_FLATFILE%If exist %FILENAME% type %FILENAME% >> %DATADIR%\%SP%_HOSTS.lst

if not exist %DATADIR%\%SP%_HOSTS.lst goto :END

for /f %%x in (%DATADIR%\%SP%_HOSTS.lst) do call :GET_ARCH %%x

::---------------------------------
:: Since we are threading the
:: psexec processes the script
:: needs to watch what is out there
:: and after a specified time limit
:: kill leftovers and go get the files
::---------------------------------

for /l %%x in (1,1,%COUNT%) do call :wait

::---------------------------------
:: Go get the files if they exist
::---------------------------------

for /f %%x in (%DATADIR%\%SP%_HOSTS.lst) do ECHO copy %%x EMCReport file to %DATADIR%&& xcopy \\%%x\c$\windows\emcreports\collection\zip\*.zip %DATADIR% >> %LOG% 2>&1

:REPORT
::--------------------------------
:: Write an HTML report on success
:: and failures
::--------------------------------
set file=%DATADIR%\%SP%_HOSTS.lst
set report=%DATADIR%\%DATADIR%_REPORT.html

echo ^<html^> > %report%
echo ^<body^> >> %report%
echo ^<font face="arial"^> >> %report%
echo Report: %~dp0^%report% ^<br^>Started on Serial: %APM% IP: %SP%^<br^> >> %report%
date /t >> %report%
echo ^@ >> %report%
time /t >> %report%
echo ^<br^> >> %report%
echo ^<table border=1^> >> %report%
echo ^<tr^> ^<th^>Server Name^<^/th^> ^<th^>Status^<^/th^> ^<th^>File Name^<^/th^> ^<^/tr^> >> %report%
for /f "delims=." %%x in (%file%) do call :check_it %%x

start %report%

GOTO :END

:check_it
(
for /f %%x in ('dir /b %DATADIR%\%1*.zip') do set filename=%%x
) >> %LOG% 2>&1
if "%filename%"=="" (echo ^<tr bgcolor=yellow^> ^<td^> %1 ^<^/td^> ^<td^> Failure ^<^/td^> ^<td^> None ^<^/td^>>> %report%) else (echo ^<tr bgcolor=green^> ^<td^> ^<font color="yellow"^> %1 ^<^/font^> ^<^/td^> ^<td^> ^<font color="yellow"^> Success ^<^/font^> ^<^/td^> ^<td^> ^<font color="yellow"^> %filename% ^<^/font^> ^<^/td^> >> %report%)
echo ^<^/font^> ^<^/tr^> >> %report%
set filename=

GOTO :END

:GET_ARCH

set NO_HOST=
set HOST_ARCH=
set HOST_NAME=%1
::--------------------------------
:: Check to see if the host exists
::--------------------------------

echo.
echo ============================================
echo =						
echo = Collecting host arch from %HOST_NAME%	
echo =		
echo ============================================
echo Starting at:
time /t
echo.

if not exist \\%HOST_NAME%\C$\windows set NO_HOST=yes

if /i "%NO_HOST%"=="yes" echo ================ ALERT ================&& echo %HOST_NAME% can not be contacted!&& ECHO ============== END ALERT ==============

if /i "%NO_HOST%"=="yes" echo ================ ALERT ================ >> %LOG%&& echo %HOST_NAME% can not be contacted >> %LOG%&& ECHO ================== END ALERT ================ >> %LOG% && goto :END

if exist \\%HOST_NAME%\C$\windows\syswow64 (set HOST_ARCH=x64) else (set HOST_ARCH=x86)

%NOPAUSE%pause

echo.
echo ============================================
echo =						
echo = Making EMCREPORTS_DIR directory on %HOST_NAME%	
echo =		
echo ============================================

mkdir \\%HOST_NAME%\c$\emc

echo.
echo ============================================
echo =						
echo = Copying %EMCREPORTS_EXE%%HOST_ARCH%.EXE to %HOST_NAME%	
echo =		
echo ============================================
xcopy /y %EMCREPORTS_DIR%%EMCREPORTS_EXE%%HOST_ARCH%.EXE \\%HOST_NAME%\c$\emc\

echo.
echo ============================================
echo =						
echo = Starting PSEXEC emcreports %HOST_NAME%	
echo =						
echo ============================================
echo Starting at:
time /t
echo.

start /MIN psexec.exe \\%HOST_NAME% c:\emc\%EMCREPORTS_EXE%%HOST_ARCH%.EXE /q

%NOPAUSE%pause

GOTO :END

:DEDUPE
::--------------------------------
:: Dedupe the server name list
:: some of these servers will not
:: work if they have not cleaned
:: up the arrays
:: Will need to Log all bs servers
:: in another portion of the script
::--------------------------------

if "%current%"=="" (
	set current=%1&& echo %1>> %DATADIR%\%SP%_HOSTS.lst
) else (
	If "%current%"=="%1" (
		echo %1 already located
	) else (
		findstr /i "%1" %DATADIR%\%SP%_HOSTS.lst
		If ERRORLEVEL 1 (
			echo %1>> %DATADIR%\%SP%_HOSTS.lst
		) else (
			echo %1 already located			
		)
	)
	set current=%1
)
GOTO :END

:WAIT
::--------------------------------
:: Little Ping set to setup a 10
:: second waiting period
::--------------------------------
If "%COUNTER%"=="%COUNT%" GOTO :END
ECHO Script was started %DATETIME%
echo.
ECHO ------------------------------------------------------------------
ECHO Current Time is:
time /t
SET PASS=%PASS% %COUNTER%
ECHO There will be %COUNT% %DELAY% Second Passes!
ECHO Unless all psexec processes finish before then!
Echo Waiting for collection to finish: Pass %PASS%
ECHO ------------------------------------------------------------------
ECHO.
ping 127.0.0.1 -n 2 -w 1000 > nul
ping 127.0.0.1 -n %DELAY% -w 1000> nul
set /A COUNTER+=1
goto :WATCH

:WATCH
::--------------------------------
:: Watch all of the psexec processes
:: and report them to the end users
:: after the counter is finished
:: kill what is left and start 
:: gathering the zip files.
::--------------------------------
Echo *********************************
echo The following psexecs are running
echo *********************************

%pslist% psexec

if "%errorlevel%"=="1" echo psexec Processes all completed&& set COUNTER=%COUNT%
If "%COUNTER%"=="%COUNT%" %pskill% psexec&& echo Killed stale psexecs

GOTO :END 

:FILE_SIZE
::-----------------------------------
:: Check the file size and set
:: variable to size of file
:: this allows for check of 0 byte
:: file
::-----------------------------------
set FILESIZE=%~z1
GOTO :END

::===========================Error Control Below Here=====================

:NOCLI
echo -----------------------------
echo  Navicli must be installed
echo  on this machine in the default
echo  directory:
echo. 
echo  c:\Program Files\EMC\Navisphere CLI\
echo ------------------------------
GOTO :END

:NO_PSLIST
echo ------------------------------
echo Could not locate %pslist%
echo Please install PSTools from
echo %PSTOOLS_URL%
echo Thank You
echo ------------------------------
goto :end

:NO_PSEXEC
echo ------------------------------
echo Could not locate %psexec%
echo Please install PSTools from
echo %PSTOOLS_URL%
echo Thank You
echo ------------------------------
goto :end

:NO_PSKILL
echo ------------------------------
echo Could not locate %pskill%
echo Please install PSTools from
echo %PSTOOLS_URL%
echo Thank You
echo ------------------------------
goto :end

:NO_EMCREPORTS
echo ------------------------------
echo Could not locate %EMCREPORTS_EXE%
echo Please install from http://powerlink.emc.com
echo %EMCREPORTS_URL%
echo Thank You
echo ------------------------------
goto :end



::=================================End Error Control========================


:HELP
echo ------------------------------
echo.
echo  The command line syntax for 
echo  this app is:
echo  %0 Username Password SP_IP_Address
echo  Or 
echo  %0 /f Host_list_FileName
echo.  
echo ------------------------------
Help request only >> %LOG%
goto :END

:ACCEPT_EULA
::--------------------------------
:: Run each of the pstools
:: one at a time to make sure
:: they are license accepted
:: otherwise it blows things
:: up during the loop and execution
:: of the tools to remote execute
::--------------------------------

ECHO =======================================
ECHO.
ECHO Running each of the following to allow
echo the use to accept the EULA's before
echo the initial run of the script for
echo production host gathers

echo %psexec%&& call %psexec%
echo %pslist%&& call %pslist%
echo %pskill%&& call %pskill%
echo delete %EULA% to avoid the EULA's&& del %EULA%
echo.
echo End of setup phase
Echo please report any issues to
Echo 	Aaron Baldie
echo	baldie_aaron@emc.com
echo =======================================
goto :END



:END
