#!/bin/sh

REVISION="2"
REVISION_FILE="/data/utils/fw_manager.revision"

#
# @file    s1e_update.sh
# @brief   This script is used to manage program operations,
#          including, but not limited to,
#          1. update firmware.
#
# @author  Niceboy (niceboygithub@github.com)
# @author  Michael (huiwang.zhu@aqara.com)
#
# Copyright (c) 2020~2021 ShenZhen Lumiunited Technology Co., Ltd.
# All rights reserved.
#

#
# Script options.
# -h: helper.
# -u: update.
#
OPTIONS="-h;-u;"

#
# Platforms.
# -a: AIOT.
# -m: MIOT.
#
PLATFORMS="-a;-m"

#
# Default platform.
# Must in aiot;miot.
#
DEFAULT_PLATFORM="aiot"

#
# Tag files.
#
MODEL_FILE="/data/utils/fw_manager.model"
_ble_ota_bak_file="/data/ble_ota_bak.bin"

#
# Product model, support list: AC_P3, AH_M1S, AH_M2.
#
# AC_P3 : Air Condition P3.
# AH_M1S: Aqara Hub M1S.
# AH_M2 : Aqara Hub M2.

#
# Version and md5sum
#
FIRMWARE_URL="https://raw.githubusercontent.com/niceboygithub/AqaraSmartSwitchS1E/master/firmwares"
VERSION="2.0.6_0000"
KERNEL_MD5SUM="de202a2bfa1ecaaf05dc397d688bdfdd"
ROOTFS_MD5SUM="fd99afe4d2dc70bef356975a27432958"
BTBL_MD5SUM=""
BTAPP_MD5SUM=""
IRCTRL_MD5SUM=""
kernel_bin_=""
rootfs_bin_=""

#
# note: default is unknow.
#
model=""

#
# Enable debug, 0/1.
#
debug=1


ota_dir_="/data/ota_unpack"
coor_dir_="/data/ota-files"
fws_dir_="/data/ota_dir"

#
# Show green content, in the same way to use as echo.
#
green_echo() {
    if [ $debug -eq 0 ]; then return; fi

    GREEN="\033[0;32m"
    BLACK="\033[0m"
    if [ "$1" = "-n" ]; then echo -en $GREEN$2$BLACK; else echo -e $GREEN$1$BLACK; fi
}

#
# Show red content, in the same way to use as echo.
#
red_echo() {
    RED="\033[0;31m"
    BLACK="\033[0m"
    if [ "$1" = "-n" ]; then echo -en $RED$2$BLACK; else echo -e $RED$1$BLACK; fi
}

#
# Match sub-string.
#
# param $1: string.
# Param $2: sub-string.
#
# return: 1 - matched.
# return: 0 - unmatch.
#
match_substring() {
    string="$1"
    substr="$2"

    case $string in
    *$substr*) return 1 ;;
    *) return 0 ;;
    esac
}

