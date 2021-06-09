@echo off
set xv_path=C:\\Xilinx\\Vivado\\2016.4\\bin
call %xv_path%/xsim SevenSegmentControlTop_behav -key {Behavioral:sim_1:Functional:SevenSegmentControlTop} -tclbatch SevenSegmentControlTop.tcl -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0
