#!/bin/bash -e

  #创建文件夹 变量
  environment_name="trojan_install";
  tmp_trojan="/tmp/${environment_name}";

#版本全局变量
openssl_version=1.1.1;
cmake_version=3.12.3;

  #所需的依赖 变量
  openssl_name='openssl-'$openssl_version'f';
  cmake_name='cmake-'$cmake_version;
  boost_name='boost_1_68_0';
  trojan_name="trojan";
  openssl_tar="${openssl_name}.tar.gz";
  cmake_tar="${cmake_name}.tar.gz";
  boost_tar="${boost_name}.tar.gz";
  trojan_git="${trojan_name}.git";

  CONFIG_PATH='/usr/local/etc/trojan/config.json'

  jq_file='/usr/bin/jq'

  ubuntu_debian_update(){
    sudo apt update -y
    sudo apt-get -y install software-properties-common
    sudo add-apt-repository ppa:certbot/certbot  #添加certbot仓库
    sudo apt update -y
    sudo apt upgrade -y  #更新系统
    sudo apt-get -y install jq #添加jq工具
    sudo apt-get -y install certbot
    sudo apt-get -y install curl
  }
  ubuntu_tojan_install(){
    sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/trojan-gfw/trojan-quickstart/master/trojan-quickstart.sh)"
    trojan_bin_location='/usr/local/bin/';trojan_service_location='/etc/systemd/system/';
    if [[ $(find $trojan_bin_location -name 'trojan'|grep -c -i "trojan") -eq 0 ]] || [[ $(find $trojan_bin_location -name 'trojan'|grep -c -i "trojan") -eq 0 ]];then
        echo "=============================trojan 安装失败================================="
        exit 5;
      else
        sed -i '/^User/d;/^AmbientCapabilities/d' $trojan_service_location/trojan.service;

        echo "=============================trojan 安装成功================================="
      fi
  }


