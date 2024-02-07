#!/bin/sh

DEBUG=0
VERSION="1.0.7"

# linux
USER_BIN="/data/bin"

# mqtt configuration
PUB=""
SUB=""
MQTT_CONF="/data/etc/mqtt.conf"
MQTT_IP=""
MQTT_USER=""
MQTT_PASSWORD=""
MQTT_PORT=""
MQTT_ARGS=""

# S1E info
DEVICE_NAME=""
DID=""
MODEL=""
SW_VERSION=""

# S1E Home Assistant
NAME="s1e2ha"
S1E2HA_URL="https://raw.githubusercontent.com/niceboygithub/AqaraSmartSwitchS1E/master/homeassistant/$NAME.tar.gz"

info() {
    echo "INFO: $@"
}

warn() {
    echo -e '\033[1;35m'"WARN: $@"'\033[0m'
}

debug() {
    if [ "x$DEBUG" == "x1" ]; then
        echo "DEBUG: $@"
    fi
}

error() {
    echo -e '\033[1;31m'"ERROR: $@"'\033[0m'
    exit 1
}

check_mqtt() {
    if [ -x "/bin/mosquitto_sub" ]; then
        SUB="/bin/mosquitto_sub"
    elif [ -x "$USER_BIN/mosquitto_sub" ]; then
        SUB="$USER_BIN/mosquitto_sub"
    elif [ -x "/tmp/bin/mosquitto_sub" ]; then
        SUB="/tmp/bin/mosquitto_sub"
    fi
    if [ -x "/bin/mosquitto_pub" ]; then
        PUB="/bin/mosquitto_pub"
    elif [ -x "$USER_BIN/mosquitto_pub" ]; then
        PUB="$USER_BIN/mosquitto_pub"
    elif [ -x "/tmp/bin/mosquitto_pub" ]; then
        PUB="/tmp/bin/mosquitto_pub"
    fi

    if [ -z "$PUB" -o -z "$SUB" ]; then
        error "The mosquitto_pub or mosquitto_sub are not exist!"
    fi
}

welcome() {

    echo
    echo "Welcome the Installation of Aqara Smart Swich S1E to Home Assistant $VERSION"
    echo
    echo "This installation will help you install package that can make S1E connect to Home Assistant"
    echo "Please the follow the instrustions to configure related settings."
    echo
    echo "The current version of $DEVICE_NAME ($DID) is $SW_VERSION. "
    echo
}

check_installed() {
    local install=
    local param=$1

    if [ "x$param" == "x-r" ]; then
        warn "The $NAME was installed! Do you want to uninstall?"
        read -p "Please answer yes or no: " install
        if [ "x$install" != "xno" -o "x$install" == "xyes" ]; then
            killall -9 res_monitor.sh > /dev/null 2>&1
            killall -9 mqtt_sub.sh > /dev/null 2>&1
            killall -9 ubus_monitor.sh > /dev/null 2>&1
            rm -f $USER_BIN/res_monitor.sh $USER_BIN/mqtt_sub.sh $USER_BIN/ubus_monitor.sh $USER_BIN/run_$NAME.sh
            rm -f $MQTT_CONF $USER_BIN/mosquitto_pub $USER_BIN/mosquitto_sub $USER_BIN/curl $USER_BIN/frame.sh
            chattr -i "/data/scripts/post_init.sh"
            sed -e ':a' -e 'N' -e '$!ba' -e "s,\n\[ -x $USER_BIN/run_s1e2ha.sh \] \&\& $USER_BIN/run_$NAME.sh,,g" -i "/data/scripts/post_init.sh"
            chattr +i "/data/scripts/post_init.sh"
            info "Bye!"
            exit 0
        fi
    fi

    if [ "x$param" != "x-u" ]; then
        if [ -f "$MQTT_CONF" ]; then
            warn "The $NAME was installed! Do you want to reinstall again?"
            read -p "Please answer yes or no: " install
            if [ "x$install" == "xno" -o "x$install" != "xyes" ]; then
                info "Bye!"
                exit 0
            fi
            rm -f $MQTT_CONF
        fi
    fi
    killall -9 res_monitor.sh > /dev/null 2>&1
    killall -9 mqtt_sub.sh > /dev/null 2>&1
    killall -9 ubus_monitor.sh > /dev/null 2>&1
    rm -f $USER_BIN/res_monitor.sh $USER_BIN/mqtt_sub.sh $USER_BIN/ubus_monitor.sh $USER_BIN/run_$NAME.sh
}

