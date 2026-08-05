#!/bin/bash
# 生成 media.json（Linux 版本）

outfile="media.json"

# 清理旧文件
[ -f "$outfile" ] && rm -f "$outfile"

# JSON 字符串转义函数（处理反斜杠和双引号）
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

# 收集图片文件（不区分大小写，不重复）
shopt -s nullglob nocaseglob
files=(*.jpg *.jpeg *.png *.gif *.bmp)
shopt -u nocaseglob

# 去重（避免同一文件因大小写匹配被收录两次，例如同时匹配 *.jpg 和某些大小写变体）
declare -A seen
unique_files=()
for f in "${files[@]}"; do
    if [ -f "$f" ] && [ -z "${seen[$f]}" ]; then
        seen["$f"]=1
        unique_files+=("$f")
    fi
done
files=("${unique_files[@]}")

filecount=${#files[@]}

# 没有文件的情况
if [ "$filecount" -eq 0 ]; then
    cat > "$outfile" <<EOF
{
  "title": "",
  "description": "",
  "custom_thumbnail": "",
  "datetime": "",
  "reverse": false,
  "images": {}
}
EOF
    echo "没有找到图片文件"
    exit 0
fi

# 第一个文件作为缩略图
thumb="${files[0]}"
thumb_escaped=$(json_escape "$thumb")

# 写入JSON开始部分
{
    echo "{"
    echo "  \"title\": \"\","
    echo "  \"description\": \"\","
    echo "  \"custom_thumbnail\": \"$thumb_escaped\","
    echo "  \"datetime\": \"\","
    echo "  \"reverse\": false,"
    echo "  \"images\": {"
} > "$outfile"

# 写入所有文件
for i in "${!files[@]}"; do
    fname_escaped=$(json_escape "${files[$i]}")
    if [ "$i" -eq $((filecount - 1)) ]; then
        # 最后一个文件，不加逗号
        {
            echo "    \"$fname_escaped\": {"
            echo "        \"description\": \"\""
            echo "    }"
        } >> "$outfile"
    else
        {
            echo "    \"$fname_escaped\": {"
            echo "        \"description\": \"\""
            echo "    },"
        } >> "$outfile"
    fi
done

# JSON 结束
{
    echo "  }"
    echo "}"
} >> "$outfile"

echo "生成完成: $outfile"
echo "共处理 $filecount 个文件"