# 判断是否存在openssl 1.1.1


  centos_update(){
    yum -y update # 更新系统

    yum -y install jq #安装jq 解析json数据

    if [[ $(openssl version |grep -c -i $openssl_version ) -eq 0 ]]; then
    yum -y remove openssl openssl-devel  # 把系统自带的openssl卸载掉
    fi

     if [[ $(cmake -version |grep -c -i $cmake_version ) -eq 0 ]]; then
        yum -y remove cmake  # 把系统自带的cmake卸载掉
    fi


    yum -y install epel-release # 安装EPEL源(用于安装certbot)

    yum -y groupinstall "Development Tools" # 安装开发工具包

    yum -y install wget git libtool perl-core zlib-devel bzip2-devel python-devel # 安装编译openssl/cmake/boost所需的依赖
  }



  openssl_make(){
    if [[ $(openssl version | awk '{print $2}' |grep -c -i $openssl_version ) -eq 0 ]]; then
      echo "=============================开始安装 openssl================================="
    tar -xzvf $tmp_trojan/$openssl_tar -C  $tmp_trojan/&& cd  $tmp_trojan/$openssl_name && `$tmp_trojan/$openssl_name/config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib`
    make
    make test
    make install
    ###########建立动态连接库文件###############
    mkdir -p /etc/ld.so.conf.d/;
    if [ ! -f  /etc/ld.so.conf.d/$openssl_name.conf ];then
        touch /etc/ld.so.conf.d/$openssl_name.conf;
    fi
    echo '/usr/local/openssl/lib' > /etc/ld.so.conf.d/$openssl_name.conf ;
    ldconfig -v;
    ###########配置环境变量###############
    mkdir -p /etc/profile.d/;
    if [ ! -f  /etc/profile.d/$openssl_name.sh ];then
        touch /etc/profile.d/$openssl_name.sh;
    fi
    echo 'pathmunge /usr/local/openssl/bin' > /etc/profile.d/$openssl_name.sh;
    source /etc/profile;
    if [[ $(openssl version | awk '{print $2}' |grep -c -i $openssl_version ) -eq 0 ]]; then
      echo "=============================openssl 安装失败================================="
      exit 1;
    else
      echo "=============================openssl 安装成功================================="
    fi

  else
    echo "=============================openssl 已安装================================="
  fi
  }

  cmake_make(){
    if ! [[ -x $(command -v cmake )  ]];then
      echo "=============================开始安装 cmake================================="
      tar -xzvf $tmp_trojan/$cmake_tar -C $tmp_trojan/;
      cd $tmp_trojan/$cmake_name ;
      $tmp_trojan/$cmake_name/bootstrap;
      gmake
      gmake install
      if ! [[ -x $(command -v cmake )  ]];then
        echo "=============================cmake 安装失败================================="
        exit 2;
      else
        echo "=============================cmake 安装成功================================="
      fi
    else
      echo "=============================cmake 已安装================================="
    fi
  }


  boost_make(){
    if [[ $(find / -name libboost_random.so*| grep -c -i "boost") -eq 0 ]];then
      echo "=============================开始安装 boost================================="
      tar -xzvf $tmp_trojan/$boost_tar -C $tmp_trojan/ ;
      cd $tmp_trojan/$boost_name;
      bash $tmp_trojan/$boost_name/bootstrap.sh --prefix=/usr/local/include/boost;
      $tmp_trojan/$boost_name/b2
      $tmp_trojan/$boost_name/b2 install
      if [[ $(find / -name libboost_random.so*| grep -c -i "boost") -eq 0 ]];then
        echo "=============================boost 安装失败================================="
        exit 3;
      else
        echo "=============================boost 安装成功================================="
      fi
    else
      echo "=============================boost 已安装================================="
    fi
  }

  trojan_make(){
     if ! [[ -x "$(command -v trojan)" ]];then
      echo "=============================开始安装 trojan================================="
      trojan_bin_location='/usr/local/bin/';trojan_service_location='/etc/systemd/system/';
      rm -rf $tmp_trojan/$trojan_name/build;
      mkdir -p $tmp_trojan/$trojan_name/build;
      cd  $tmp_trojan/$trojan_name/build/;
      cmake  $tmp_trojan/$trojan_name/ -DENABLE_MYSQL=OFF -DENABLE_SSL_KEYLOG=ON -DFORCE_TCP_FASTOPEN=ON -DSYSTEMD_SERVICE=AUTO -DOPENSSL_ROOT_DIR=/usr/local/openssl -DBOOST_INCLUDEDIR=/usr/local/include/boost/include
      make
      cp $tmp_trojan/$trojan_name/build/trojan $trojan_bin_location;
      cp $tmp_trojan/$trojan_name/build/trojan.service $trojan_service_location;
      if ! [[ -x "$(command -v trojan)" ]];then
          echo "=============================trojan 安装失败================================="
          exit 5;
        else
          sed -i '/^User/d;/^AmbientCapabilities/d' $trojan_service_location/trojan.service;
          echo "=============================trojan 安装成功================================="
        fi
     else
          echo "=============================trojan 已安装================================="
      fi
  }
  trojan_json(){
    trojan_new_json="{
      \"run_type\": \"server\",
      \"local_addr\": \"$4\",
      \"local_port\": $5,
      \"remote_addr\": \"127.0.0.1\",
      \"remote_port\": 80,
      \"password\": [
          \"$1\"
      ],
      \"log_level\": 1,
      \"ssl\": {
          \"cert\": \"/etc/letsencrypt/live/$2/fullchain.pem\",
          \"key\": \"/etc/letsencrypt/live/$2/privkey.pem\",
          \"key_password\": \"\",
          \"cipher\": \"ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256\",
          \"prefer_server_cipher\": true,
          \"alpn\": [
              \"http/1.1\"
          ],
          \"reuse_session\": true,
          \"session_ticket\": false,
          \"session_timeout\": 600,
          \"plain_http_response\": \"\",
          \"curves\": \"\",
          \"dhparam\": \"\"
      },
      \"tcp\": {
          \"no_delay\": true,
          \"keep_alive\": true,
          \"fast_open\": $3,
          \"fast_open_qlen\": 20
      },
      \"mysql\": {
          \"enabled\": false,
          \"server_addr\": \"127.0.0.1\",
          \"server_port\": 3306,
          \"database\": \"trojan\",
          \"username\": \"trojan\",
          \"password\": \"\"
      }
  }"
    trojan_new_json=`echo  $trojan_new_json |sed 's/\"/\\\"/g'`;
    sudo rm -rf $CONFIG_PATH;
    sudo sh -c "echo  $trojan_new_json >$CONFIG_PATH";
    #sudo tee $CONFIG_PATH<<<$trojan_new_json
    #trojan_json_parsing `echo $trojan_new_json| sed -e "s/[ ][ ]*//g"` '.remote_addr.ff'
  }




  auto_config_modify(){
    #key=$1 #json key值
    title=$1 #要输入的名称
    config_orginal=`echo $2 |cut -f2 -d'"'`
    #获取当前key value
    #config_orginal=`grep -Poz '"'$key'":[[:space:]]*\K[\[]?["]?[^"]*["]?[\]]?,' $dire/configDemo.json |cut -f1 -d','`;
    new_config_orginal=$config_orginal
    # shellcheck disable=SC1087
    # shellcheck disable=SC2027
    echo -n "$title[默认:"$(echo $config_orginal| cut -f2 -d'"')"]:"; read new_config_modify
      if [[ x$new_config_modify != x ]]; then
	new_config_orginal=$new_config_modify;
      fi
    echo $new_config_orginal
  }

