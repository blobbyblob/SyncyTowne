@echo off
set command=%1

if "%command%" equ "" set command=run
if "%command%" equ "run" (
	taskkill /F /IM python.exe /T >nul 2>nul
	python server/main.py
)
if "%1" equ "test" (
	pushd server
	python -m unittest test
	popd
)
if "%command%" equ "doc" (
	ldoc . || where ldoc
)
