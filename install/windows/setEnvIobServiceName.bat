@echo off
set iobServiceName=
if exist .env (
for /F "tokens=*" %%I in (.env) do set %%I
)
if not defined iobServiceName (
	set iobServiceName=ioBroker
)
echo ioBroker service name: %iobServiceName%
