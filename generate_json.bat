@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: 输出文件
set "outfile=media.json"

:: 清理旧文件
if exist "%outfile%" del "%outfile%"

:: 直接收集文件到数组中，避免临时文件
set /a filecount=0
set "files="

:: 收集所有图片文件（不区分大小写，避免重复）
for %%F in (*.jpg *.jpeg *.png *.gif *.bmp) do (
    set /a filecount+=1
    set "file[!filecount!]=%%F"
    if "!files!"=="" (
        set "files=%%F"
    ) else (
        set "files=!files! %%F"
    )
)

:: 检查是否有文件
if %filecount%==0 (
    echo {> "%outfile%"
    echo   "title": "",>> "%outfile%"
    echo   "description": "",>> "%outfile%"
    echo   "custom_thumbnail": "",>> "%outfile%"
	echo   "datetime": "",>> "%outfile%"
	echo   "reverse": false,>> "%outfile%"
    echo   "images": {}>> "%outfile%"
    echo }>> "%outfile%"
    echo 没有找到图片文件
    pause
    exit /b
)

:: 使用第一个文件作为缩略图
set "thumb=!file[1]!"

:: 写入JSON开始部分
echo {> "%outfile%"
echo   "title": "",>> "%outfile%"
echo   "description": "",>> "%outfile%"
echo   "custom_thumbnail": "!thumb!",>> "%outfile%"
echo   "datetime": "",>> "%outfile%"
echo   "reverse": false,>> "%outfile%"
echo   "images": {>> "%outfile%"

:: 写入所有文件
for /l %%i in (1,1,%filecount%) do (
    if %%i==%filecount% (
        :: 最后一个文件，不加逗号
        echo     "!file[%%i]!": {>> "%outfile%"
        echo         "description": "">> "%outfile%"
        echo     }>> "%outfile%"
    ) else (
        :: 不是最后一个文件，加逗号
        echo     "!file[%%i]!": {>> "%outfile%"
        echo         "description": "">> "%outfile%"
        echo     },>> "%outfile%"
    )
)

:: JSON结束
echo   }>> "%outfile%"
echo }>> "%outfile%"

echo 生成完成: %outfile%
echo 共处理 %filecount% 个文件
pause