#!/bin/bash
# 将当前目录下 jpg/jpeg 图片文件名中的空格替换为短横线 "-"
# 不处理隐藏文件

shopt -s nullglob nocaseglob

for f in *.jpg *.jpeg; do
    # 只处理文件
    [ -f "$f" ] || continue

    # 文件名中没有空格则跳过
    case "$f" in
        *" "*) ;;
        *) continue ;;
    esac

    newname="${f// /-}"

    # 避免覆盖已存在的同名文件
    if [ -e "$newname" ]; then
        echo "跳过（目标已存在）: $f -> $newname"
        continue
    fi

    mv -- "$f" "$newname"
    echo "重命名: $f -> $newname"
done

echo "完成"
