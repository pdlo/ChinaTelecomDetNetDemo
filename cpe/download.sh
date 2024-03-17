# 此脚本用于在tofino上从github上单独下载这两个文件(考虑到tofino性能有限)
github_url="https://raw.githubusercontent.com/Meltsun/ChinaTelecomDetNetDemo/main/cpe/"
file_names=(
    "srv6_tofino.p4"
    "start.sh"
)

# 使用WXY电脑上运行的代理程序
http_proxy="http://219.242.112.169:1145"

for file_name in "${file_names[@]}"; do
    echo $file_name
    curl -o $file_name "${github_url}${file_name}"
done
