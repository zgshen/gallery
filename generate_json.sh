#!/bin/bash
# 生成 media.json（兼容 bash 3.2 / Linux / macOS）
# 用法: ./generate_json.sh [图片文件夹]
# 不指定文件夹时使用当前目录，并在该目录生成 media.json
# 如果该文件夹下已有 media.json，则保留其中的 title、description、
# custom_thumbnail、datetime、reverse 字段的值，以及每张图片已有的 description，
# 只根据当前文件夹里的图片更新 images 列表（新图片加入，已删除的图片移除）

if [ "$#" -gt 1 ]; then
    echo "用法: $0 [图片文件夹]" >&2
    exit 1
fi

target_dir="${1:-.}"

if [ ! -d "$target_dir" ]; then
    echo "错误: 文件夹不存在: $target_dir" >&2
    exit 1
fi

# 进入目标文件夹，后续读取图片和写入 media.json 的逻辑保持不变
cd -- "$target_dir" || {
    echo "错误: 无法进入文件夹: $target_dir" >&2
    exit 1
}

outfile="media.json"

# JSON 字符串转义函数（处理反斜杠和双引号）
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# 从一段 JSON 文本中读取某个字段的原始 JSON 值
# 参数: $1=文本  $2=字段名；找到则输出原始值（字符串带引号）并返回 0
read_old_field() {
    local str_re='"([^"\\]|\\.)*"'
    local re="\"$2\"[[:space:]]*:[[:space:]]*(${str_re}|[^,}[:space:]]+)"
    if [[ $1 =~ $re ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
        return 0
    fi
    return 1
}

# 默认值（原来没有 media.json，或其中缺少某个字段时使用）
v_title='""'
v_description='""'
v_datetime='""'
v_reverse='false'
v_thumb=""
has_old=0

# 旧 media.json 里每张图片的名称和描述（原始 JSON 文本），两个数组按下标一一对应
old_names=()
old_descs=()

if [ -f "$outfile" ]; then
    has_old=1
    old_content=$(cat -- "$outfile")
    # "images" 之前的部分是顶层字段，避免误读图片里的字段
    old_header="${old_content%%\"images\"*}"

    val=$(read_old_field "$old_header" title) && v_title="$val"
    val=$(read_old_field "$old_header" description) && v_description="$val"
    val=$(read_old_field "$old_header" custom_thumbnail) && v_thumb="$val"
    val=$(read_old_field "$old_header" datetime) && v_datetime="$val"
    val=$(read_old_field "$old_header" reverse) && v_reverse="$val"

    # 逐个读取旧 images 里的 “文件名: { ... }” 条目，记下各自的 description
    if [[ "$old_content" == *'"images"'* ]]; then
        rest="${old_content#*\"images\"}"
        img_re='"((\\.|[^"\\])*)"[[:space:]]*:[[:space:]]*(\{([^{}"]|"(\\.|[^"\\])*")*\})'
        while [[ $rest =~ $img_re ]]; do
            matched="${BASH_REMATCH[0]}"
            d=$(read_old_field "${BASH_REMATCH[3]}" description) || d='""'
            old_names+=("${BASH_REMATCH[1]}")
            old_descs+=("$d")
            rest="${rest#*"$matched"}"
        done
    fi
fi

# 按文件名查找旧描述；结果放在 found_desc。
# 从上一次命中位置的下一项开始找，图片顺序没变时每次基本只比较一次
last=0
found_desc=""
lookup_desc() {
    local n=${#old_names[@]} k=0 idx
    found_desc=""
    [ "$n" -eq 0 ] && return 1
    while [ "$k" -lt "$n" ]; do
        idx=$(( (last + k) % n ))
        if [ "${old_names[$idx]}" = "$1" ]; then
            found_desc="${old_descs[$idx]}"
            last=$((idx + 1))
            return 0
        fi
        k=$((k + 1))
    done
    return 1
}

# 收集图片文件（不区分大小写，兼容 bash 3.2）
files=()
for f in *; do
    [ -f "$f" ] || continue
    case "$f" in
        *.[jJ][pP][gG]|*.[jJ][pP][eE][gG]|*.[pP][nN][gG]|*.[gG][iI][fF]|*.[bB][mM][pP])
            files+=("$f")
            ;;
    esac
done

filecount=${#files[@]}

# 缩略图：旧文件里有 custom_thumbnail 就沿用，否则用第一个图片文件，没有图片则为空
if [ -z "$v_thumb" ]; then
    if [ "$filecount" -gt 0 ]; then
        v_thumb="\"$(json_escape "${files[0]}")\""
    else
        v_thumb='""'
    fi
fi

# 先写到临时文件，成功后再替换，避免中途出错丢失原有 media.json
tmpfile="${outfile}.tmp.$$"

{
    echo "{"
    echo "  \"title\": $v_title,"
    echo "  \"description\": $v_description,"
    echo "  \"custom_thumbnail\": $v_thumb,"
    echo "  \"datetime\": $v_datetime,"
    echo "  \"reverse\": $v_reverse,"
} > "$tmpfile"

if [ "$filecount" -eq 0 ]; then
    # 没有文件的情况
    echo "  \"images\": {}" >> "$tmpfile"
    echo "}" >> "$tmpfile"
    mv -f -- "$tmpfile" "$outfile"
    [ "$has_old" -eq 1 ] && echo "已保留原有 media.json 的字段"
    echo "没有找到图片文件"
    exit 0
fi

echo "  \"images\": {" >> "$tmpfile"

# 写入所有文件
kept=0
for i in "${!files[@]}"; do
    fname_escaped=$(json_escape "${files[$i]}")

    # 旧文件里有这张图片的描述就沿用，否则为空
    desc='""'
    if lookup_desc "$fname_escaped"; then
        [ -n "$found_desc" ] && desc="$found_desc"
        kept=$((kept + 1))
    fi

    if [ "$i" -eq $((filecount - 1)) ]; then
        # 最后一个文件，不加逗号
        {
            echo "    \"$fname_escaped\": {"
            echo "        \"description\": $desc"
            echo "    }"
        } >> "$tmpfile"
    else
        {
            echo "    \"$fname_escaped\": {"
            echo "        \"description\": $desc"
            echo "    },"
        } >> "$tmpfile"
    fi
done

# JSON 结束
{
    echo "  }"
    echo "}"
} >> "$tmpfile"

mv -f -- "$tmpfile" "$outfile"

if [ "$has_old" -eq 1 ]; then
    echo "已保留原有 media.json 的 title/description/custom_thumbnail/datetime/reverse"
    echo "沿用了 $kept 张图片已有的描述"
fi
echo "生成完成: ${target_dir%/}/$outfile"
echo "共处理 $filecount 个文件"