auto_config_make(){
new_config_orginal=$2;
 echo -n "$1[默认:$2]:"; read new_config_modify
      if [[ x$new_config_modify != x ]]; then
	new_config_orginal=$new_config_modify;
      fi
    echo $new_config_orginal

}

  sed_config(){
    key=$1
    old_config=$2
    new_config_orginal=$3
    sed -i '/"'$key'":/ {N; s/'$(echo ${old_config})'/'$(echo ${new_config_orginal})'/g}' $CONFIG_PATH
    #sed -i 'N;s/"'$key'":.*'$(echo ${old_config})'/"'$key'": '$(echo ${new_config_orginal})'/g' $dire/configDemo.json
  }

trojan_config_switch_update(){
 ######配置调用########

  domain_name=`${jq_file} '.ssl.cert' $CONFIG_PATH| cut -f 5 -d "/"`;

  auto_config_modify  "请输入正确域名" $domain_name  #原始value
  remote_addr_config=$new_config_orginal
  remote_addr_config_old=$config_orginal

  auto_config_modify  "请输入本地端口" `${jq_file} '.local_port' $CONFIG_PATH` #原始value
  local_port_config=$new_config_orginal
  local_port_config_old=$config_orginal

  auto_config_modify  "请输入密码" `${jq_file} '.password[0]' $CONFIG_PATH` #原始value
  password_config=$new_config_orginal
  password_config_old=$config_orginal

   auto_config_modify  "允许访问地址" `${jq_file} '.local_addr' $CONFIG_PATH` #原始value
  local_addr_config=$new_config_orginal
  local_addr_config_old=$config_orginal


   auto_config_modify  "是否开启快速访问" `${jq_file} '.tcp.fast_open' $CONFIG_PATH` #原始value
  fast_open_config=$new_config_orginal
  fast_open_config_old=$config_orginal

  #sed_config "remote_addr" $remote_addr_config_old $remote_addr_config #域名
  #sed_config "local_port" $local_port_config_old $local_port_config #监听本地端口
  #sed_config "password" $password_config_old $password_config #重新配置密码
  #sed_config "verify" $ssl_verify_config_old $ssl_verify_config #重新配置密码

  trojan_json $password_config $remote_addr_config $fast_open_config $local_addr_config $local_port_config

}

