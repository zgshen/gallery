@echo off
setlocal enabledelayedexpansion

:: 输出文件
set "outfile=media.json"

:: 写入 JSON 头部（先写到文件，但 custom_thumbnail 暂留空）
(
  echo {
  echo   "title": "",
  echo   "description": "",
  echo   "custom_thumbnail": "",
  echo   "datetime": "",
  echo   "images": {
) > "%outfile%"

:: 收集图片文件到变量（不区分大小写）
set "files="
for %%F in (*.jpg *.jpeg *.png *.gif *.bmp *.JPG *.JPEG *.PNG *.GIF *.BMP) do (
    if exist "%%F" (
        if defined files (
            set "files=!files!;%%F"
        ) else (
            set "files=%%F"
        )
    )
)

:: 如果没找到文件，直接结束
if not defined files (
    >>"%outfile%" echo   }
    >>"%outfile%" echo }
    echo 没有找到图片文件。
    pause
    exit /b
)

:: 计算总数
set "count=0"
for %%A in (!files!) do set /a count+=1

:: 取第一个文件作为 custom_thumbnail
for %%A in (!files!) do (
    set "thumb=%%A"
    goto :gotThumb
)
:gotThumb

:: 先将头部文件重写，加入 custom_thumbnail
(
  echo {
  echo   "title": "",
  echo   "description": "",
  echo   "custom_thumbnail": "!thumb!",
  echo   "datetime": "",
  echo   "images": {
) > "%outfile%"

:: 写入图片条目
set "i=0"
for %%A in (!files!) do (
    set /a i+=1
    if !i! lss %count% (
        >>"%outfile%" echo     "%%A": {
        >>"%outfile%" echo         "description": ""
        >>"%outfile%" echo     },
    ) else (
        >>"%outfile%" echo     "%%A": {
        >>"%outfile%" echo         "description": ""
        >>"%outfile%" echo     }
    )
)

:: JSON 结尾
>>"%outfile%" echo   }
>>"%outfile%" echo }

echo 生成完成: %outfile%
pause
