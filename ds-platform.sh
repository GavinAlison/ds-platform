#!/bin/sh  

:<<!
应用规约：
1、sh脚本文件全路径名不能包含此应用名ID
2、sh脚本文件名必须与上一级目录名一致
!
#-----------------------------------------------------
#是否发送通知邮件
sendEmail=false
#接收邮箱
readonly email_no=user@163.com
#邮件标题
email_title='XXX maxwell服务通知'

#定时监听进程,停顿时间（秒）,即每多少时间进行一次服务进程监听
readonly delay_millisecond=300

#宕机时，最大重启次数
total_count=20200

#应用名ID,注意：此sh脚本全路径名不能包含此应用名,覆盖config.properties里的client_id
export readonly APP_NAME="maxwell"

#maxwell运行日志删除，默认删除
delete_log=false

#邮件附件最大值,默认10M
email_accessory_maxsize=$((1024 * 1024 * 10))

#截取问题日志前多少行
analysisLog_pre=50
#截取问题日志后多少行
analysisLog_later=100

#-----------------------------------------------------
#run.sh所在目录
readonly CURDIR="$(cd `dirname $0`; pwd)"
#日志文件
export readonly CONSOLE_OUTPUT_FILE=$CURDIR/logs/$APP_NAME.out
#应用相对路径
readonly APP_DIR="maxwell-1.24.1/bin/maxwell"

#日志分析关键字符串
readonly analysisLog_str='Exception:,ERROR:'

#邮件进程名
readonly email_app=sendmail

#邮件发送重试次数
readonly email_try_count=3