trojan_config_switch_make(){
 ######配置调用########
  auto_config_make  "请输入正确域名" "www.example.com" #原始value
  remote_addr_config=$new_config_orginal


  auto_config_make  "请输入本地端口" 443 #原始value
  local_port_config=$new_config_orginal


  auto_config_make  "请输入密码" "vpn" #原始value
  password_config=$new_config_orginal

   auto_config_make  "允许访问地址" "0.0.0.0" #原始value
  local_addr_config=$new_config_orginal

 auto_config_make  "是否开启快速访问" true #原始value
  fast_open_config=$new_config_orginal

trojan_json $password_config $remote_addr_config $fast_open_config $local_addr_config $local_port_config

}

ssl_domain(){
  auto_config_make  "请输入ssl域名" "www.example.com" #原始value
  remote_addr_config=$new_config_orginal
  certbot certonly --standalone -d $remote_addr_config;
}

trojan_config(){
  type_opt=$1;
  trojan_config_path='/usr/local/etc/trojan'
    if [ ! -d $trojan_config_path ];then
      mkdir -p $trojan_config_path
    fi

   if [[ $type_opt == 'update' ]] && [[ -f $CONFIG_PATH ]] ;then
      trojan_config_switch_update;
      systemctl stop trojan.service && systemctl start trojan.service
   else
      trojan_config_switch_make;
   fi
  }


centos_download_trojan(){
    wget -P ${tmp_trojan} https://www.openssl.org/source/$openssl_tar #openssl tar包

    wget -P ${tmp_trojan} https://cmake.org/files/v3.12/$cmake_tar #cmake tar包

    wget -P ${tmp_trojan}  https://dl.bintray.com/boostorg/release/1.68.0/source/$boost_tar #boost tar包

    if [ -d ${tmp_trojan}/trojan ];then # 删除存在的trojan
      `rm -rf ${tmp_trojan}/trojan`
    fi
    git clone https://github.com/trojan-gfw/trojan.git ${tmp_trojan}/${trojan_name}  #trojan 文件夹下载

    openssl_make #开始编译openssl

    cmake_make #开始编译cmake

    boost_make # 开始安装 boost

    trojan_make #开始安装trojan

    echo '###########  添加trojan 配置###############'
    trojan_config add;
    echo '###########  trojan 配置结束###############'
    yum -y install certbot;ssl_domain;
    systemctl daemon-reload && systemctl enable trojan.service && systemctl start trojan.service
  }

centos_create_tempdir(){
    `rm -rf ${tmp_trojan}`;
    if [ ! -f ${tmp_trojan} ] ;then
      `mkdir -p ${tmp_trojan}`;
      centos_download_trojan #下载到指定文件夹
    fi
  }





