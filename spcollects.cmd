@If "%echoon%"=="" @echo off
If "%local%"=="" setlocal
set NOPAUSE=
set NOCLS=
If "%pauseon%"=="" set NOPAUSE=::
If not "%clson%"=="" set NOCLS=::
::=============================
::
:: SPCollect.cmd is used to 
:: Automatically start and grab
:: an spcollect file from an 
:: EMC array to speed the time
:: to resolution of any type of
:: Problem.
::
:: Tested Platforms:
:: Windows Server 2003 SP1
:: Navicli ver 6.16.00.04.63
:: Flare 16 Patch 12
::
:: Aaron Baldie
:: EMC (c)
:: Version 0.1
:: 06/29/05
::=============================

::------------------------------
:: Setup logging files and paths
::------------------------------
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
SET IPLIST=
SET DATETIME=
SET SP=
SET DATADIR=
SET COUNTER=1
SET PASS=
SET FILENAME=
SET USER=
SET PWD=
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
:: Setup static env vars
::--------------------------------
If Exist "c:\Program Files\emc\Navisphere CLI\naviseccli.exe" set NAVICLI="c:\Program Files\emc\Navisphere CLI\naviseccli.exe"
If Exist "c:\Program Files (x86)\emc\Navisphere CLI\naviseccli.exe" set NAVICLI="c:\Program Files (x86)\emc\Navisphere CLI\naviseccli.exe"
set SMTPMAIL="c:\Program Files\emc\Navisphere Agent\smtpmail.exe"

::--------------------------------
:: Check for the navicli.exe file
:: If not present error out and 
:: give the help screen
::--------------------------------
If not exist %NAVICLI% goto :NOCLI

::--------------------------------
:: Now set up the extended command
:: for seccli with -user -password
::--------------------------------
set %NAVICLI%=%NAVICLI% -User %user% -Password %pwd% -Scope 0

:STARTCOLLECT

::--------------------------------
:: Check that there is SP address
::--------------------------------
If "%SP%"=="" GOTO :NOSP

::--------------------------------
:: Set up a working directory for
:: This arrays collection based on
:: SP_IP and date/time stamp
::--------------------------------
set DATADIR=%SP%_%DATETIME%
mkdir %DATADIR%

::--------------------------------
:: Perform a managefiles -list
:: to get the arrays current file
:: state so we can parse and figure
:: out which file we need to grab
:: and when the spcollect completes
::--------------------------------
if exist %DATADIR%\%SP%_ORIG.log del %DATADIR%\%SP%_ORIG.log
for /f "tokens=1-5" %%a in ('%NAVICLI% -h %SP% managefiles -list') do echo %%e | findstr /i "data" >> %DATADIR%\%SP%_ORIG.log

::--------------------------------
:: Start the collection of splogs
::--------------------------------
%navicli% -h %SP% spcollect -messner > %DATADIR%\%SP%_collect-errors.log
If %ERRORLEVEL%==66 goto :NOSPCOLLECT

:COLLECTING
::--------------------------------
:: Now watch the collection and
:: report when the file is ready 
:: to be downloaded
::--------------------------------
if exist %DATADIR%\%SP%_NEW.log del %DATADIR%\%SP%_NEW.log
for /f "tokens=1-5" %%a in ('%NAVICLI% -h %SP% managefiles -list') do echo %%e | findstr /i "data" >> %DATADIR%\%SP%_NEW.log

::--------------------------------
:: Now the cool part what file
:: is the new file that we should
:: tell navicli to download
:: A little elimination game should
:: get us where we need to be
::--------------------------------
for /f %%x in (%DATADIR%\%SP%_ORIG.LOG) do findstr /v "%%x" %DATADIR%\%SP%_NEW.log> %DATADIR%\%SP%_HOLD.log & type %DATADIR%\%SP%_HOLD.log> %DATADIR%\%SP%_NEW.log & del %DATADIR%\%SP%_HOLD.log
GOTO :IN_PROCESS

:IN_PROCESS
::--------------------------------
:: Watch to see if a new file
:: shows up in the managefiles
:: list, if so we are done and
:: ready to collect the file.
:: Otherwise go to wait and 
:: then come back again.
::--------------------------------
for /f %%x in (%DATADIR%\%SP%_NEW.LOG) do set FILENAME=%%x
If "%FILENAME%"=="" GOTO :WAIT
pushd %DATADIR%
%NAVICLI% -h %SP% managefiles -retrieve -file %FILENAME% -o
popd
Echo Success, the file is located in the directory:
Echo		.\%DATADIR%
ECHO And is called:
Echo		 %FILENAME%
Echo Have a great day...
::--------------------------------
:: Program is over skip to the end
::--------------------------------
GOTO :END

:WAIT
::--------------------------------
:: Little Ping set to setup a 10
:: second waiting period
::--------------------------------
ping 127.0.0.1 -n 2 -w 1000 > nul
ping 127.0.0.1 -n 10 -w 1000> nul
%NOCLS%cls
ECHO Script was started %DATETIME%
ECHO Current Time is:
time /t
SET PASS=%PASS% %COUNTER%
Echo Waiting for collection to finish: Pass %PASS%
set /A COUNTER+=1
GOTO :COLLECTING

::===========================Error Control Below Here=====================

:NOAGENTCONFIG
echo -----------------------------
Echo  The agent config file must
echo  be in the same directory (%~dp0)
echo  as this batch file (%0)
echo -----------------------------
GOTO :END

:NOCLI
echo -----------------------------
echo  Navicli must be installed
echo  on this machine in the default
echo  directory:
echo 
echo  c:\Program Files\EMC\Navisphere CLI\
echo ------------------------------
GOTO :END

:NOSP
echo ------------------------------
echo You must have an ip address
echo to be able to collect the 
echo log files
echo please enter an ip address
echo syntax is:
echo %0 SP_IP_Address
echo ------------------------------
goto :END

:NOSPCOLLECT
echo ------------------------------
echo There was a problem with starting
echo the spcollect on the system
echo %SP%
echo Here is the content of that error
type %DATADIR%\%SP%_collect-errors.log
echo ------------------------------
goto :END
::=================================End Error Control========================


:HELP
echo ------------------------------
echo  The command line syntax for 
echo  this app is:
echo  %0 SP_IP_Address
echo 
echo 
echo ------------------------------
Help request only >> %LOG%
goto :END

:END
endlocal