#日志错误解析
analysisLog(){
    local error='未找到maxwell错误日志...'

    #存在日志
    if test -e $CONSOLE_OUTPUT_FILE; then

        #获取异常所在行
        local array=(${analysisLog_str//,/ })
        local cur_line=''
        for var in ${array[@]}
        do
           cur_line=`grep -n "${var}" $CONSOLE_OUTPUT_FILE | tail -n 1`
           if [ "$cur_line" != "" ]; then
                #行数
                cur_line=${cur_line%%:*}
                local line_pre=$((analysisLog_pre > cur_line ? 1 : `expr $cur_line - $analysisLog_pre`))
                local line_later=`expr $cur_line + $analysisLog_later`
                #获取指定长度的日志信息
                error=`sed -n "${line_pre},${line_later}p" $CONSOLE_OUTPUT_FILE`
                break
            fi
        done
    fi
    echo "${error}"
}

#邮件发送
send(){
    #不允许发送邮件
    if [ $sendEmail != true ]; then
        return 1
    fi

    #存在sendMail 进程才进行邮件发送
    local mail_process=`ps aux | grep ${email_app} | grep -v grep`;

    logger "sendMail process: $mail_process "
    if [ "$mail_process" != "" ]; then
        local title=$1
        #错误日志
        local content=$2
        #附件
        local accessory=$3
        local count=1
        #发送邮件

        #判断附件是否存在
        if test -e $accessory ;then
            #获取日志文件大小
            local filesize=`ls -l $accessory | awk '{ print $5 }'`
            logger "当前待发送邮件附件大小为:$filesize "
            if [ $filesize -gt $email_accessory_maxsize ]; then
                accessory=''
            fi
        fi

        #发送失败则存在重试机制
        local num=0
        while (($num < $email_try_count))
        do
            #不带附件
            if [ "$accessory" = "" ]; then
                echo -e "${content}"|mail -s ${title} $email_no
            #带附件
            else
                echo -e "${content}"|mail -s ${title} -a $accessory $email_no
            fi

            if [ $? = 0 ]; then
                return $?
            fi

            ((num++))
            sleep 5
        done

        logger "邮件发送重试${email_try_count}次失败..."
        return 1
    else
        logger "${email_app}邮箱客户端未启动,请确认..."
        return 1
    fi
}

#kill app process
kill_app() {
    #进程名
    local processName=$1
    local notExistentPid=$2
    while true
    do
        local process=`ps -ef | grep ${processName} | grep -v grep |grep -v "\<${notExistentPid}\>" | awk '{print $2}'`
        if [ "$process" = "" ]; then
            logger "no $processName process";
            break;
        else
            logger "kill $processName process...";
            kill -9 $process
            sleep 5
        fi
    done
}

stop(){
    #杀死本sh 其他进程

    local filename=$0
    kill_app ${filename##*/} $$

    #先杀死进程
    kill_app $APP_NAME
}

#启动
run_app(){
    logger "start maxwell process...";
    #删除旧日志
    if [ $delete_log = true -a -e $CONSOLE_OUTPUT_FILE ]; then
        logger "删除旧日志$CONSOLE_OUTPUT_FILE"
        rm -rf "$CURDIR/logs/$APP_NAME.out"
    fi
    #启动应用
    ${CURDIR}/${APP_DIR} \
        --config=${CURDIR}/config.properties \
        --client_id=$APP_NAME \
        --daemon
}

start(){
    stop

	run_app

	sleep 10

    local firstStart=true

    #本次宕机邮件已发送，避免多次发送同一类型邮件
    local isSend=false
	#启动次数
	local start_count=1

    while (($start_count <= $total_count))
    do
        local process=`ps aux | grep ${APP_NAME} | grep -v grep`;
        logger "maxwell process:$process"
        #未启动
        if [ "$process" = "" ]; then
            logger "no maxwell process";

            #发送邮件
            if [ $isSend = false ]; then
                local error=$(analysisLog)
                #发送邮件
                send "警告：${email_title}" "maxwell服务已宕机，正在尝试重启，错误日志为：\n $error" $CONSOLE_OUTPUT_FILE
                if [ $? = 0 ]; then
                    isSend=true
                    logger 'maxwell宕机邮件已投递成功...'
                else
                    logger 'maxwell宕机邮件投递失败...'
                fi
            fi
            #启动
            run_app

            logger "maxwell故障重启次数：${start_count}"

            #启动次数累加
            ((start_count++))
        #已启动
        else
            #重启成功邮件通知已启动成功
            if [ $isSend = true ]; then
                if [ $firstStart = true ]; then
                    firstStart=false
                fi
                isSend=false
                send "通知：${email_title}" "maxwell 已重新启动成功..." $CONSOLE_OUTPUT_FILE
            fi
            start_count=1

            #第一次启动，发送通知邮件
            if [ $firstStart = true ]; then
                firstStart=false
                send "通知：${email_title}" "maxwell 已启动成功..." $CONSOLE_OUTPUT_FILE
            fi
        fi

        sleep $delay_millisecond
    done
}

restart() {
    start;
}

logger(){
    local content=$1
    local date=`date '+%Y-%m-%d %H:%M:%S'`
    printf "%s\n" "$date $content"
}

#校验
#1、脚本名必须与上一级目录一致
#2、sh脚本绝对路径不能包含AppName名称
verify(){
    logger "执行校验中..."

    local parent_dir=${CURDIR##*/}
    logger "脚本父目录：$parent_dir"

    local filePath=$0
    local filename=${filePath##*/}

    filePath="$CURDIR/$filename"
    logger "脚本文件文件名：$filename"
    logger "全路径名：$filePath"

    logger "应用名ID：$APP_NAME"

    local result=$(echo $filePath | grep "${APP_NAME}")
    if [ "$result" != "" ]; then
        logger "脚本文件全路径名不能包含应用名，请进行修改..."
        exit 1
    fi

    if [ "$parent_dir.sh" != "$filename" ]; then
        logger "脚本父目录必须跟sh脚本名一致，请进行修改..."
        exit 1
    fi
}


#校验不通过，则退出本次执行
verify

case "$1" in
    'start')
        start
        ;;
    'stop')
        stop
        ;;
    'restart')
        restart
        ;;
    *)
    logger "usage: $0 {start|stop|restart}"
    exit 1
        ;;
    esac