trojan_install(){  # trojan 安装
    if [[ ! -f /etc/redhat-release ]] || [[ `cat /etc/redhat-release | grep -c -i centos` -eq 0   ]] ; then
     echo "not found!"
     ubuntu_debian_update #ubuntu 系统更新
     ubuntu_tojan_install #安装 trojan
     echo '###########  添加trojan 配置###############'
     trojan_config update;
     echo '###########  trojan 配置结束###############'
     ssl_domain;
     if [[ `sudo systemctl daemon-reload |grep -c -i 'Refusing'` -gt 0 ]];then
         sudo mount -t tmpfs tmpfs /run -o remount,size=32M,nosuid,noexec,relatime,mode=755;
     fi
     sudo systemctl daemon-reload && sudo systemctl enable trojan.service && sudo systemctl start trojan.service;
    else
     echo "found!"
     centos_update  #系统更新
     centos_create_tempdir # 创建文件夹
    fi
  }

  serverSpeeder_set_boot_index(){
    boot_index=`sudo egrep ^menuentry /etc/grub2.cfg | cut -f 2 -d \' |grep -n "CentOS Linux (3.10.0-229.1.2.el7.x86_64)"|cut -f 1 -d :`
    index=$[boot_index-1];
    sudo grub2-set-default $index
      echo -n "是否重新启动y/n[默认:y] : ";read i
      if [ x$i == x ];then
        i='y';
      fi

     if [ $i == 'y' ]; then
       sudo reboot;
     else
       exit 1;
     fi
  }

  serverSpeeder_kenel_install(){ #锐速内核安装
    if [[ ! -f /etc/redhat-release ]] || [[ `cat /etc/redhat-release | grep -c -i centos` -eq 0   ]] ; then
     echo "not found!"
    else
    cat /etc/redhat-release;
    if [[ `rpm -qa |grep -ci kernel-3.10.0-229.1.2.el7.x86_64` -eq 0 ]] ; then
     yum -y update;  #系统更新
     rpm -ivh http://soft.91yun.org/ISO/Linux/CentOS/kernel/kernel-3.10.0-229.1.2.el7.x86_64.rpm --force; #安装支持锐速内核
     if [[ `rpm -qa |grep -ci kernel-3.10.0-229.1.2.el7.x86_64` -eq 0 ]] ; then
       echo "kernel installed is failed!";
     else
      serverSpeeder_set_boot_index;
     fi
   else
       if [[ `uname -r |grep -ci 3.10.0-229.1.2.el7.x86_64` -eq 0 ]] ; then
           echo -n "重新设置锐速内核启动项!";
           serverSpeeder_set_boot_index;
         else
           echo "锐速内核已安装!";
         fi
   fi
    fi
  }

  serverSpeeder_dowanload_install(){
    #rm -rf /tmp/serverspeeder.sh;
    if [[ ! -f /tmp/serverspeeder.sh ]]; then
   #wget --no-check-certificate -qO /tmp/appex.sh "https://raw.githubusercontent.com/0oVicero0/serverSpeeder_Install/master/appex.sh" && bash /tmp/appex.sh 'install';#此链接已失效
      wget -N --no-check-certificate -qO /tmp/serverspeeder.sh https://github.com/91yun/serverspeeder/raw/master/serverspeeder.sh && bash /tmp/serverspeeder.sh
   else
     #`bash /tmp/appex.sh 'install'`失效
     `bash /tmp/serverspeeder.sh`;
   fi
  }

  serverSpeeder_install(){
    if [[ ! -f /etc/redhat-release ]] || [[ `cat /etc/redhat-release | grep -c -i centos` -eq 0   ]] ; then
     echo "not found!"
    else
    cat /etc/redhat-release;
    if [[ `uname -r |grep -ci 3.10.0-229.1.2.el7.x86_64` -eq 0 ]] ; then
      echo -n "未安装支持锐速内核! 是否安装锐速内核y/n[默认:y] : ";read i
      if [ x$i == x ];then
        i='y';
      fi

     if [ $i == 'y' ]; then
       serverSpeeder_kenel_install;
     else
       exit 1;
     fi
   else
      serverSpeeder_dowanload_install;
   fi
    fi
  }

  serverSpeeder_uninstall(){
    `chattr -i /serverspeeder/etc/apx* && /serverspeeder/bin/serverSpeeder.sh uninstall -f`
  }


switchConfig(){
    echo -n "请输入上面数字进行操作[默认:1] : ";read i
    if [ x$i == x ];then
      i=1;
    fi
    if [ $i == 1 ]; then
       echo "修改配置";
       trojan_config update;
       if [[ `systemctl daemon-reload |grep -c -i 'Refusing'` -gt 0 ]];then
          mount -t tmpfs tmpfs /run -o remount,size=32M,nosuid,noexec,relatime,mode=755;
       fi
       `systemctl stop trojan&& systemctl start trojan`
    elif [ $i == 2 ]; then
      trojan_install;
    elif [[ $i == 3 ]]; then
      serverSpeeder_kenel_install  #锐速内核安装
    elif [[ $i == 4 ]]; then
      serverSpeeder_install;
    elif [[ $i == 5 ]]; then
      serverSpeeder_uninstall;
    fi
  }
cat <<F
 1. 修改配置
 2. 安装
 3. 锐速内核安装
 4. 锐速安装
 5. 锐速卸载
F
switchConfig;