#
# Convert rom string to number.
# Param: value string.
#
convert_str2int() {
    local str=$1
    local length=${#str}
    local sum=0
    local index=0

    while [ ${index} -lt ${length} ]; do
        let sum=10*sum+${str:${index}:1}
        let index+=1
    done

    echo ${sum}
}

#
# Set some tags into file.
# Param1: file.
# Param2: tags.
#
set_tags() {
    local file="$1"
    local tags="$2"

    if [ ! -f "$file" ]; then
        local dir=$(dirname "$file")
        if [ ! -d "$dir" ]; then mkdir "$dir"; fi
    fi

    echo "$tags" >"$file"
}

usage_helper() {
    green_echo "Helper to show how to use this script."
    green_echo "Usage: s1e_update.sh -h [$OPTIONS]."
}

usage_updater()
{
    green_echo "Update firmware."
    green_echo "Usage: s1e_update.sh -u [$UPDATER] [path]."
    green_echo " -s : check md5sum."
    green_echo " -n : don't check md5sum."
}

wait_property_svr_ok() {
    for i in $(seq 10); do
        sys_name=$(agetprop ro.sys.name)
        if [ x"$sys_name" != x ]; then
            echo "psvr ok,wait=$i"
            break
        fi
        sleep 0.1
        echo "wait pro svr"
    done
}

#
# Stop AIOT programs.
# Note: We can specifing some programs to keep alive
#       by use of format string: "x;x;x...".
#
# Flag: ha_driven        : d
#       ha_master        : m
#       ha_basis         : b
#       ha_agent         : a
#       property_service : p
#       zigbee_agent     : z
#
# For example: keep ha_basis and ha_master alive: stop_aiot "b;m"
#
stop_aiot()
{
    local d=0; local m=0; local b=0
    local a=0; local p=0; local z=0
    local l=0;

    match_substring "$1" "d"; d=$?
    match_substring "$1" "m"; m=$?
    match_substring "$1" "b"; b=$?
    match_substring "$1" "a"; a=$?
    match_substring "$1" "p"; p=$?
    match_substring "$1" "z"; z=$?
    match_substring "$1" "l"; l=$?

    green_echo "d:$d, m:$m, b:$b, a:$a, p:$p, z:$z, l:$l"

    # Stop monitor.
    killall -9 app_monitor.sh

    sleep 1.5

    #
    # Send a signal to programs.
    #
    if [ $d -eq 0 ]; then killall ha_driven        ;fi
    if [ $m -eq 0 ]; then killall ha_master        ;fi
    if [ $b -eq 0 ]; then killall ha_basis         ;fi
    if [ $a -eq 0 ]; then killall ha_agent         ;fi
    if [ $p -eq 0 ]; then killall property_service ;fi
    if [ $z -eq 0 ]; then killall zigbee_agent     ;fi
    if [ $l -eq 0 ]; then killall ha_lanbox        ;fi

    sleep 1

    #
    # Force to kill programs.
    #
    if [ $d -eq 0 ]; then killall -9 ha_driven        ;fi
    if [ $m -eq 0 ]; then killall -9 ha_master        ;fi
    if [ $b -eq 0 ]; then killall -9 ha_basis         ;fi
    if [ $a -eq 0 ]; then killall -9 ha_agent         ;fi
    if [ $p -eq 0 ]; then killall -9 property_service ;fi
    if [ $z -eq 0 ]; then killall -9 zigbee_agent     ;fi
    if [ $l -eq 0 ]; then killall -9 ha_lanbox        ;fi
}

#
# Stop MIOT programs.
# Note: We can specifing some programs to keep alive
#       by use of format string: "x;x;x...".
#
# Flag: mha_basis        : b
#       mha_master       : m
#       homekitserver    : h
#       miio_agent       : g
#       miio_client      : c
#       mzigbee_agent    : z
#       mijia_automation : a
#       property_service : p
#
# For example: keep mha_basis and mha_master alive: stop_miot "b;m"
#
stop_miot() {
    local b=0
    local m=0
    local h=0
    local g=0
    local c=0
    local z=0
    local a=0
    local p=0
    local l=0

    match_substring "$1" "b"
    b=$?
    match_substring "$1" "m"
    m=$?
    match_substring "$1" "h"
    h=$?
    match_substring "$1" "g"
    g=$?
    match_substring "$1" "c"
    c=$?
    match_substring "$1" "z"
    z=$?
    match_substring "$1" "a"
    a=$?
    match_substring "$1" "p"
    p=$?

    # Stop monitor.
    killall -9 app_monitor.sh

    sleep 1.5

    #for TI coordinator end
    # /bin/ti_linux_host/end.sh

    #
    # Send a signal to programs.
    #
    killall -9 miio_client_helper_nomqtt.sh
    if [ $a -eq 0 ]; then killall mijia_automation; fi
    if [ $h -eq 0 ]; then killall homekitserver; fi
    if [ $m -eq 0 ]; then killall mha_master; fi
    if [ $c -eq 0 ]; then killall miio_client; fi
    if [ $b -eq 0 ]; then killall mha_basis; fi
    if [ $p -eq 0 ]; then killall property_service; fi
    if [ $g -eq 0 ]; then killall miio_agent; fi
    if [ $z -eq 0 ]; then killall mzigbee_agent; fi
    if [ $l -eq 0 ]; then killall mZ3GatewayHost_MQTT; fi

    # P3 programs.
    if [ "$model" = "AC_P3" ]; then killall mha_ir; fi

    sleep 1

    #
    # Force to kill programs.
    #
    if [ $a -eq 0 ]; then killall -9 mijia_automation; fi
    if [ $h -eq 0 ]; then killall -9 homekitserver; fi
    if [ $m -eq 0 ]; then killall -9 mha_master; fi
    if [ $c -eq 0 ]; then killall -9 miio_client; fi
    if [ $b -eq 0 ]; then killall -9 mha_basis; fi
    if [ $p -eq 0 ]; then killall -9 property_service; fi
    if [ $g -eq 0 ]; then killall -9 miio_agent; fi
    if [ $z -eq 0 ]; then killall -9 mzigbee_agent; fi
    if [ $l -eq 0 ]; then killall -9 mZ3GatewayHost_MQTT; fi

    # P3 programs.
    if [ "$model" = "AC_P3" ]; then killall -9 mha_ir; fi
}

force_stop_unlimited() {
    killall -9 app_monitor.sh
    killall -9 property_service

    # AIOT
    killall -9 ha_master
    killall -9 zigbee_agent
    killall -9 ha_driven
    killall -9 ha_basis
    killall -9 ha_agent
    killall -9 ha_lanbox
    killall -9 Z3GatewayHost_MQTT
    sleep 2

    # MIOT
    killall -9 miio_client
    killall -9 miio_agent
    killall -9 miio_client_helper_nomqtt.sh
    killall -9 mha_master
    killall -9 mha_basis
    killall -9 mzigbee_agent
    killall -9 mijia_automation
    killall -9 homekitserver
    killall -9 mZ3GatewayHost_MQTT
}

#
# Backup homekit token info to res partition.
#
hap_token_backup() {
    local hap_token_uuid=$1
    local hap_token_key=$2

    # Backup hap_uuid and hap_token_key to /misc
    echo ${hap_token_uuid} >/misc/hap_token_uuid
    echo ${hap_token_key} >/misc/hap_token_key

    sync
    green_echo "Backup hap_token_uuid and hap_token_key to '/misc' succeed."
}

#
# Recovery homekit token info from res partition.
#
hap_token_recovery() {
    if [ -e /misc/hap_token_uuid ]; then
        local hap_token_uuid_property=$(agetprop persist.sys.hap_token_uuid)
        local hap_token_uuid_res=$(cat /misc/hap_token_uuid)
        if [ "$hap_token_uuid" != "$hap_token_uuid_res" ]; then
            asetprop persist.sys.hap_token_uuid "$hap_token_uuid_res"
            green_echo "Recovery hap_token_uuid from production partition."
        fi

        rm -f /misc/hap_token_uuid
    fi

    if [ -e /misc/hap_token_key ]; then
        local hap_token_key=$(agetprop persist.sys.hap_token_key)
        local hap_token_key_res=$(cat /misc/hap_token_key)
        if [ "$hap_token_key" != "$hap_token_key_res" ]; then
            asetprop persist.sys.hap_token_key "$hap_token_key_res"
            green_echo "Recovery hap_token_key from production partition."
        fi

        rm -f /misc/hap_token_key
    fi
}

dir_mount_ok() {
    n=$(cat /proc/mounts | grep $1)
    if [ x"$n" != x ]; then
        echo "1"
    fi
}

#
# Switch to platform: AIOT.
#

parse_json() {
    echo "${1//\"/}" | sed "s/.*$2:\([^,}]*\).*/\1/"
}
#to avoid coor cloud status confused

check_coor_cloud() {
    CUR_CLOUD=$1
    local COOR_MIOT_FALG="0x126e"
    local COOR_AIOT_FALG="0x115f"

    local COOR_INFO="/data/zigbee/coordinator.info"
    for n in $(seq 3); do
        buf=$(cat /data/zigbee/coordinator.info)
        manu_code="$(parse_json "$buf" "manuCode")"
        if [ "$CUR_CLOUD" = "aiot" ]; then
            if [ "$manu_code" != $COOR_AIOT_FALG ]; then
                zigbee_msnger cloud aiot
                sleep 2
            else
                return 0
            fi
        fi
        if [ "$CUR_CLOUD" = "miot" ]; then
            if [ $manu_code != "$COOR_MIOT_FALG" ]; then
                zigbee_msnger cloud miot
                sleep 2
            else
                return 0
            fi
        fi
    done
    return 1
}

#
# Prepare for update.
# Return value 1 : failed.
# Return value 0 : ok.
#
update_prepare() {
    # ota_dir_="/data/ota_unpack"
    # coor_dir_="/data/ota-files"
    # fws_dir_="/data/ota_dir"

    # Clean old firmware directory.
    if [ -d $fws_dir_ ]; then rm $fws_dir_ -rf; fi
    if [ -d $coor_dir_ ]; then rm $coor_dir_ -rf; fi
    if [ -d $ota_dir_ ]; then rm $ota_dir_ -rf; fi

    # Clean log files.
    rm /tmp/bmlog.txt* -f
    rm /tmp/zblog.txt* -f
    rm /tmp/aulog.txt* -f
    rm /tmp/uilog.txt* -f

    killall -9 app_monitor.sh
    killall -9 gui_monitor.sh

    #cd /bin/ti_linux_host
    #./end.sh
    #cd -
    #sleep 0.1

    echo 3 >/proc/sys/vm/drop_caches
    sleep 1

    dfu_pkg_="$1"

    firmwares_="$fws_dir_/lumi_fw.tar"

    kernel_bin_="$ota_dir_/kernel"
    rootfs_bin_="$ota_dir_/rootfs.sqfs"

    irctrl_bin_="$ota_dir_/IRController.bin"
    ble_bl_bin_="$ota_dir_/bootloader.gbl"
    ble_app_bin_="$ota_dir_/full.gbl"

    ble_bl_bin_bk_="/data/bootloader.gbl"
    ble_app_bin_bk_="/data/full.gbl"

    local dfusize=17039
    local memfree=$(cat /proc/meminfo | grep MemFree | tr -cd "[0-9]")
    local romfree=$(df | grep data | awk '{print $4}')

    dfusize_=$(convert_str2int "$dfusize")
    memfree_=$(convert_str2int "$memfree")
    romfree_=$(convert_str2int "$romfree")

    green_echo "Original OTA package : $dfu_pkg_"
    green_echo "Unpack path          : $ota_dir_"
    green_echo "Firmware path        : $fws_dir_"
    green_echo "OTA packages size(kb) : $dfusize_"
    green_echo "Available ROM size(kb): $romfree_"
    green_echo "Available RAM size(kb): $memfree_"

    # Check memory space.
    # Failed to get var if romfree_/memfree_ equal zero.
    if [[ $romfree_ -lt $dfusize_ ]]; then
        red_echo "Not enough storage available!"
        return 1
    fi

    mkdir -p $fws_dir_ $coor_dir_ $ota_dir_

    return 0
}

update_get_packages()
{
    local platform="$1"
    local simple_model=""
    local path="$2"
    local nocheck="$3"

    # Air Condition.
    if   [ "$model" = "AC_P3" ]; then simple_model="P3"
    # Aqara Hub M1S.
    elif [ "$model" = "AH_M1S" ]; then simple_model="M1S"
    # Aqara Hub M2.
    elif [ "$model" = "AH_M2_BLE" ]; then simple_model="M2"
    # Aqara Hub H1.
    elif [ "$model" = "AH_H1" ];  then simple_model="H1"
    # Aqara Smart Switch S1E.
    elif [ "$model" = "AH_S1E" ];  then simple_model="S1E"
    # End
    fi

    if [ "x${simple_model}" == "x" ]; then
        echo "Error: Unknow model"
        return 1
    fi

    echo "Update to ${VERSION}"
    echo "Get packages, please wait..."
    if [ "x${simple_model}" == "xP3" ]; then
        if [ "x${IRCTRL_MD5SUM}" != "x" ]; then
            /tmp/curl -s -k -L -o /tmp/IRController.bin ${FIRMWARE_URL}/original/${simple_model}/${VERSION}/IRController.bin
            [ "$(md5sum /tmp/IRController.bin)" != "${IRCTRL_MD5SUM}  /tmp/IRController.bin" ] && return 1
        fi
    fi

    if [ "x${BTBL_MD5SUM}" != "x" ]; then
        /tmp/curl -s -k -L -o /tmp/bootloader.gbl ${FIRMWARE_URL}/original/${simple_model}/${VERSION}/bootloader.gbl
        [ "$(md5sum /tmp/bootloader.gbl)" != "${BTBL_MD5SUM}  /tmp/bootloader.gbl" ] && return 1
    fi

    if [ "x${BTAPP_MD5SUM}" != "x" ]; then
        /tmp/curl -s -k -L -o /tmp/full.gbl ${FIRMWARE_URL}/original/${simple_model}/${VERSION}/full.gbl
        [ "$(md5sum /tmp/full.gbl)" != "${BTAPP_MD5SUM}  /tmp/full.gbl" ] && return 1
    fi

    if [ "x${simple_model}" != "xS1E" ]; then
         /tmp/curl -s -k -L -o /tmp/ControlBridge.bin ${FIRMWARE_URL}/original/${simple_model}/${VERSION}/ControlBridge.bin
        [ "$(md5sum /tmp/ControlBridge.bin)" != "${COOR_MD5SUM}  /tmp/ControlBridge.bin" ] && return 1
    fi

    /tmp/curl -s -k -L -o /tmp/linux.bin ${FIRMWARE_URL}/original/${simple_model}/${VERSION}/kernel_${VERSION}
    [ "$(md5sum /tmp/linux.bin)" != "${KERNEL_MD5SUM}  /tmp/linux.bin" ] && return 1

    /tmp/curl -s -k -L -o /tmp/rootfs.bin ${FIRMWARE_URL}/modified/${simple_model}/${VERSION}/rootfs_${VERSION}_modified.sqfs
    [ "$(md5sum /tmp/rootfs.bin)" != "${ROOTFS_MD5SUM}  /tmp/rootfs.bin" ] && return 1

    echo "Got packages done"
    return 0
}

update_clean() {
    rm -rf "$dfu_pkg_" "$fws_dir_" "$ota_dir_"
    sync
    sync
    sync
    sleep 1
}

#
# Check update status was block or not.
# return value 1: true.
# return value 0: false.
#
update_block() {
    local result=$(agetprop sys.dfu_progress)
    if [ "$result" = "-1" ]; then return 1; fi

    return 0
}

confirm_coor() {
    zigbee_msnger get_zgb_ver
    sleep 0.1
    local index2=$(agetprop sys.coor_update)
    if [ "$index2" != "true" ]; then
        return 1
    else
        # check ver
        local ver=$(agetprop persist.sys.zb_ver)
        if [ "$g_zbcoor_need_ver" = "$ver" ]; then
            echo "same ver"
            return 0
        else
            red_echo "diff ver"
            echo "need ver:$g_zbcoor_need_ver,curr ver:$ver"
        fi
    fi
    return 1
}

update_before_start() {
    local platform="$1"

    if [ -f "/tmp/IRController.bin" ]; then
        mv /tmp/IRController.bin $irctrl_bin_
    fi

    if [ -f "/tmp/ControlBridge.bin" ]; then
        mv /tmp/ControlBridge.bin $zbcoor_bin_
    fi

    if [ -f "/tmp/bootloader.gbl" ]; then
        mv /tmp/bootloader.gbl $ble_bl_bin_
    fi

    if [ -f "/tmp/full.gbl" ]; then
        mv /tmp/full.gbl $ble_app_bin_
    fi

    if [ -f "/tmp/linux.bin" ]; then
        mv /tmp/linux.bin $kernel_bin_
    fi

    if [ -f "/tmp/rootfs.bin" ]; then
        mv /tmp/rootfs.bin $rootfs_bin_
    fi
}

get_kernel_partitions() {

    /etc/fw_printenv | grep bootcmd | awk '{print $4}'
}

get_rootfs_partitions() {

    cat /proc/cmdline | grep mtdblock7
}

set_kernel_partitions() {
    if [ "$1" = "KERNEL" ]; then
        /etc/fw_setenv bootcmd "nand read.e 0x22000000 KERNEL_BAK 0x2d0000; dcache on; st7701; bootlogo 0 0 0 0;pwm 0 200000 200000 14; bootm 0x22000000;nand read.e 0x22000000 KERNEL 0x2d0000; dcache on; bootm 0x22000000"
    else
        /etc/fw_setenv bootcmd "nand read.e 0x22000000 KERNEL 0x2d0000; dcache on;st7701; bootlogo 0 0 0 0; pwm 0 200000 200000 14;bootm 0x22000000;nand read.e 0x22000000 KERNEL_BAK 0x2d0000; dcache on; bootm 0x22000000"
    fi
}

set_rootfs_partitions() {
    if [ x"$1" != x ]; then
        /etc/fw_setenv bootargs "root=/dev/mtdblock8 rootfstype=squashfs ro init=/linuxrc loglevel=3 LX_MEM=0x3FE0000 mma_heap=mma_heap_name0,miu=0,sz=0x2B0000 cma=2M highres=on mmap_reserved=fb,miu=0,sz=0x300000,max_start_off=0x3300000,max_end_off=0x3600000 mtdparts=nand0:1664k@0x140000(BOOT0),1664k(BOOT1),256k(ENV),256k(ENV1),128k(KEY_CUST),3m(KERNEL),3m(KERNEL_BAK),20m(rootfs),20m(rootfs_bak),1m(factory),1m(MISC),10m(RES),10m(RES_BAK),-(UBI)"
    else
        /etc/fw_setenv bootargs "root=/dev/mtdblock7 rootfstype=squashfs ro init=/linuxrc loglevel=3 LX_MEM=0x3FE0000 mma_heap=mma_heap_name0,miu=0,sz=0x2B0000 cma=2M highres=on mmap_reserved=fb,miu=0,sz=0x300000,max_start_off=0x3300000,max_end_off=0x3600000 mtdparts=nand0:1664k@0x140000(BOOT0),1664k(BOOT1),256k(ENV),256k(ENV1),128k(KEY_CUST),3m(KERNEL),3m(KERNEL_BAK),20m(rootfs),20m(rootfs_bak),1m(factory),1m(MISC),10m(RES),10m(RES_BAK),-(UBI)"
    fi
}

get_coor_file_ver() {
    ver=$(echo $1 | cut -d "_" -f 4)
    echo $ver
}

coordinator_ota() {
    # Update zigbee-coordinator firmware.
    echo "===Update zigbee-coordinator==="

    if [ ! -f "$zbcoor_bin_" ]; then
        echo "no co_ota file"
        return 0
    fi

    local zb_platform=$(agetprop persist.sys.zb_chip)
    local file_size=$(ls $zbcoor_bin_ -al | awk '{print $5}')

    local file_max_size=679936
    echo "filesize=$file_size"
    if [ $ZIGBEE_IC = "Ti2652" ] && [ $file_size -gt $file_max_size ]; then
        echo "error file size $file_size"
        return 0
    fi

    ## check ic
    # if [ "$zb_platform" != "$CC2652P7" ]; then
    #         red_echo "$zb_platform no support ota"
    #         return 0
    # fi

    # unpack
    # if [ "$zb_platform" = "" ]; then zb_platform="$CC2652P1"; fi
    green_echo "zb_coordinator: $zb_platform, coor_bin_name:$coor_bin_name"
    tar -xvf $zbcoor_bin_ -C $ota_dir_
    sync
    rm $zbcoor_bin_
    rm $coor_dir_/*

    if [ $ZIGBEE_IC = "MG21" ]; then
        green_echo "==2==zb_platform: $zb_platform, MG21"
        local ota_file=$(
            cd $ota_dir_
            ls Network-Co-Processor_115200_MG21*
            cd -
        )
        g_zbcoor_need_ver=$(get_coor_file_ver $ota_file)
        mv $ota_dir_/Network-Co-Processor_115200_MG21*.ota $coor_dir_/Network-Co-Processor.ota
        sync
    else
        if [ "$zb_platform" = "$CC2652P1" ]; then
            green_echo "==1==zb_platform: $zb_platform, CC2652P1:$CC2652P1"
            local ota_file=$(
                cd $ota_dir_
                ls Network-Co-Processor_115200_CC2652P1*
                cd -
            )
            mv $ota_dir_/Network-Co-Processor_115200_CC2652P1*.ota $coor_dir_/Network-Co-Processor.ota
            sync
            g_zbcoor_need_ver=$(get_coor_file_ver $ota_file)
        fi

        if [ "$zb_platform" = "$CC2652P7" ]; then
            green_echo "==2==zb_platform: $zb_platform, CC2652P7:$CC2652P7"
            local ota_file=$(
                cd $ota_dir_
                ls Network-Co-Processor_115200_CC2652P7*
                cd -
            )
            mv $ota_dir_/Network-Co-Processor_115200_CC2652P7*.ota $coor_dir_/Network-Co-Processor.ota
            sync
            g_zbcoor_need_ver=$(get_coor_file_ver $ota_file)
        fi

        if [ "$zb_platform" = "$CC1352P7" ]; then
            green_echo "==3==zb_platform: $zb_platform, CC1352P7:$CC1352P7"
            mv $ota_dir_/Network-Co-Processor_115200_CC1352P7*.ota $coor_dir_/Network-Co-Processor.ota
            sync
        fi
    fi

    local DFU_VER=$(agetprop persist.app.dfu_ver)
    local CLOUD_VER=$(echo $DFU_VER | cut -d '.' -f 4)
    local LOCAL_VER=$(agetprop persist.sys.zb_ver)

    coor_bin_="$coor_dir_/Network-Co-Processor.ota"
    coor_bin_bk_="/data/Network-Co-Processor.ota"

    if [ "$CLOUD_VER" != "$LOCAL_VER" ]; then
        if [ -f "$coor_bin_" ]; then
            cp -f "$coor_bin_" "$coor_bin_bk_"
            zigbee_msnger zgb_ota "$coor_bin_"
            echo "zigbee_msnger zgb_ota $coor_bin_"
            for retry in $(seq 28); do
                sleep 1
                # Check result
                confirm_coor
                var=$?
                if [ $var -eq 0 ]; then break; fi
            done

            if [ $var -eq 1 ]; then
                asetprop sys.dfu_progress -1
                return 1
            fi
            rm -f "$coor_bin_bk_"
        fi
    else
        echo "same coordinator ver"
    fi

    return 0
}
ota_kernel() {
    # Update kernel.
    echo "===Update kernel==="
    KERNEL_PARTITION=$(get_kernel_partitions)
    for cnt in $(seq 4); do
        if [ -f "$kernel_bin_" ]; then
            if [ "$KERNEL_PARTITION" = "KERNEL" ]; then
                flash_erase /dev/mtd6 0 0
                /bin/nandwrite -p /dev/mtd6 $kernel_bin_
                sync
                sleep 0.4
                /bin/nanddump -s 0x0 -l 0x1 -f /tmp/kernel_head -p /dev/mtd6
                cat /tmp/kernel_head | awk -F ':' '{print $2}' >>/tmp/kernel_head0
            else
                flash_erase /dev/mtd5 0 0
                /bin/nandwrite -p /dev/mtd5 $kernel_bin_
                sync
                sleep 0.4
                /bin/nanddump -s 0x0 -l 0x1 -f /tmp/kernel_head -p /dev/mtd5
                cat /tmp/kernel_head | awk -F ':' '{print $2}' >>/tmp/kernel_head0
            fi

            hexdump -n 2048 -e '16/1 "%02x" "\n"' $kernel_bin_ >>/tmp/kernel_head1
            result=$(diff -w /tmp/kernel_head0 /tmp/kernel_head1)
            rm -f /tmp/kernel_head0
            rm -f /tmp/kernel_head1
            rm -f /tmp/kernel_head
            if [ "$result" = "" ]; then break; fi

        fi
    done
    if [ $cnt -eq 4 ]; then return 1; fi
    return 0
}

ota_rootfs() {
    # Update rootfs.
    echo "===Update rootfs==="
    ROOTFS_PARTITION=$(get_rootfs_partitions)
    for cnt in $(seq 4); do
        if [ -f "$rootfs_bin_" ]; then
            if [ x"$ROOTFS_PARTITION" != x ]; then
                flash_erase /dev/mtd8 0 0
                /bin/nandwrite -p /dev/mtd8 $rootfs_bin_
                sync
                sleep 0.4
                /bin/nanddump -s 0x0 -l 0x1 -f /tmp/rootfs_head -p /dev/mtd8
                cat /tmp/rootfs_head | awk -F ':' '{print $2}' >>/tmp/rootfs_head0
            else
                flash_erase /dev/mtd7 0 0
                /bin/nandwrite -p /dev/mtd7 $rootfs_bin_
                sync
                sleep 0.4
                /bin/nanddump -s 0x0 -l 0x1 -f /tmp/rootfs_head -p /dev/mtd7
                cat /tmp/rootfs_head | awk -F ':' '{print $2}' >>/tmp/rootfs_head0
            fi
            hexdump -n 2048 -e '16/1 "%02x" "\n"' $rootfs_bin_ >>/tmp/rootfs_head1
            result=$(diff -w /tmp/rootfs_head0 /tmp/rootfs_head1)
            rm -f /tmp/rootfs_head0
            rm -f /tmp/rootfs_head1
            rm -f /tmp/rootfs_head
            if [ "$result" = "" ]; then break; fi
        fi
    done

    if [ $cnt -eq 4 ]; then return 1; fi

    return 0
}

ota_ir() {
    # Update IR-Controller firmware.
    echo "===Update IR-Controller==="
    if [ -f "$irctrl_bin_" ]; then
        if [ "$platform" = "miot" ]; then
            asetprop sys.app_monitor_delay 60
            killall mha_ir
            sleep 2
        fi

        cp $irctrl_bin_ $IRCTRL_BIN_BK_

        ir_ota ttyS3 115200 "$irctrl_bin_"
        # Check result
        update_block
        if [ $? -eq 1 ]; then
            echo "ota ir fail"
            return 1
        fi

        rm $IRCTRL_BIN_BK_
    fi

    return 0
}

get_ble_ver() {
    local path=$(basename $1)
    echo $(echo $path | cut -d '_' -f 4 | cut -d '.' -f 1)
}

ota_ble() {
    local ble_support=$(agetprop persist.sys.ble_supported)

    echo "****Update BLE support=$ble_support ****"
    if [ "$ble_support" != "true" ]; then
        red_echo "no support ble"
    else
        if [ ! -z $_ble_ota_bin ] && [ -f "$_ble_ota_bin" ]; then
            # todo kill ble app
            local ble_ver=$(get_ble_ver $_ble_ota_bin)
            echo "ble_ver=$ble_ver"

            ble_ota /dev/ttyS2 $_ble_ota_bin $ble_ver
            # Check result
            if [ $? -ne 0 ]; then
                red_echo "ota ble fail"
                return 1
            fi
        fi
    fi

    return 0
}

set_def_env() {
    /etc/fw_setenv mtdparts 'mtdparts=nand0:1664k@0x140000(BOOT0),1664k(BOOT1),256k(ENV),256k(ENV1),128k(KEY_CUST),3m(KERNEL),3m(KERNEL_BAK),20m(rootfs),20m(rootfs_bak),1m(factory),1m(MISC),10m(RES),10m(RES_BAK),-(UBI)'
    /etc/fw_setenv bootargs "root=/dev/mtdblock7 rootfstype=squashfs ro init=/linuxrc loglevel=3 LX_MEM=0x3FE0000 mma_heap=mma_heap_name0,miu=0,sz=0x2B0000 cma=2M highres=on mmap_reserved=fb,miu=0,sz=0x300000,max_start_off=0x3300000,max_end_off=0x3600000 mtdparts=nand0:1664k@0x140000(BOOT0),1664k(BOOT1),256k(ENV),256k(ENV1),128k(KEY_CUST),3m(KERNEL),3m(KERNEL_BAK),20m(rootfs),20m(rootfs_bak),1m(factory),1m(MISC),10m(RES),10m(RES_BAK),-(UBI)"
    /etc/fw_setenv bootcmd "nand read.e 0x22000000 KERNEL 0x2d0000; dcache on; st7701; bootlogo 0 0 0 0; pwm 0 200000 200000 14; bootm 0x22000000;nand read.e 0x22000000 KERNEL_BAK 0x2d0000; dcache on; bootm 0x22000000"
}

check_env() {
    local err_crc=$(/etc/fw_printenv 2>&1 | grep "Bad CRC")
    if [ x"$err_crc" != x ]; then
        red_echo "last env error,set default env"
        set_def_env
    else
        echo "env right"
    fi
}

update_start() {
    local platform="$1"
    local coor_bin_name=$(echo $ota_dir_/*.ota | cut -d '/' -f 4)

    zbcoor_bin_="$ota_dir_/Network-Co-Processor.ota"
    zbcoor_bin_bk_="/data/Network-Co-Processor.ota"
    _ble_ota_bin=$(find $ota_dir_ -name ble_*)
    echo "ble ota file:$_ble_ota_bin"

    check_env

    asetprop sys.dfu_progress 80

    ota_kernel
    if [ $? -eq 1 ]; then
        echo "kernel ota fail"
        return 1
    fi

    asetprop sys.dfu_progress 95

    ota_rootfs

    if [ $? -eq 1 ]; then
        echo "rootfs ota fail"
        return 1
    fi

    echo "===Update ALL Success==="

    return 0
}

update_failed() {
    local platform="$1"
    local errmsg="$2"
    local clean="$3"

    green_echo "Update failed, reason: $errmsg"

    if [ "$clean" = "true" ]; then update_clean; fi

    if [ "$platform" = "miot" ]; then
        asetprop sys.dfu_progress -33005
    else asetprop sys.dfu_progress -1; fi
}

update_done() {
    set_kernel_partitions "$KERNEL_PARTITION"
    set_rootfs_partitions "$ROOTFS_PARTITION"
    update_clean

    asetprop sys.dfu_progress 100

    sleep 1
    killall gui_monitor.sh
    killall aqgui
    killall sysservice

    sleep 6
#    reboot
    green_echo ""
    green_echo "Update Done, Please manually reboot!"
}

#
# Document helper.
#
helper() {
    local cmd="$1"

    case $cmd in
    -r) usage_runner ;;

    -s) usage_switcher ;;

    -f) usage_factory ;;

    -u) usage_updater ;;

    -t) usage_tester ;;

    *) usage_helper ;;
    esac

    return 0
}

#
# Run user programs.
#
runner() {
    local opt="$1"

    run_prepare

    case $opt in
    -a) run_aiot ;;

    -m) run_miot ;;

    *) run_xxxx ;;
    esac

    return 0
}

#
# Switch platform.
#
switcher() {
    echo "no support switcher"
    return 1
    local opt="$1"

    local platform=$(agetprop persist.sys.cloud)

    case $opt in
    -a) switch2_aiot "$platform" ;;

    -m) switch2_miot "$platform" ;;

    *) switch2_xxxx "$platform" ;;
    esac

    return 0
}

#
# Factory operations.
#
factory() {
    local opt="$1"

    case $opt in
    -r) factory_reset ;;

    -m) factory_test ;;

    *) green_echo "Lost params." ;;
    esac

    return 0
}

#
# Update firmware.
#
updater() {
    local sign="0"
    local path="/tmp/fw.tar.gz"

    # Check file existed or not.
    if [ ! -e "/tmp/curl" ]; then update_failed "$platform" "/tmp/curl not found!"; return 1; fi

    # Need check sign?
    if [ "$2" = "-s" ]; then sign="1"; fi

    local platform=$(agetprop persist.sys.cloud)
    if [ "$platform" = "" ]; then platform=$DEFAULT_PLATFORM; fi

    green_echo "platform: $platform, path: $path, sign: $sign"

    # Prepare...
    update_prepare "$path"
    if [ $? -ne 0 ]; then
        update_failed "$platform" "Not enough storage available!"
        return 1
    fi

    # Get DFU package and check it.
    update_get_packages "$platform" "$path" "$sign"
    if [ $? -ne 0 ]; then
        update_failed "$platform" "getpack failed!" "true"
        return 1
    fi

    update_before_start "$platform"

    update_start "$platform"
    if [ $? -eq 0 ]; then
        update_done
    else update_failed "$platform" "OTA failed!" "true"; fi

    return 0
}

#
# Get product model.
#
info_model() {
    # Try: Get by attribute: persist.sys.model.
    for i in 1 2 1 0; do
        local userattr=$(agetprop persist.sys.model)
        if [ ! -n "$userattr" ]; then
            sleep $i
            continue
        fi

        if [ ! -f "$MODEL_FILE" ]; then set_tags "$MODEL_FILE" "$userattr"; fi

        echo "$userattr"
        return
    done

    # Try: Get from file.
    if [ -f "$MODEL_FILE" ]; then
        local fileattr=$(cat $MODEL_FILE)
        echo "$fileattr"
        return
    fi

    # Try: Get by attribute: ro.sys.model.
    local sysattr=$(agetprop ro.sys.model)
    echo "$sysattr"
}

#
# Initial params.
#
initial() {
    # wait_property_svr_ok

    local exit_flag=1

    # Is another script running?
    for i in 2 3 1 0; do
        local info=$(ps)
        local this_num=$(echo "$info" | grep "$1" | wc -l)

        if [ $this_num -le 1 ]; then
            exit_flag=0
            break
        fi

        sleep $i # Waitting...
    done

    if [ $exit_flag -ne 0 ]; then exit 1; fi

    green_echo "$1 revision: $REVISION"

    # Compatible by revision.
    # compatible

    # Set ipv4 local reserved ports.
    echo "1883,54322" >/proc/sys/net/ipv4/ip_local_reserved_ports
    product=$(agetprop ro.sys.model)

    model="AH_S1E"

    sync

    green_echo "type: $product, model: $model"
}

#
# Main function.
#
main() {
    wait_property_svr_ok
    initial ${0##*/}
    # if the bak file exit , upgrade the ir fw
    if [ -f "$IRCTRL_BIN_BK_" ]; then
        ir_ota ttyS3 115200 "$IRCTRL_BIN_BK_"
        update_block
        if [ $? -eq 0 ]; then rm $IRCTRL_BIN_BK_; fi
    fi

    if [ -f $_ble_ota_bak_file ]; then
        local ble_ver=$(get_ble_ver $_ble_ota_bak_file)
        echo "ble_ver=$ble_ver"

        ble_ota /dev/ttyS2 $_ble_ota_bak_file $ble_ver
        if [ $? -eq 0 ]; then
            echo "ota ble bak file ok"
            rm $_ble_ota_bak_file
        fi
    fi

    local option="$1"

    case $option in
    -h)
        local cmd="$2"
        helper $cmd
        ;;

    -u|*) updater $* ;;

    *)
        green_echo ""
        green_echo "Usage: $0 [option] [params]."
        green_echo "  option: $OPTIONS"
        green_echo "  params: params list."
        return 1
        ;;
    esac

    return $?
}

#
# Run script.
#
main $*
exit $?
