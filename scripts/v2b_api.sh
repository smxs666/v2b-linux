#!/bin/sh

#全局变量
API_URL=https://fastly.jsdelivr.net/gh/smxs666/v2b-linux@main/api.json
. $CRASHDIR/configs/ShellCrash.cfg

#工具
webget() {
	[ -n "$(pidof CrashCore)" ] && {
		[ -n "$authentication" ] && auth="$authentication@"
		export https_proxy="http://${auth}127.0.0.1:$mix_port"
	}
	if curl1 --version >/dev/null 2>&1; then
		curl -ksSl --connect-timeout 3 -H "$2" "$1"
	elif wget --version >/dev/null 2>&1; then
		wget -Y on -q --timeout=3 --header="$2" -O - "$1"
	fi
}
webpost() {
	[ -n "$(pidof CrashCore)" ] && {
		[ -n "$authentication" ] && auth="$authentication@"
		export https_proxy="http://${auth}127.0.0.1:$mix_port"
	}
	if curl --version >/dev/null 2>&1; then
		curl -kfsSl -X POST --connect-timeout 3 -H "Content-Type: application/x-www-form-urlencoded" "$1" -d "$2"
	elif wget --version >/dev/null 2>&1; then
		wget -Y on -q --timeout=3 --method=POST --header="Content-Type: application/x-www-form-urlencoded" --body-data="$2" -O - "$1"
	fi
}

