#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# 脚本会自动获取你的公网IPv4或者IPv6并更新到CloudFlare对应的记录上
# 能够自动获取你的Cloudflare Zone ID 和Record ID

# 用法:
# cf-ddns.sh -k <你的cloudflare api key> \
#            -u <Cloudflare登录邮箱> \
#            -h <host.example.com> \     # 你想要DDNS的完整域名
#            -z <example.com> \          # 主域名，即二级域名，或者说站点名称
#            -t <A|AAAA>                 # IPv4模式或者IPv6模式；默认IPv4

# 可选参数:
#            -f false|true \           # 强制更新记录，忽略本地ip文件

##################################################################################
# 以下为默认配置，在没有填写命令行参数的情况下有效。
# 命令行参数会覆盖下面的配置

# 你的Global API Key, 请见 https://dash.cloudflare.com/profile/api-tokens,
# 如果填写错误会造成请求错误
CFKEY="b8c657a9b6ca96ba9babfdd9fa8bfa9dba9bf"

# Cloudflare登录邮箱, 例如: user@example.com
CFUSER="username@example.com"

# 主域名，即二级域名，或者说站点名称, 例如: example.com
CFZONE_NAME="example.com"

# 想要进行ddns的域名, 例如: homeserver.example.com，也可以是二级域名如 example.com
# 请分别设置用于IPv4 DDNS 和 IPv6 DDNS 的域名。当然，两者可以相同也可以其中一个不填（如果你用不着其中一项的话）
CFRECORD_NAMEV4="ddns.example.com"
CFRECORD_NAMEV6="ddnsv6.example.com"

# 记录类型, A(IPv4)|AAAA(IPv6), 默认 IPv4
CFRECORD_TYPE="A"

# TTL设置, 在 120 和 86400 秒之间
CFTTL=120

# 忽略本地ip文件，强制更新记录
FORCE=false

# 用于获取公网IP的地址, 可以换成其他的比如: bot.whatismyipaddress.com, https://api.ipify.org/ ...
# 请分别设置用于IPv4 DDNS 和 IPv6 DDNS 的参数。当然，两者可以相同也可以其中一个不填（如果你用不着其中一项的话）
WANIPSITEV4="http://ipv4.icanhazip.com" 
WANIPSITEV6="http://ipv6.icanhazip.com" 

# 这个文件将会存储你的zoneid和recordid等信息，可以是绝对路径或者相对路径
# 请分别设置用于IPv4 DDNS 和 IPv6 DDNS 的路径。当然，两者可以相同也可以其中一个不填（如果你用不着其中一项的话）
ID_FILEV4="cloudflare.v4.ids" 
ID_FILEV6="cloudflare.v6.ids"

# 这个文件将会在每一次IPv4地址变更后存储下当前IP，作为对比
# 请分别设置用于IPv4 DDNS 和 IPv6 DDNS 的路径。当然，两者可以相同也可以其中一个不填（如果你用不着其中一项的话）
WAN_IP_FILEV4="ipv4.txt"
WAN_IP_FILEV6="ipv6.txt"

# 日志文件路径，分别是IPv4和IPv6，可以为同一个，不会互相覆盖
LOG_FILEV4="cf_ddns.log"
LOG_FILEV6="cf_ddns.log"

# 配置部分结束
#############################################################################

log() {
    if [ "$1" ]; then
        echo -e "[$(date)] - $1" >> $LOG_FILE
    fi
}

# 获取参数
while getopts k:u:h:z:t:f: opts; do
  case ${opts} in
    k) CFKEY=${OPTARG} ;;
    u) CFUSER=${OPTARG} ;;
    h) CFRECORD_NAME=${OPTARG} ;;
    z) CFZONE_NAME=${OPTARG} ;;
    t) CFRECORD_TYPE=${OPTARG} ;;
    f) FORCE=${OPTARG} ;;
  esac
done

if [ "$CFRECORD_TYPE" = "A" ]; then
  ID_FILE=$ID_FILEV4
  WAN_IP_FILE=$WAN_IP_FILEV4
  LOG_FILE=$LOG_FILEV4
  CFRECORD_NAME=$CFRECORD_NAMEV4
  WANIPSITE=$WANIPSITEV4
  IP_TYPE="IPv4"
elif [ "$CFRECORD_TYPE" = "AAAA" ]; then
  WANIPSITE=$WANIPSITEV6
  ID_FILE=$ID_FILEV6
  WAN_IP_FILE=$WAN_IP_FILEV6
  LOG_FILE=$LOG_FILEV6
  CFRECORD_NAME=$CFRECORD_NAMEV6
  IP_TYPE="IPv6"
else
  echo "CFRECORD_TYPE参数错误，你填写的值是 $CFRECORD_TYPE ,它只能是 A(IPv4) 或者 AAAA(IPv6)"
  log "CFRECORD_TYPE参数错误，你填写的值是 $CFRECORD_TYPE ,它只能是 A(IPv4) 或者 AAAA(IPv6) \n"
  exit 2
fi

