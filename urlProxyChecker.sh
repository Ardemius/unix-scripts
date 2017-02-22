#!/bin/bash

#************************************************************************************************
# Name          : urlProxyChecker.sh
# Version       : 1.0
# Date          : 2016/05/11
# Author        : Thomas SCHWENDER
#************************************************************************************************

usage()
{
    echo "Usage: urlProxyChecker URL"
    echo "Check if the URL given as a parameter is accessible for each of the given proxies"
    echo "This script requires either \"curl\" or \"wget\""
    echo
};

LOGIN="PROXY_LOGIN"
# CAREFULL! No special character allowed in password! Use the percent encoding substitute (# => %23)
PASSWORD="PROXY_PASSWORD"
PROXIES=(
	"myproxy:8080"
	"myOtherProxy:8080"
	"aThirdProxy:8080"
)

function validateUrl()
{
	#curl --output /dev/null --silent --head --fail -x $LOGIN:$PASSWORD@$proxy $url
	wget -S --spider --tries=1 --timeout=5 -e http_proxy=http://$LOGIN:$PASSWORD@$proxy/ -e https_proxy=http://$LOGIN:$PASSWORD@$proxy/ $url 2>&1 | grep -q 'HTTP/1.1 200 OK'
}

function checkURL()
{
	read -p "URL to check: " url
	echo

	for proxy in "${PROXIES[@]}"; do

		if validateUrl; then
			printf '%s\t%s\n' "PROXY $proxy" ": $url is accessible"
		else
			printf '%s\t%s\n' "PROXY $proxy" ": $url is NOT accessible"
		fi

	done
}

##########
## MAIN ##
##########

ACTION="$1"

case "$ACTION" in
-h | --help)
    usage && exit 1
;;
*)
    checkURL
;;
esac

echo "finished!"
exit 0