login() {
	# 登录并获取token和auth_data
	login_response=$(webpost "$API_BASE_URL/api/v1/passport/auth/login" "email=$api_email&password=$api_password")
	token="$(echo "$login_response" | grep -o "\"token\":\"[^\"]*" | cut -d'"' -f4)"
	auth_data="$(echo "$login_response" | grep -o "\"auth_data\":\"[^\"]*" | cut -d'"' -f4)"
	sub_link="$SUB_BASE_URL/api/v1/client/subscribe?token=$token"

	#获取订阅信息
	subscribe=$(webget "$API_BASE_URL/api/v1/user/getSubscribe" "Authorization: $auth_data")
	expired_at="$(echo "$subscribe" | grep -o "\"expired_at\":.*" | cut -d',' -f1 | cut -d':' -f2)"
	transfer_enable="$(echo "$subscribe" | grep -o "\"transfer_enable\":.*" | cut -d',' -f1 | cut -d':' -f2)"
	reset_day="$(echo "$subscribe" | grep -o "\"reset_day\":.*" | cut -d'}' -f1 | cut -d':' -f2)"

	# 检查登录是否成功
	if [ -z "$token" ] || [ -z "$auth_data" ]; then
		echo -e "\033[31m登录失败,请检查您的电子邮件和密码\033[0m"
		sleep 1
		return 1
	else
		setconfig api_email "$api_email"
		setconfig api_password "$api_password"
		return 0
	fi
}
user_del() {
	setconfig api_email
	setconfig api_password
}
logout() {
	webpost "$API_BASE_URL/api/v1/user/logout" "Authorization: $auth_data"
	echo -e "\033[33m已退出当前用户！\033[0m"
	sleep 1
}
get_core_config() {
	# 获取订阅
	webget "$sub_link" "User-Agent: clash" >/tmp/ShellCrash/config.yaml
	echo -----------------------------------------------
	if [ -s /tmp/ShellCrash/config.yaml ]; then
		mv -f /tmp/ShellCrash/config.yaml $CRASHDIR/yamls/config.yaml
		read -p "已成功获取配置文件，是否重启服务？(1/0) > " res
		[ "$res" = 1 ] && start_service && exit
	else
		echo -e "\033[31m获取订阅链接失败,请检查API响应！\033[0m"
		sleep 1
		rm -rf /tmp/ShellCrash/config.yaml
	fi
}
user_input() {
	read -p "$1" text
	if [ -z "$text" ]; then
		user_input "$1"
	else
		echo "$text"
	fi
}
user_add() {
	api_email=$(user_input "请输入注册邮箱：")
	[ "$api_email" = 0 ] && return 1
	api_password=$(user_input "请输入密码：")
}
user_menu() {
	[ "$reset_day" != null ] && sub_date=$(date -d "@$expired_at" "+%Y-%m-%d") || sub_date='长期有效'
	echo -----------------------------------------------
	echo -e "您好，\033[36m$api_email\033[0m！欢迎使用 \033[30;47m${BASE_NAME}\033[0m"
	echo -e "剩余流量：\033[32m$((transfer_enable / 1073741824)) GB\033[0m 订阅过期时间：\033[33m$sub_date\033[0m"
	[ "$reset_day" != null ] && echo -e "流量重置日期：\033[32m$reset_day\033[0m"
	echo -----------------------------------------------
	echo -e " 1 更新\033[32mClash配置文件\033[0m"
	echo -e " 2 添加为\033[32mproviders提供者\033[0m"
	echo -e " 3 查看\033[33m订阅链接\033[0m"
	echo -e " 4 重置\033[33m订阅链接\033[0m"
	echo -e " 5 修改\033[36m登录信息\033[0m"
	echo -e " 6 清空\033[31m登录信息\033[0m"
	echo -----------------------------------------------
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
			echo -e "\033[31m暂不支持直接生成singbox配置文件！\033[0m"
			echo -e "\033[33m请使用Clash内核或添加为providers提供者\033[0m"
			sleep 1
		else
			get_core_config
		fi
		user_menu
		;;
	2)
		echo "$BASE_NAME $sub_link" >>$CRASHDIR/configs/providers.cfg
		echo -e "\033[32mproviders已添加！正在跳转到providers功能！\033[0m"
		sleep 1
		if [ "$crashcore" = meta -o "$crashcore" = clashpre ]; then
			coretype=clash
			setproviders
		elif [ "$crashcore" = singboxp ]; then
			coretype=singbox
			setproviders
		else
			echo -e "\033[33msingbox官方内核及Clash基础内核不支持此功能，请先更换内核！\033[0m"
			sleep 1
			checkupdate && setcore
			user_menu
		fi
		;;
	3)
		echo -----------------------------------------------
		echo -e "您的链接为：\033[36;4m$sub_link\033[0m"
		echo -e "注意：\033[31m请不要将此链接泄露给任何用户！\033[0m"
		sleep 1
		user_menu
		;;
	4)
		echo -----------------------------------------------
		webget "$API_BASE_URL/api/v1/user/resetSecurity" "Authorization: $auth_data" >/dev/null
		echo -e "\033[33m链接已重置，请重新生成配置文件！\033[0m"
		login
		if [ "$?" = 0 ]; then
			user_menu
		else
			guest_menu
		fi
		;;
	5)
		user_add && {
			login
			if [ "$?" = 0 ]; then
				user_menu
			else
				guest_menu
			fi
		}
		;;
	6)
		user_del
		;;
	*)
		errornum
		;;
	esac
}

guest_menu() {
	echo -----------------------------------------------
	echo -e "欢迎使用\033[30;47m${BASE_NAME}\033[0m！"
	echo -----------------------------------------------
	echo -e "还未注册？请前往：\033[36;4m${API_BASE_URL}/#/register\033[0m"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	user_add && {
		login
		if [ "$?" = 0 ]; then
			user_menu
		else
			guest_menu
		fi
	}
}

echo -e "\033[36m正在连接服务器……\033[0m"
API_JSON=$(webget "$API_URL" "Content-Type: application/json")
API_BASE_URL=$(echo "$API_JSON" | awk -F'"' '/api/ {print $4}')
SUB_BASE_URL=$(echo "$API_JSON" | awk -F'"' '/sub/ {print $4}')
BASE_NAME=$(echo "$API_JSON" | awk -F'"' '/name/ {print $4}')
[ -z "$BASE_NAME" ] && BASE_NAME='蓝海加速'

if [ -n "$api_email" ] && [ -n "$api_password" ]; then
	login
	if [ "$?" = 0 ]; then
		user_menu
	else
		guest_menu
	fi
else
	guest_menu
fi
