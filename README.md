### 更新
2020.5.23更新，修复了由于CloudflareAPI修改导致的脚本提示错误，但实际修改记录成功的bug。
### 要怎么用呢？
首先下载这个脚本，如果你在linux环境下，且有条件“面对国内网络环境”，可以使用这个命令
使用它的前提是你有安装curl，[如何安装curl](https://www.baidu.com/s?wd=%E5%AE%89%E8%A3%85curl "别问，问就是百度")
```shell
curl https://raw.githubusercontent.com/acha666/cloudflare-api-v4-ddns/master/cf-v4-ddns.sh > /usr/local/bin/cf-ddns.sh && chmod +x /usr/local/bin/cf-ddns.sh
```
或者通过我的博客下载（可能不会是最新版）
```shell
curl \source\contents\cloudflare-api-v4-ddns\cf-v4-ddns.sh > /usr/local/bin/cf-ddns.sh && chmod +x /usr/local/bin/cf-ddns.sh
```
在Windows环境下可以去我的[项目地址](https://github.com/acha666/cloudflare-api-v4-ddns "项目地址")直接下载
然后打开这个脚本，需要手动配置的地方已经使用注释标出
```shell
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
```
当然，你也可以选择不使用默认配置，在shell中用参数提供这些信息
```shell
# 用法:
# cf-ddns.sh -k <你的cloudflare api key> \
#            -u <Cloudflare登录邮箱> \
#            -h <host.example.com> \     # 你想要DDNS的完整域名
#            -z <example.com> \          # 主域名，即二级域名，或者说站点名称
#            -t <A|AAAA>                 # IPv4模式或者IPv6模式；默认IPv4
```
配置完成后，运行`bash cf-ddns.sh`即可
### 设置crontab计划任务
十分简单，首先输入`crontab -e`
然后在文件中添加新的一行
```shell
*/1 * * * * "/usr/local/bin/cf-ddns.sh" >/dev/null 2>&1
```
这样将会每分钟执行一次这个脚本。把`*/1`改成`*/10`就是每10分钟执行一次。
如果你改变了`cf-ddns.sh`的所在位置，相应的，你也要把`/usr/local/bin/cf-ddns.sh`改变成正确的目录。
当然，你也可以在`cf-ddns.sh`之后添加相应的参数。
不过，如果你和我一样使用群晖,只需要在控制面板-计划任务中添加新项目，然后设置好时间就行
![](https://i.loli.net/2020/05/10/I2FOKQfpD9xkjlJ.png)
### 注意事项
~~1.不能同时存在两个记录名相同的记录(比如一个example.com的A记录和example.com的MX记录)，会发生错误~~已经修复这个蛋疼的问题，现在有100个也没问题（话说哪里来的100种类型的记录啊= =）

2.脚本只在群晖DSM和Centos环境下测试，不过Ubuntu之类的也应该可以跑吧

3.如果要使用IPv6模式，当然首先你要保证你能够正常访问IPv6网站啦~[测试一下吧](https://www.test-ipv6.com/ "当然是测试能不能访问IPv6网站啦")

4.貌似没有了，因为我能发现的问题都修复完了
### 要是有BUG怎么办？
可以[前往我的Blog](https://acha666.cn/2020/05/10/%E4%BD%BF%E7%94%A8Cloudflare%E9%85%8D%E7%BD%AEIPV4%E5%92%8CIPV6%E7%9A%84%E5%8A%A8%E6%80%81DNS-DDNS "去我的博客看看吧")，给我留言就好，有人回复你时你会收到邮件提醒。或者你也可以选择[提交Issue](https://github.com/acha666/cloudflare-api-v4-ddns/issues "去Github提交Issue")，不过可能没那么快得到回复