# 如果缺少必要的参数就退出
if [ "$CFKEY" = "" ]; then
  echo "缺少 Global API Key,前往 https://dash.cloudflare.com/profile/api-tokens 获取"
  log "[$IP_TYPE]缺少 Global API Key,前往 https://dash.cloudflare.com/profile/api-tokens 获取"
  echo "请把它保存在 ${0} 或使用 -k 参数"
  log "[$IP_TYPE]请把它保存在 ${0} 或使用 -k 参数 \n"
  exit 2
fi
if [ "$CFUSER" = "" ]; then
  echo "缺少用户名,这应该是你用于登录Cloudflare的电子邮件地址"
  log "[$IP_TYPE]缺少用户名,这应该是你用于登录Cloudflare的电子邮件地址"
  echo "请把它保存在 ${0} 或使用 -u 参数"
  log "[$IP_TYPE]请把它保存在 ${0} 或使用 -u 参数 \n"
  exit 2
fi
if [ "$CFRECORD_NAME" = "" ]; then 
  echo "缺少域名(CFRECORD_NAME), 你想要想要对哪个域名进行DDNS?"
  log "[$IP_TYPE]缺少域名(CFRECORD_NAME), 你想要想要对哪个域名进行DDNS?"
  echo "请把它保存在 ${0} 或使用 -h 参数"
  log "[$IP_TYPE]请把它保存在 ${0} 或使用 -h 参数 \n"
  exit 2
fi

# 如果CFRECORD_NAME不是全限定域名
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && ! [ -z "${CFRECORD_NAME##*$CFZONE_NAME}" ]; then
  CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
  echo "主机名不是全限定域名，已自动补全"
  log "[$IP_TYPE]主机名不是全限定域名，已自动补全"
fi

# 取得当前的&旧的公网IP
WAN_IP=`curl -s ${WANIPSITE}`

if [ -f $WAN_IP_FILE ]; then
  OLD_WAN_IP=`cat $WAN_IP_FILE`
else
  echo "无法找到旧的IP地址，似乎是第一次运行这个脚本？"
  log "[$IP_TYPE]无法找到旧的IP地址，似乎是第一次运行这个脚本？"
  OLD_WAN_IP=""
fi

# 如果公网IP没有变化就退出，避免过于频繁的调用API
if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" = false ]; then
  echo "公网IP($OLD_WAN_IP)没有变化,如果要强制更新请使用\"-f true\"参数"
  log "[$IP_TYPE]公网IP($OLD_WAN_IP)没有变化,如果要强制更新请使用\"-f true\"参数 \n"
  exit 0
fi

# 取得zoneid和recordid

if [ -f $ID_FILE ] && [ $(wc -l $ID_FILE | cut -d " " -f 1) == 4 ] \
  && [ "$(sed -n '3,1p' "$ID_FILE")" == "$CFZONE_NAME" ] \
  && [ "$(sed -n '4,1p' "$ID_FILE")" == "$CFRECORD_NAME" ]; then
    CFZONE_ID=$(sed -n '1,1p' "$ID_FILE")
    CFRECORD_ID=$(sed -n '2,1p' "$ID_FILE")
else
    echo "正在更新ZoneID和RecordID"
	log "[$IP_TYPE]正在更新ZoneID和RecordID"
    CFZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
	log "[$IP_TYPE]zoneid=$CFZONE_ID"
    CFRECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME&type=$CFRECORD_TYPE" -H "X-Auth-Email: $CFUSER" -H "X-Auth-Key: $CFKEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
	log "[$IP_TYPE]recordid=$CFRECORD_ID"
    echo "$CFZONE_ID" > $ID_FILE
    echo "$CFRECORD_ID" >> $ID_FILE
    echo "$CFZONE_NAME" >> $ID_FILE
    echo "$CFRECORD_NAME" >> $ID_FILE
fi

# 如果IP有变化就更新记录
echo "本地保存的IP是 $OLD_WAN_IP ,正在更新DNS记录到 $WAN_IP"
log "[$IP_TYPE]本地保存的IP是 $OLD_WAN_IP ,正在更新DNS记录到 $WAN_IP"

RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
  -H "X-Auth-Email: $CFUSER" \
  -H "X-Auth-Key: $CFKEY" \
  -H "Content-Type: application/json" \
  --data "{\"id\":\"$CFZONE_ID\",\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\", \"ttl\":$CFTTL}")

if [ "$RESPONSE" != "${RESPONSE%success*}" ] && [ "$(echo $RESPONSE | grep "\"success\":true")" != "" ]; then
  echo "成功！已将 $CFRECORD_NAME 的记录更新到 $WAN_IP"
  log "[$IP_TYPE]成功！已将 $CFRECORD_NAME 的记录更新到 $WAN_IP \n"
  #log "[$IP_TYPE][debug]Response:\n $RESPONSE"     #debug用
  echo $WAN_IP > $WAN_IP_FILE
  exit
else
  echo '似乎哪里出问题了 :(  API返回信息如下'
  echo "$RESPONSE"
  log '似乎哪里出问题了 :(  API返回信息如下'
  log "[$IP_TYPE][debug]Response:\n $RESPONSE \n"
  exit 1
fi
