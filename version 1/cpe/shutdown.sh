echo "寻找并杀死现有switchd进程"

pgrep -f switchd | while read -r pid; do
    echo "发现switchd进程 $pid"
    sudo kill "$pid"
    echo "已杀死"
done