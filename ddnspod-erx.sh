#!/bin/sh

ACCESS_TOKEN="xxxxx,yyyyyyyyyyyyyyyyyyyyyyyy"
DOMAIN_ID="aaaaaa"
RECORD_ID="bbbbbb"

IS_PPP_UP=1

if [ -z $PPP_LOCAL ]; then
	IS_PPP_UP=0
fi

if [ "$PPP_IFACE" != "pppoe0" ]; then
    exit 0
fi

if [ $IS_PPP_UP -eq 0 ]; then 
    echo "Please copy script file to /config/scripts/ppp/ip-up.d/" 
    exit 0
else 
    date > /var/log/ppp.log 
    echo -e " PPP_LOCAL:${PPP_LOCAL} \n PPP_REMOTE:${PPP_REMOTE}" >> /var/log/ppp.log 
fi

showMsg() {
	echo $1
	if [ $IS_PPP_UP -eq 1 ]; then
		echo $1 >> /var/log/ppp.log
	fi
}

# arguments: apiInterface postParameters 
callApi() { 
    local agent="YYDdns/1.0(y6yuan@gmail.com)" 
    local url="https://dnsapi.cn/${1:?'Info.Version'}" 
    local params="login_token=${ACCESS_TOKEN}&format=json&${2}" 
    curl --silent --request POST --user-agent $agent $url --data $params 
}

# arguments: domainId recordId 
getLastIp() { 
    local response lastIp 
    
    # get last Ip 
    response=$(callApi "Record.Info" "domain_id=${1}&record_id=${2}") 
    lastIp=$(echo $response | sed 's/.*,"value":"\([0-9\.]*\)".*/\1/') 
    # validate Ip 
    case "$lastIp" in 
        [1-9][0-9]*) 
            echo $lastIp 
            return 0 
            ;; 
        *) 
            echo $response | sed 's/.*,"message":"\([^"]*\)".*/\1/' 
            return 1 
            ;; 
    esac 
}

# arguments: domainId recordId subdomainName lineId newIp 
updateDdns() { 
    local response returnCode recordIp lastIp 
    # get last Ip 
    lastIp=$(getLastIp $1 $2) 
    if [ $? -eq 1 ]; then 
        showMsg $lastIp 
        return 1 
    fi 
    # same Ip check 
    if [ "$lastIp" = "$5" ]; then 
        showMsg "Server side last Ip is the same as current local Ip!" 
        return 1 
    fi 
    # update Ip 
    response=$(callApi "Record.Ddns" "domain_id=${1}&record_id=${2}&sub_domain=${3}&record_line_id=${4}&value=${5}&record_type=A") 
    returnCode=$(echo $response | sed 's/.*{"code":"\([0-9]*\)".*/\1/') 
    recordIp=$(echo $response | sed 's/.*,"value":"\([0-9\.]*\)".*/\1/') 
    showMsg "${response}" 
    # Output Ip 
    if [ "$recordIp" = "$5" ]; then 
        if [ "$returnCode" = "1" ]; then 
            showMsg "New Ip post success: ${recordIp}" 
        else 
            # Echo error message 
            showMsg $(echo $response | sed 's/.*,"message":"\([^"]*\)".*/\1/') 
        fi 
    else 
        showMsg "Update Failed! Please check your network." 
    fi 
}

updateDdns $DOMAIN_ID $RECORD_ID "@" "0" $PPP_LOCAL