get_config() {
    local mqtt_ip=; local mqtt_port=
    local mqtt_user=; local mqtt_password=
    local retry=3; local subscribe=0
    local param=$1

    if [ "x$param" == "x-u" ]; then
        return
    fi

    for i in `seq 1 $retry`; do
        read -p "The ip addr of MQTT Broker  []: " mqtt_ip
        read -p "The port of MQTT Broker [1883]: " mqtt_port
        read -p "The username of MQTT Broker []: " mqtt_user
        read -p "The password of MQTT Broker []: " mqtt_password

        ping -c 1 -W 2 $mqtt_ip > /dev/null 2>&1 && ret=$?
        if [ "x$ret" != "x0" ]; then
            warn "The ip of MQTT Broker is not exist. Please input again."
            mqtt_ip=""
        fi

        if [ -n "$mqtt_ip" ]; then
            MQTT_ARGS="`echo "-h $mqtt_ip"` `[ ! -z $mqtt_user ] && echo "-u $mqtt_user -P $mqtt_password"` `[ ! -z $mqtt_port ] && echo "-p $mqtt_port" || echo "-p 1883"`"
            topic="homeassistant/#"

            info "Testing the connection of MQTT broker, pleae wait a while!"
            echo
            subscribe=$($SUB $MQTT_ARGS -t $topic -v --retained-only -C 1 -W 3 --quiet)
            ret=$?
            if [ "x$subscribe" != "x" ]; then
                MQTT_IP=$mqtt_ip
                MQTT_USER=$mqtt_user
                MQTT_PASSWORD=$mqtt_password
                MQTT_PORT=`[ ! -z $mqtt_port ] && echo "$mqtt_port" || echo "1883"`
                return
            fi
            if [ "x$ret" != "x0" ]; then
                warn "Can not connecto MQTT broker, please try agin"
                echo
            else
                MQTT_IP=$mqtt_ip
                MQTT_USER=$mqtt_user
                MQTT_PASSWORD=$mqtt_password
                MQTT_PORT=`[ ! -z $mqtt_port ] && echo "$mqtt_port" || echo "1883"`
                return
            fi

            if [ $i -gt 3 ]; then
                error "Can not config MQTT broker. Exit!"
            fi
        else
            warn "The info of MQTT broker is incorrect!"
        fi
        echo
    done
    if [ "x$subscribe" == "x0" ]; then
        error "Can not config MQTT broker. Exit!"
    fi
}

