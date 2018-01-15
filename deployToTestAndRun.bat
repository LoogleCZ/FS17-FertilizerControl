@echo off

REM 
REM Who the f*** created windows batch!? 
REM

setlocal EnableDelayedExpansion

set templateFile=.\testTemplate.txt
set game=C:\Program Files (x86)\Farming Simulator 2017\FarmingSimulator2017.exe

set /a counter=0
set script=

for /f ^"usebackq^ eol^=^

^ delims^=^" %%a in (%templateFile%) do (
	if "!counter!"=="0" (
		set script=%%a
	) else (
		if not "!script!"=="" (
			copy "!script!" "%%a" /Y
		)
	)
	set /a counter+=1
)

"%game%"

