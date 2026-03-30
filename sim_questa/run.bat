@echo off
REM Batch script to run Questa Sim simulation
REM Make sure Questa/ModelSim is in your PATH

echo ============================================
echo Bit-Trix CPU - Questa Sim Simulation
echo ============================================

REM Check if vsim is available
where vsim >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: vsim not found in PATH
    echo Please add Questa/ModelSim to your PATH
    pause
    exit /b 1
)

REM Copy memory files to this directory
echo Copying memory files...
copy /Y ..\opcode_gen\program.mem . >nul
copy /Y ..\src\data.mem . >nul 2>nul

REM Run simulation
echo Running simulation...
vsim -do run_sim.do

echo Done!
pause
