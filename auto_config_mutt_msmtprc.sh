#!/bin/bash

function log_info() {
	echo "[INFO]$@"
}

function log_warn() {
	echo "[WARN]$@"
}

function log_error() {
	echo "[ERROR]$@"
}

#使用方法说明
function usage() {
	cat<<USAGEEOF	
	NAME  
		$g_shell_name - 自动配置邮件发送环境 
	SYNOPSIS  
		source $g_shell_name [命令列表] [文件名]...   
	DESCRIPTION  
		$g_git_wrap_shell_name --自动配置git环境  
			-h 
				get help log_info
			-m
				set sender's mail address
			-p
				set sender's mail login password
			-f 
				force mode to override exist file of the same name
			-v
				verbose display
			-o 
				the path of the out files
	AUTHOR 作者
    		由 searKing Chan 完成。
			
       	DATE   日期
		2015-11-16

	REPORTING BUGS 报告缺陷
    		向 searKingChan@gmail.com 报告缺陷。	
	REFERENCE	参见
			https://github.com/searKing/GithubHub.git
USAGEEOF
}

#循环嵌套调用程序,每次输入一个参数
#本shell中定义的其他函数都认为不支持空格字符串的序列化处理（pull其实也支持）
#@param func_in 	函数名 "func" 只支持单个函数
#@param param_in	以空格分隔的字符串"a b c",可以为空
function call_func_serializable()
{
	func_in=$1
	param_in=$2
	case $# in
		0)
			log_error "${LINENO}:$FUNCNAME expercts 1 param in at least, but receive only $#. EXIT"
			return 1
			;;
		1)
			case $func_in in
				"auto_config_mutt" | "auto_test_msmtp")
					$func_in
					;;
				*) 
					log_error "${LINENO}:Invalid serializable cmd with no param: $func_in"
					return 1
					;;
			esac	
			;;				
		*)	#有参数函数调用
			error_num=0
			for curr_param in $param_in
			do	
				case $func_in in
					"auto_config_msmtp")
						msmtp_generate_account_template_name=$curr_param
						$func_in "$msmtp_generate_account_template_name"
						if [ $? -ne 0 ]; then
							error_num+=0
						fi
					 	;;
					*) 
						log_error "${LINENO}:Invalid serializable cmd with params: $func_in"
						return 1
					 	;;
				esac		
			done	
			return $error_num
			;;		
	esac
}

#解析输入参数
function parse_params_in() {
	if [ "$#" -lt 0 ]; then   
		cat << HELPEOF
use option -h to get more log_information .  
HELPEOF
		return 1  
	fi   	
	set_default_cfg_param #设置默认配置参数	
	set_default_var_param #设置默认变量参数
	unset OPTIND
	while getopts "m:p:vfo:h" opt  
	do  
		case $opt in
		m)
			#配置开发者邮箱
			g_user_email=$OPTARG
			;;  
		p)
			#配置开发者邮箱登陆密码
			g_user_email_login_passwd=$OPTARG
			;;  
		f)
			#覆盖前永不提示
			g_cfg_force_mode=1
			;;  
		o)
			#输出文件路径
			g_cfg_output_root_dir=$OPTARG
			;;  
		v)
			#是否显示详细信息
			g_cfg_visual=1
			;;
		h)  
			usage
			return 1  
			;;  	
		?)
			log_error "${LINENO}:$opt is Invalid"
			return 1
			;;
		*)    
			;;  
		esac  
	done  
	#去除options参数
	shift $(($OPTIND - 1))
	
	if [ "$#" -lt 0 ]; then   
		cat << HELPEOF
