#!/bin/sh
set -o errexit
trap '
if [ $? -ne 0 ]
then 
    echo "================"
    echo "安装失败，请检查 /tmp/redis_install.log"
    echo "================"
    echo ""
fi
' EXIT

START_PORT=7000
IP_ADDR=127.0.0.1
BASE_DIR=/tmp/redis
REDIS_NUM=6
IMAGE=redis:latest
LOG_FILE=/tmp/redis_install.log
CLUSTER_STR=

CONFIG_CONTENT="
bind 0.0.0.0
protected-mode no
daemonize no
appendonly yes
cluster-enabled yes
cluster-config-file nodes.conf
"
while read line
do
    CONFIG_CONTENT=$CONFIG_CONTENT" \n$line"
done << EOF
$ENV_CONFIG_CONTENT
EOF

check_args()
{
    if [ ! -z $ENV_IP_ADDR ]
    then
        IP_ADDR=$ENV_IP_ADDR
    fi
    
    if [ ! -z $ENV_START_PORT ]
    then
        START_PORT=$ENV_START_PORT
    fi
    
    if [ ! -z $ENV_BASE_DIR ]
    then
        BASE_DIR=$ENV_BASE_DIR
    fi
    
    if [ ! -z $ENV_REDIS_NUM ]
    then
        REDIS_NUM=$ENV_REDIS_NUM
    fi
    
    args="START_PORT $START_PORT
    IP_ADDR $IP_ADDR
    BASE_DIR $BASE_DIR
    REDIS_NUM $REDIS_NUM
    IMAGE $IMAGE"

    name_width=20
    age_width=20
    total_width=$((name_width + age_width + 7))
    
    printf '+%.0s' $(seq 1 $total_width)
    printf '\n'
    printf "| %-*s | %-*s |\n" "$name_width" "parameter" "$age_width" "value"
    printf '+%.0s' $(seq 1 $total_width)
    printf '\n'
    echo "$args" | while IFS=" " read -r name age; do
        printf "| %-*s | %-*s |\n" "$name_width" "$name" "$age_width" "$age" 
    done
    printf '+%.0s' $(seq 1 $total_width)
    printf '\n'
    printf '\n'
    printf '+%.0s' $(seq 1 20)
    printf '\n'
    echo "redis.conf 新增参数："
    printf '+%.0s' $(seq 1 20)
    printf '\n'
    echo "$ENV_CONFIG_CONTENT"
    printf '+%.0s' $(seq 1 20)
    printf '\n'
    read -p "请确认上述参数是否符合预期(yes/no): " res
    
    echo ''
    if [ $res = "yes" ]
    then
        echo '符合预期，安装继续'
    else
        echo '不符合预期，安装结束'
        exit 0
    fi
}

check_image_exists()
{
    if docker image inspect "$IMAGE" > /dev/null 2>&1; then
        check_image_exists_return="镜像 $IMAGE 已存在"
    else
        check_image_exists_return="镜像 $IMAGE_NAME 不存在，拉取中..."
        docker pull "$IMAGE"
    fi
}

check_args
echo "================"

check_image_exists
echo $check_image_exists_return > $LOG_FILE 2>&1
mkdir -p $BASE_DIR/conf $BASE_DIR/data

for count in $(seq 1 $REDIS_NUM)
do
    CONFIG_CONTENT_NODE=$CONFIG_CONTENT
    CONFIG_CONTENT_NODE="port $START_PORT\n"$CONFIG_CONTENT_NODE
    CONFIG_CONTENT_NODE="cluster-announce-ip $IP_ADDR\n"$CONFIG_CONTENT_NODE
    CONFIG_CONTENT_NODE="cluster-announce-port $START_PORT\n"$CONFIG_CONTENT_NODE
    CONFIG_CONTENT_NODE="cluster-announce-bus-port 1$START_PORT\n"$CONFIG_CONTENT_NODE
    echo "$CONFIG_CONTENT_NODE" > $BASE_DIR/conf/$START_PORT.conf
    echo "启动第$count个节点..."
    docker run -d --network=host --name=redis-cluster-$START_PORT \
        -p $START_PORT:$START_PORT \
        -p 1$START_PORT:1$START_PORT \
        -v $BASE_DIR/conf/$START_PORT.conf:/etc/redis.conf \
        $IMAGE \
        /usr/local/bin/redis-server /etc/redis.conf >> $LOG_FILE 2>&1

    echo "第$count个节点启动成功！"
    CLUSTER_STR=$CLUSTER_STR" $IP_ADDR:$START_PORT"
    START_PORT=`expr $START_PORT + 1`
done

echo "================"
echo "等待集群初始化..."
sleep 3
redis-cli --cluster create $CLUSTER_STR --cluster-replicas 1 --cluster-yes >> $LOG_FILE 2>&1
echo "集群安装成功"

print_nodes()
{
    name_width=20
    total_width=$((name_width + 4))

    printf '+%.0s' $(seq 1 $total_width)
    printf '\n'
    printf "| %-*s |\n" "$name_width" "node" 
    printf '+%.0s' $(seq 1 $total_width)
    printf '\n'
    echo "$CLUSTER_STR" | xargs -n 1 | while IFS=" " read -r name; do
        printf "| %-*s |\n" "$name_width" "$name"
    done
    printf '+%.0s' $(seq 1 $total_width)
    printf '\n'
}
print_nodes

