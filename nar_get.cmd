@If "%echoon%"=="" @echo off
If "%local%"=="" setlocal
set NOPAUSE=
set NOCLS=
If "%pauseon%"=="" set NOPAUSE=::
If not "%clson%"=="" set NOCLS=::
::=============================
::
:: nar_get.cmd is used to 
:: Automatically start and grab
:: a nar file from an 
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
:: 05/03/06
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
:: If there is a command line param
:: Go ahead and set it
::--------------------------------
set username=%1
set password=%2
set ip=%3

::--------------------------------
:: Check all of the user vars
::--------------------------------
If "%username%"=="" GOTO :NOUSERNAME
If "%password%"=="" GOTO :NOPASSWORD
If "%ip%"=="" GOTO :NOIP

::--------------------------------
:: Ah, the infamous date/time
:: loop to create stamped file 
:: names
::--------------------------------
for /f "tokens=1-3 delims=/" %%x in ('date /t') do set year=%%z&& set day=%%y&& set month=%%x
set year=%year:~0,4%
set day=%day:~0,2%
set month=%month:~4,6%
for /f "tokens=1-2 delims=:" %%a in ('time /t') do set hour=%%a&& set min=%%b
set min=%min:~0,2%


::--------------------------------
:: Setup static env vars
::--------------------------------
if exist "c:\Program Files\emc\Navisphere CLI\navicli.exe" set NAVICLI="c:\Program Files\emc\Navisphere CLI\navicli.exe"
if exist "c:\Program Files (x86)\emc\Navisphere CLI\navicli.exe" set NAVICLI="c:\Program Files (x86)\emc\Navisphere CLI\navicli.exe"

if exist "c:\Program Files\emc\Navisphere CLI\archiveretrieve.jar set ARCHIVE="c:\Program Files\emc\Navisphere CLI\archiveretrieve.jar"
if exist "c:\Program Files (x86)\emc\Navisphere CLI\archiveretrieve.jar set ARCHIVE="c:\Program Files (x86)\emc\Navisphere CLI\archiveretrieve.jar"

::--------------------------------
:: Check for the navicli.exe file
:: If not present error out and 
:: give the help screen
::--------------------------------
If not exist %NAVICLI% goto :NOCLI

::--------------------------------
:: Check for the navicli.exe file
:: If not present error out and 
:: give the help screen
::--------------------------------
If not exist %ARCHIVE% goto :NOARCHIVE

:STARTCOLLECT
If not exist %ip% md %ip%

::--------------------------------
:: Give some feedback to the user
::--------------------------------
%NOCLS%cls
echo ******************************************
echo Collection Array info on %month% %day% %year% @ %hour%:%min%
%NAVICLI% -h %ip% getagent > %ip%_getagent.txt

echo reading Array info
for /f "tokens=3" %%x in ('findstr /s "Serial" %ip%_getagent.txt') do set serial=%%x
echo You are working on %serial%
for /f "tokens=3" %%x in ('findstr /s "Identifier" %ip%_getagent.txt') do set sp=%%x
echo The Current SP is %sp%
echo Collecting the nar file
java -jar %ARCHIVE% -User %username% -Password %password% -Address %ip% -File %year%_%month%_%day%-%hour%_%min%-%serial%_SP%sp%.nar -Location %ip%
echo Nar file %year%_%month%_%day%-%hour%_%min%-%serial%_SP%sp%.nar has been collected
echo The content of directory %ip% are:
echo =================================
dir /b %ip% | findstr /i "%serial%"
echo =================================
echo *******************************************
del %ip%_getagent.txt

::------------------------------------
:: Log everything
::------------------------------------
echo ****************************************** >> %LOG%
echo Collection Array info on %month% %day% %year% @ %hour%:%min% >> %LOG%
echo reading Array info >> %LOG%
echo You are working on %serial% >> %LOG%
echo The Current SP is %sp% >> %LOG%
echo Collecting the nar file >> %LOG%
echo Nar file %year%_%month%_%day%-%hour%_%min%-%serial%_SP%sp%.nar has been collected >> %LOG%
echo The content of directory %ip% are: >> %LOG%
echo ================================= >> %LOG%
dir /b %ip% | findstr /i "%serial%" >> %LOG%
echo ================================= >> %LOG%
echo ******************************************* >> %LOG%

echo Have a great day!!!
goto :END

::===========================Error Control Below Here=====================

:NOUSERNAME
echo -----------------------------
Echo  You need to enter a username
echo %0 Username Password SP_IP_Address
echo -----------------------------
GOTO :END

:NOPASSWORD
echo -----------------------------
echo  You need to enter a password
echo %0 Username Password SP_IP_Address
echo ------------------------------
GOTO :END

:NOIP
echo ------------------------------
echo You must have an ip address
echo to be able to collect the 
echo log files
echo please enter an ip address
echo syntax is:
echo %0 Username Password SP_IP_Address
echo ------------------------------
goto :END

:NOCLI
echo -----------------------------
echo  Navicli must be installed
echo  on this machine in the default
echo  directory:
echo 
echo  c:\Program Files\EMC\Navisphere CLI\
echo ------------------------------
GOTO :END

:NOARCHIVE
echo -----------------------------
echo  archiveretrieve must be installed
echo  on this machine in the default
echo  directory:
echo 
echo  c:\Program Files\EMC\Navisphere CLI\
echo ------------------------------
GOTO :END

::=================================End Error Control========================


:HELP
echo ------------------------------
echo  The command line syntax for 
echo  this app is:
echo  %0 Username Password IP_Address
echo 
echo ------------------------------
echo Help request only >> %LOG%
goto :END

:END
endlocal