use option -h to get more log_information .  
HELPEOF
		return 0  
	fi  	
	
	#默认账户
	g_default_account=${g_user_email##*@}
	g_default_account=${g_default_account%.com}
	
	g_mutt_output_file_abs_name="$g_cfg_output_root_dir/$g_config_mutt_file_name"
	g_msmtp_output_file_abs_name="$g_cfg_output_root_dir/$g_config_msmtp_file_name"
	case $g_default_account in
		"gmail")
			g_msmtp_generate_account_template="msmtp_gmail_account_template"
			;;
		"163")
			g_msmtp_generate_account_template="msmtp_163_account_template"		
			;;
		"qq")
			g_msmtp_generate_account_template="msmtp_qq_account_template"		
			;;
		*)	#有参数函数调用			
			log_error "${LINENO}:Invalid mail account: $g_default_account"
			return 1;
			;;		
	esac
	#检查远程smtp服务器是否正常
	check_smtp_server "$g_default_account"
	if [ $? -ne 0 ]; then
		return 1;
	fi
	
}
#设置默认配置参数
function set_default_cfg_param(){
	#覆盖前永不提示-f
	g_cfg_force_mode=0
	
	#开发者名字
	g_user_name="searKing"	
	#开发者邮箱
	g_user_email="searKingChan@163.com"	
	#开发者邮箱登陆密码
	g_user_email_login_passwd="kwisghrojnmklpcn"	
	cd ~		
	#输出文件路径
	g_cfg_output_root_dir="$(cd ~; pwd)/"
	cd -
	
	#是否显示详细信息
	g_cfg_visual=0
}
#设置默认变量参数
function set_default_var_param(){	
	#获取当前脚本短路径名称
	g_shell_name="$(basename $0)" 
	#切换并获取当前脚本所在路径
	g_shell_repositories_abs_dir="$(cd `dirname $0`; pwd)"
	#配置文件名称
	g_config_mutt_file_name=".muttrc"	
	g_config_msmtp_file_name=".msmtprc"	
	#发送内容文本路径
	g_mailcontent_ads_dir=$g_shell_repositories_abs_dir
	#发送内容文本文件名
	g_mailcontent_name="mailcontent"
	#获取当前动作
	g_send_eamil_action="auto_send_emails"
	g_send_eamil_names="" #当前动作参数--.gitignore文件名称
}
#自动配置mutt
function auto_config_mutt()
{	
	if [ -f $g_mutt_output_file_abs_name ]; then
	   	if [ $g_cfg_force_mode -eq 0 ]; then 	
			log_error "${LINENO}:"$g_mutt_output_file_abs_name" files is already exist. use -f to override? Exit."
			return 1
		else
    		rm "$g_mutt_output_file_abs_name" -Rf
    	fi
    fi
	#检测是否安装成功msmtp
	if [ $g_cfg_visual -ne 0 ]; then
		which mutt	
	else
		which mutt	1>/dev/null
	fi
	
	if [ $? -ne 0 ]; then
		sudo apt-get install mutt
		ret=$?
		if [ $ret -ne 0 ]; then
			log_error "${LINENO}: install mutt failed($ret). Exit."
			return 1;
		fi
	fi
    cat > $g_mutt_output_file_abs_name <<CONFIGEOF	
    #配置发送email的工具为msmtp
	set sendmail="/usr/bin/msmtp"
	set use_from=yes
	set realname="searKing" 
	set from=$g_user_email
	set editor="gedit"
	set envelope_from=yes
	set rfc2047_parameters=yes
	set charset="utf-8"
CONFIGEOF
}
#gmail配置部分模板
function msmtp_gmail_account_template()
{
    cat >> $g_msmtp_output_file_abs_name <<CONFIGEOF	
	# A gmail address
	account        gmail
	host           smtp.gmail.com
	port           587
	from           $g_user_email
	user           $g_user_email
	password       $g_user_email_login_passwd
	tls_trust_file /etc/ssl/certs/ca-certificates.crt
CONFIGEOF
}
#163配置部分模板
function msmtp_163_account_template()
{
    cat >> $g_msmtp_output_file_abs_name <<CONFIGEOF	
	# A 163 email address
	account    163
	host       smtp.163.com
	port       25
	from       $g_user_email
	auth       login
	#网易免费邮箱的ssl证书通不过验证，所以使用126/163邮箱时，只能关闭tls证书验证
	tls        off
	user       $g_user_email
	#网易邮箱需要开启客户端授权码代替登陆密码(coco189621)
	password   $g_user_email_login_passwd
CONFIGEOF
}
#qq配置部分模板
function msmtp_qq_account_template()
{
    cat >> $g_msmtp_output_file_abs_name <<CONFIGEOF	
	# A qq email address
	# http://service.mail.qq.com/cgi-bin/help?subtype=1&&id=28&&no=371
	account    	qq
	host 		smtp.qq.com
	port 		465
	from       	$g_user_email
	auth 		login
	#QQ邮箱不支持tls，使用QQ邮箱需要关闭tls_starttls
	tls_starttls 	off
	tls 			on
	tls_certcheck 	off
	user       	$g_user_email
	password   	$g_user_email_login_passwd
CONFIGEOF
}
#msmtp配置通用头部模板
function msmtp_generate_head_template()
{
    cat > $g_msmtp_output_file_abs_name <<CONFIGEOF	
	#Accounts will inherit settings from this section
	defaults
	tls on
	logfile ~/.msmtp.log
CONFIGEOF
}
#msmtp配置通用头部模板
function msmtp_generate_tag_template()
{
	cat >> $g_msmtp_output_file_abs_name <<CONFIGEOF	
	# Set a default account
	account default : $g_default_account
CONFIGEOF
}
#自动配置msmtp
function auto_config_msmtp()
{	
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$FUNCNAME expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	msmtp_generate_account_template=$1
	
	
	#检测是否安装成功msmtp
	if [ $g_cfg_visual -ne 0 ]; then
		which msmtp	
	else
		which msmtp	1>/dev/null
	fi
	if [ $? -ne 0 ]; then
		sudo apt-get install msmtp
		ret=$?
		if [ $ret -ne 0 ]; then
			log_error "${LINENO}: install msmtp failed($ret). Exit."
			return 1;
		fi
	fi
	
	if [ -f $g_msmtp_output_file_abs_name ]; then
    	if [ $g_cfg_force_mode -eq 0 ]; then    	
			log_error "${LINENO}:"$g_msmtp_output_file_abs_name" files is already exist. use -f to override? Exit."
			return 1
		else
    		rm "$g_msmtp_output_file_abs_name" -Rf
    	fi
    fi
    #生成msmtp配置文件
    msmtp_generate_head_template
	if [ $? -ne 0 ]; then
		return 1;
	fi
    
    $msmtp_generate_account_template
	if [ $? -ne 0 ]; then
		return 1;
	fi
	
    msmtp_generate_tag_template
	if [ $? -ne 0 ]; then
		return 1;
	fi
	#配置文件需要600权限
	#msmtp: .msmtprc: must have no more than user read/write permissions
	sudo chmod 600 $g_msmtp_output_file_abs_name
}
#检查远程smtp服务器是否正常
function check_smtp_server()
{
	expected_params_in_num=1
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$FUNCNAME expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	default_account=$1
	#测试smtp服务器
	if [ $g_cfg_visual -ne 0 ]; then
		msmtp --host=smtp.$default_account.com --serverinfo
	else
		msmtp --host=smtp.$default_account.com --serverinfo	 1>/dev/null
	fi
    ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}: get msmtp[smtp.$default_account.com]'s serverinfo failed($ret). Exit."
		return 1
	fi 
}
#自动测试msmtp配置是否成功
function auto_test_msmtp()
{	
	expected_params_in_num=0
	if [ $# -ne $expected_params_in_num ]; then
		log_error "${LINENO}:$FUNCNAME expercts $expected_params_in_num param_in, but receive only $#. EXIT"
		return 1;
	fi
	#测试配置文件
	if [ $g_cfg_visual -ne 0 ]; then
		msmtp -P
	else
		msmtp -P	 1>/dev/null
	fi	
    ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}: test msmtp's configuration failed($ret). Exit."
		return 1
	fi 
	
	#测试smtp服务器	
	if [ $g_cfg_visual -ne 0 ]; then
		msmtp -S
	else
		msmtp -S	 1>/dev/null
	fi	
    ret=$?
	if [ $ret -ne 0 ]; then
		log_error "${LINENO}: get msmtp's serverinfo failed($ret). Exit."
		return 1
	fi 
}



function do_work(){  	
	call_func_serializable auto_config_mutt
    ret=$?
	if [ $ret -ne 0 ]; then
		return 1
	fi 
	call_func_serializable auto_config_msmtp $g_msmtp_generate_account_template	
    ret=$?
	if [ $ret -ne 0 ]; then
		return 1
	fi 
	call_func_serializable auto_test_msmtp
	ret=$?
	if [ $ret -ne 0 ]; then
		return 1
	fi 
}
################################################################################
#脚本开始
################################################################################
function shell_wrap()
{
	#含空格的字符串若想作为一个整体传递，则需加*
	#"$*" is equivalent to "$1c$2c...", where c is the first character of the value of the IFS variable.
	#"$@" is equivalent to "$1" "$2" ... 
	#$*、$@不加"",则无区别，
	parse_params_in "$@"
	if [ $? -ne 0 ]; then 
		return 1
	fi
	do_work
	if [ $? -ne 0 ]; then
		return 1
	fi
	log_info "$0 $@ is running successfully"
	read -n1 -p "Press any key to continue..."
	return 0
}
shell_wrap "$@"

