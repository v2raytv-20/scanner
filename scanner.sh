sudo apt update && sudo apt install -y prips figlet lolcat jq -y

cat > scan.sh << 'EOF'
#!/bin/bash
R="\033[0;31m"; G="\033[0;32m"; B="\033[0;34m"; Y="\033[1;33m"; NC="\033[0m";
clear
figlet "V2RAYTV20" | lolcat

# نمایش تلگرام قبل از انتخاب گزینه
echo -e "${Y}📌 Telegram: @v2raytv20${NC}"
echo
echo -e "${Y}1) Scan Cloudflare${NC}"
echo -e "${Y}2) Scan Fastly${NC}"
read -p "> Please select 1 or 2: " o

[[ "$o" != "1" && "$o" != "2" ]] && echo -e "${R}Exiting${NC}" && exit

if [[ "$o" == "1" ]]; then
    echo -e "${B}Fetching Cloudflare IP Ranges...${NC}"
    curl -s https://www.cloudflare.com/ips-v4 -o cf_ipv4.txt
    SRC=cf_ipv4.txt
    NAME="Cloudflare"
else
    echo -e "${B}Fetching Fastly IP Ranges...${NC}"
    curl -s https://api.fastly.com/public-ip-list | jq -r '.addresses[]' > fastly.txt
    SRC=fastly.txt
    NAME="Fastly"
fi

ALL_IPS=()
for c in $(cat $SRC); do
    a=($(prips $c))
    s=$(( ${#a[@]}/32 ))
    [ $s -lt 1 ] && s=1
    for ((i=0;i<${#a[@]};i+=s)); do
        ALL_IPS+=("${a[$i]}")
    done
done

echo -e "${B}Testing $NAME IPs (Ping + 80/443)...${NC}"
TMP=$(mktemp)
for ip in "${ALL_IPS[@]}"; do
(
    p=$(ping -c1 -W1 $ip 2>/dev/null | grep "time=" | awk -F"time=" '{print $2}' | awk '{print $1}')
    timeout 1 bash -c "echo > /dev/tcp/$ip/80" 2>/dev/null; p80=$?
    timeout 1 bash -c "echo > /dev/tcp/$ip/443" 2>/dev/null; p443=$?
    [[ $p80 -eq 0 || $p443 -eq 0 ]] && echo "$p $ip $p80 $p443" >> $TMP
) &
done
wait

clear
figlet "$NAME RESULT" | lolcat
printf "%-20s | %-10s | %-6s | %-6s\n" "IP" "Ping" "80" "443"
echo "----------------------------------------"
sort -n $TMP | head -n 100 | while read p ip p80 p443; do
    p80s=$([[ $p80 -eq 0 ]] && echo -e "${G}open${NC}" || echo -e "${R}----${NC}")
    p443s=$([[ $p443 -eq 0 ]] && echo -e "${G}open${NC}" || echo -e "${R}----${NC}")
    printf "%-20s | %-10s | %-6s | %-6s\n" "$ip" "${p:-N/A}ms" "$p80s" "$p443s"
done
rm $TMP
echo -e "${G}✔ DONE — Best $NAME IPs!${NC}"
EOF

chmod +x scan.sh
bash scan.sh
