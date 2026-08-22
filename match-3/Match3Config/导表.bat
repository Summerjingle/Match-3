@echo off
chcp 65001 >nul
rem 去掉 %~dp0 结尾的反斜杠，避免引号紧贴 \ 导致参数粘连
set "CFGDIR=%~dp0"
set "CFGDIR=%CFGDIR:~0,-1%"
set PYTHONIOENCODING=utf-8
python "%CFGDIR%\..\Tools\export_json.py" "%CFGDIR%" "%CFGDIR%\..\Config"
pause