save_config() {
    local param=$1

    if [ "x$param" != "x-u" ]; then
        if [ -n "$MQTT_IP" ]; then
            if [ ! -d "/data/etc" ]; then
                mkdir /data/etc
            fi
            echo "MQTT_IP=$MQTT_IP" > $MQTT_CONF
            [ ! -z $MQTT_USER ] && echo "MQTT_USER=$MQTT_USER" >> $MQTT_CONF
            [ ! -z $MQTT_PASSWORD ] && echo "MQTT_PASSWORD=$MQTT_PASSWORD" >> $MQTT_CONF
            echo "MQTT_PORT=$MQTT_PORT" >> $MQTT_CONF
        fi
        mv -f /tmp/curl /tmp/bin
    fi

    # move all file to /data/bin
    mv -f /tmp/bin/* $USER_BIN
}

get_product_info() {
    DEVICE_NAME=$(agetprop ro.sys.name)
    DID=$(agetprop persist.app.dfu_did | cut -d '.' -f 2)
    MODEL=$(agetprop ro.sys.product)
    SW_VERSION=$(agetprop ro.sys.fw_ver)_$(agetprop ro.sys.build_num)
    IDENTIFIERS=$(agetprop persist.sys.sn)
    debug "{\"name\": \"$DEVICE_NAME\", \"identifiers\": \"$IDENTIFIERS\", \"sw_version\": \"$SW_VERSION\", \"model\": \"$MODEL\", \"manufacturer\": \"Aqara\"}"
}

get_s1e2ha() {
    local cpath="/tmp/curl"
    local param=$1

    if [ "x$param" == "x-u" ]; then
        cpath=/data/bin/curl
    fi

    if [ ! -d "$USER_BIN" ]; then
        mkdir $USER_BIN
    fi

    if [ ! -x "$cpath" ]; then
        error "The $cpath is not exist! Exit!"
    fi

    echo
    info "Getting $NAME package, please wait."
    echo

    $cpath -s -k -L -o /tmp/$NAME.tar.gz $S1E2HA_URL
    ret=$?
    if [ "x$ret" != "x0" ]; then
        error "Can not get S1E to Home Assistant package ($NAME)!"
    fi
    tar -xzf /tmp/$NAME.tar.gz -C /tmp
    ret=$?
    if [ "x$ret" != "x0" ]; then
        error "Extract package failed!"
    fi

    [ ! -x "/tmp/bin/mosquitto_pub" ] && error "The mosquitto_pub is not executable! Please report to developer."
    [ ! -x "/tmp/bin/mosquitto_sub" ] && error "The mosquitto_sub is not executable! Please report to developer."
    [ ! -x "/tmp/bin/run_$NAME.sh" ] && error "The run_$NAME.sh is not executable! Please report to developer."
    [ ! -x "/tmp/bin/ubus_monitor.sh" ] && error "The ubus_monitor.sh is not executable! Please report to developer."
    [ ! -x "/tmp/bin/res_monitor.sh" ] && error "The res_monitor.sh is not executable! Please report to developer."
    [ ! -x "/tmp/bin/mqtt_sub.sh" ] && error "The mqtt_sub.sh is not executable! Please report to developer."
    chown -Rf root:root /tmp/bin
}

set_post_init() {
    local spath="/data/scripts"; local installed=
    local param=$1

    if [ ! -d "$spath" ]; then
        mkdir $spath
    fi

    if [ "x$param" == "x-u" ]; then
        return
    fi

    if [ -f "$spath/post_init.sh" ]; then
        installed=$(cat $spath/post_init.sh | grep run_$NAME.sh)
        if [ -n "$installed" ]; then
            warn "The S1E to HA is already installed!"
        fi
        chattr -i "$spath/post_init.sh"
    else
        echo -e "#!/bin/sh\n\npasswd -d $USER\nfw_manager.sh -r\napp_start.sh -g\nfw_manager.sh -t -k\n" > "$spath/post_init.sh"
    fi
    chmod a+x "$spath/post_init.sh"

    if [ -x "$USER_BIN/run_$NAME.sh" ]; then
        ret=$(echo "$spath/post_init.sh" | grep "$USER_BIN/run_$NAME.sh")
        if [ "x$ret" == "x" ]; then
            echo -e "\n[ -x $USER_BIN/run_$NAME.sh ] && $USER_BIN/run_$NAME.sh" >> "$spath/post_init.sh"
        fi
    fi
    chattr +i "$spath/post_init.sh"
}

set_aqgui_lang() {
    local aqgui_cht=n; local installed=; local current=
    local param=$1

    if [ "x$param" == "x-u" ]; then
        return
    fi

    read -p "Do you want set aqgui to 1. English 2. Simplified Chinese 3. Traditional Chinese (1/2/3/n): " aqgui_cht

    if [ "x$aqgui_cht" == "xn" ]; then
        info "No Change the language of UI!"
    fi

    if [ "x$aqgui_cht" == "x1" ]; then
        current=$(ubus -S call setting get.display)
        new=$(echo $current | sed -r "s/\"language\":\"(.*)\",\"autoBrightness/\"language\":\"en\",\"autoBrightness/g")
        ubus -S call setting set.display '$new'
    fi

    if [ "x$aqgui_cht" == "x2" ]; then
        current=$(ubus -S call setting get.display)
        new=$(echo $current | sed -r "s/\"language\":\"(.*)\",\"autoBrightness/\"language\":\"zh\",\"autoBrightness/g")
        ubus -S call setting set.display '$new'
    fi

    if [ "x$aqgui_cht" == "x3" ]; then
        current=$(ubus -S call setting get.display)
        new=$(echo $current | sed -r "s/\"language\":\"(.*)\",\"autoBrightness/\"language\":\"zh-TW\",\"autoBrightness/g")
        ubus -S call setting set.display '$new'
    fi
}

enjoy_s1e2ha() {
    $USER_BIN/run_$NAME.sh &
    rm -rf /tmp/$NAME.tar.gz
    echo
    echo "Aqara Smart Swich S1E to Home Assistant $VERSION is installed!"
    echo "Enjoy!"
    echo
}

usage() {
    echo
    echo "usage: install_s1e2ha.sh [ -h | -u | -r ]"
    echo
    echo "The Installation of Aqara Smart Swich S1E to Home Assistant $VERSION"
    echo
    echo "optional arguments:"
    echo " -h          show this help message and exit"
    echo " -r          Uninstall $NAME"
    echo " -u          Upgrade $NAME"
    echo

    exit 0
}

# main
params=$1

[ "x$params" == "x-h" ] && usage

get_product_info
welcome
check_installed $params
get_s1e2ha $params
check_mqtt
get_config $params
save_config $params
set_post_init $params
set_aqgui_lang $params
enjoy_s1e2ha
