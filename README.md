# ds-platform
环境要求：jdk1.8+

​		本maxwell在原有的基础上经过封装，已具备maxwell 宕机重启，以及宕机时发送邮件通知相关人员，部署过程如下：

> 需要邮件通知，邮件通知需要部署maxwell的服务器具备访问外网的能力，即能ping通：[smtp.163.com](http://smtp.163.com/)， 且请先安装邮件发送服务：



#### 1.安装linux sendmail邮件服务(不需要邮件通知可跳过此步)

- 安装sendmail:

  ```shell
  yum  -y  install  sendmail
  service sendmail start
  ```

  > 设置开机自启：chkconfig sendmail on

- 安装mailx ：

  ```sh
  yum install -y mailx
  ```

  

- 配置证书：

  ```shell
  #1.创建证书目录 /root/mail/.certs
  mkdir -p /root/mail/.certs
  #2. 分别执行以下命令：
  echo -n | openssl s_client -connect smtp.163.com:465 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /root/mail/.certs/163.crt
  
  certutil -A -n "GeoTrust Global CA" -t "C,," -d /root/mail/.certs -i /root/mail/.certs/163.crt
  
  certutil -A -n "GeoTrust SSL CA" -t "C,," -d /root/mail/.certs -i /root/mail/.certs/163.crt
  
  certutil -L -d /root/mail/.certs
  
  certutil -A -n "GeoTrust SSL CA - G3" -t "Pu,Pu,Pu" -d /root/mail/.certs/ -i /root/mail/.certs/163.crt
  ```

  

- 在 `/etc/mail.rc`文件最后添加如下配置

  ```shell
  set from=user@163.com
  set smtp=smtps://smtp.163.com:465
  # 忽略证书警告
  set ssl-verify=ignore
  # 证书所在目录
  set nss-config-dir=/root/mail/.certs
  set smtp-auth-user=user@163.com
  set smtp-auth-password=xxxx
  set smtp-auth=login
  ```

- 测试邮件是否可以正常发送

  ```shell
  echo  '内容'  |  mail  -s  '主题'  user@163.com
  ```



#### 2.服务部署

- 部分修改配置`ds-platform.sh`文件，如下

  ```shell
  #是否发送通知邮件
  sendEmail=true
  #接收邮箱
  readonly email_no=user@163.com
  #邮件标题
  email_title='澧县单采血浆站maxwell服务通知'
  
  #定时监听进程,停顿时间（秒）,即每多少时间进行一次服务进程监听,默认5分钟
  readonly delay_millisecond=300
  
  #宕机时，最大重启次数
  total_count=2016
  
  #应用名ID,注意：此sh脚本全路径名不能包含此应用名,覆盖config.properties里的client_id
  export readonly APP_NAME="maxwell"
  
  #maxwell运行日志删除，默认删除
  delete_log=true
  
  #邮件附件最大值,默认10M
  email_accessory_maxsize=$((1024 * 1024 * 10))
  
  #截取问题日志前多少行
  analysisLog_pre=20
  #截取问题日志后多少行
  analysisLog_later=100
  ```

  

- 部分修改配置`config.properties`，如下:

  ```shell
  #日志级别 [debug | info | warn | error]
  log_level=error
  
  #mysql options 数据库配置，会建立maxwell表结构
  host=localhost
  user=root
  password=xxx
  port=3306
  jdbc_options=useUnicode=true&characterEncoding=utf-8&useSSL=false&allowMultiQueries=true&zeroDateTimeBehavior=convertToNull
  schema_database=maxwell
  
  #监听数据变更的数据库
  replication_host=localhost
  replication_user=root
  replication_password=xxx
  replication_port=3306
  replication_jdbc_options=useUnicode=true&characterEncoding=utf-8&useSSL=false&allowMultiQueries=true&zeroDateTimeBehavior=convertToNull
  replication_schema_database=change_db
  
  #kafka服务地址，多个用逗号分隔
  kafka.bootstrap.servers=localhost:9092
  #kafka主题，前缀“Q.DATA_SYNC.”固定，后面可以为浆站所在组织拼音，但必须与平台配置一致。
  kafka_topic=Q.DATA_SYNC.lixian
  
  #filtering
  #过滤器
  filter=exclude: *.*, include: change_db.*
  
  #过滤脚本地址
  javascript=/xxx/filter.js
  ```

- 在`ds-platform` 目录下，启动如下：

  ```shell
  nohup ./ds-platform.sh start &
  ```

> maxwell 日志路径： `/xxxx/ds-platform/logs/maxwell.out`
