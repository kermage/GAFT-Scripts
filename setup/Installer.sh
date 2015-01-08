#!/system/bin/sh

#      ,#####    ###    ,#############
#     ###  `##  ## ##   ###      ##
#    ,##       ##   ##  ######   ##
#    ### ##### ######## #####'  ,##
#    ###   ######   `#####      ###
#    `#########'      ####     ####
#
# | kermage | PrivaTech -- GAFT | iMUT |
# Copyright 2014 Gene Alyson F. Torcende
# Email: genealyson.torcende@gmail.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# All rights reserved.

# The script includes:
# - Version checking // skips install if newer or equal version is present
# - BusyBox Installer
# - GAFT's init.d Enabler
# --- Checks init.d required commands at all possible hooks (ramdisk .rc files,
#     /system/bin/sysinit, and /system/etc/install-recovery.sh). If no required
#     commands found, hook init.d run-parts to /system/etc/install-recovery.sh.
# - GAFT's Prop Tweaker
# --- Only adds the build.prop entry if not yet existed and not set to the preferred value.
# --- Existing entries with different set value is commented out with #GAFT# first.
# - Setting up GAFT files and required binaries.


###    DO NOT CHANGE anything below    ###
### unless you know what you are doing ###
VERSION=1.00.101214
GAFT=/data/GAFT
alias BUSYBOX='${0%/*}/busybox'     # Use included busybox
LOG_FILE=$GAFT/Install.log          # Log location

# Current Directory
DIR=$(cd "$(BUSYBOX dirname "$0")" && pwd)
# Root Check
uid=`id -u` && uid=${uid%%\(*}
if [ "$uid" -ne "uid=0" ]; then
  # If not run as root
  echo -e "\nError: $( date +"%m-%d-%Y %H:%M:%S" )"
  echo " - ${0##*/} must be run as root"
  exit 1
fi
# Version Check
CURRVER=0`grep VERSION $GAFT/Settings | BUSYBOX sed 's/.*=//'`

[ ! -e $GAFT ] && mkdir $GAFT        # Create GAFT working dir
[ -e $LOG_FILE ] && rm $LOG_FILE     # Remove existing log

clear
echo "" | BUSYBOX tee -a $LOG_FILE
echo "  ######################################## " | BUSYBOX tee -a $LOG_FILE
echo " #                                        #" | BUSYBOX tee -a $LOG_FILE
echo " #        GAFT Scripts $VERSION        #" | BUSYBOX tee -a $LOG_FILE
echo " # | kermage | PrivaTech -- GAFT | iMUT | #" | BUSYBOX tee -a $LOG_FILE
echo " # Copyright 2014 Gene Alyson F. Torcende #" | BUSYBOX tee -a $LOG_FILE
echo " #  Email: genealyson.torcende@gmail.com  #" | BUSYBOX tee -a $LOG_FILE
echo " #                                        #" | BUSYBOX tee -a $LOG_FILE
echo "  ######################################## " | BUSYBOX tee -a $LOG_FILE
echo "" | BUSYBOX tee -a $LOG_FILE

if [ ${VERSION//.} -le ${CURRVER//.} ]; then
  # Newer of equal version present
  echo -e "\nError: $( date +"%m-%d-%Y %H:%M:%S" )" | BUSYBOX tee -a $LOG_FILE
  echo " - GAFT Scripts already installed" | BUSYBOX tee -a $LOG_FILE
  echo "     (Installed: v${CURRVER:1})" | BUSYBOX tee -a $LOG_FILE
  exit 1
fi

# Check default /system mount
DEFMNT=`mount | grep /system | BUSYBOX awk '{print $4}' | BUSYBOX cut -d ',' -f1`
# If read-only, remount /system to read&write first
[ $DEFMNT == "ro" ] && BUSYBOX mount -o remount,rw /system
cp -fr $DIR/GAFT /data          # Copy GAFT files

if [ ${CURRVER//.} -eq "0" ]; then
  # No existing installation
  echo " - Installing GAFT Scripts" | BUSYBOX tee -a $LOG_FILE
  echo "     (Version: $VERSION)" | BUSYBOX tee -a $LOG_FILE
elif [ ${VERSION//.} -gt ${CURRVER//.} ]; then
  # Installer version is newer
  echo " - Updating GAFT Scripts" | BUSYBOX tee -a $LOG_FILE
  echo "     (Installed: v${CURRVER:1})" | BUSYBOX tee -a $LOG_FILE
fi

# BusyBox Install
GAFT_BBINS() {
  cp -f $DIR/busybox /system/xbin/busybox            # Copy to /system/xbin
  chmod 755 /system/xbin/busybox                     # Add permissions
  ln -s /system/xbin/busybox /system/bin/busybox     # Syslink to /system/bin
  BUSYBOX --install -s /system/xbin                  # Install to /system/xbin
}

echo " - Check for BusyBox" | BUSYBOX tee -a $LOG_FILE
BBIVER=`BUSYBOX | BUSYBOX awk 'NR==1{print $2}'`     # Included version
if [ -L /system/bin/busybox ] && [ -e /system/xbin/busybox ]; then
  # BusyBox exist in /system, check further
  BBNAME=`busybox | awk 'NR==1{print $1}'`
  BBCVER=`busybox | awk 'NR==1{print $2}'`     # Current version
  if [ "`busybox --help`" ] && [ "$BBNAME" -eq "BusyBox" ]; then
    # Installed BusyBox is okay, check version
    if [ "$BBIVER" \< "$BBCVER" ] || [ "$BBIVER" == "$BBCVER" ]; then
      # Newer of equal version present
      echo "     $BBNAME $BBCVER already installed"
    else
      # Installer version is newer
      echo "     Updating $BBNAME to $BBIVER"
      GAFT_BBINS
    fi
  else
    # Something is wrong, force install
    echo "     Re-installing BusyBox $BBIVER"
    GAFT_BBINS
  fi
else
  echo "     Installing BusyBox $BBIVER"
  GAFT_BBINS
fi

# init.d Enabler
GAFT_INIT() {
  if [ ! -e $IRSH.GAFT ]; then
    # Create backup if not exist
    cp -f $IRSH $IRSH.GAFT
    echo " - Backup working install-recovery.sh" | BUSYBOX tee -a $LOG_FILE
    echo "     $IRSH.GAFT" | BUSYBOX tee -a $LOG_FILE
  fi
  echo -e "\n\n# init.d Enabler" >> $IRSH
  echo -e "# By GAFT (c)2014\n" >> $IRSH
  # Hook init.d run-parts to /system/etc/install-recovery.sh
  echo "busybox run-parts $INIT" >> $IRSH
  echo " - GAFT enabled init.d support" | BUSYBOX tee -a $LOG_FILE
  echo "     Hooked to $IRSH" | BUSYBOX tee -a $LOG_FILE
}

INIT=/system/etc/init.d
RMRC=/*.rc
SYSI=/system/bin/sysinit
IRSH=/system/etc/install-recovery.sh
# Check ROM init.d support
for CHECK in $RMRC $SYSI $IRSH; do
  # ramdisk .rc files, sysinit, and install-recovery.sh
  if [ -e $CHECK ] && [ "`grep run-parts $CHECK`" ]; then
    # Add to checked list if required command found
    INIT_CHECK="$INIT_CHECK $CHECK"
  fi
done
if [ $DIR == "/tmp" ]; then   # If run in recovery mode
  echo " - ROM not fully verified to support init.d" | BUSYBOX tee -a $LOG_FILE
  echo "     Recovery mode (Flash)" | BUSYBOX tee -a $LOG_FILE
  echo "     Cannot check at ramdisk .rc files" | BUSYBOX tee -a $LOG_FILE
else     # Else in manual mode //checked at all possible hooks
  if [ -z $INIT_CHECK ]; then     # If no init.d required commands found
    echo " - ROM does not support init.d scripts" | BUSYBOX tee -a $LOG_FILE
    echo "     Checked at all possible hooks" | BUSYBOX tee -a $LOG_FILE
    GAFT_INIT
  else     # If init.d required commands found
    echo " - Verified ROM support init.d scripts" | BUSYBOX tee -a $LOG_FILE
    echo "     Found at $INIT_CHECK" | BUSYBOX tee -a $LOG_FILE
    if [ "${INIT_CHECK///}" == " ${IRSH///}" ] && [ "`grep "# By GAFT (c)2014" $IRSH`" ]; then
      echo "     GAFT enabled init.d support" | BUSYBOX tee -a $LOG_FILE
    fi
  fi
fi
if [ -e $INIT ]; then    # If init.d folder exist
  echo " - $INIT found!" | BUSYBOX tee -a $LOG_FILE
  if [ $DIR == "/tmp" ]; then   # If run in recovery mode
    echo "     Probably ROM supports init.d" | BUSYBOX tee -a $LOG_FILE
  fi
  if [ "$(ls $INIT/* 2>&-)" ] && [ ! -e $INIT.GAFT ]; then
  # If init.d is not empty, and no backup
  echo " - Backup current init.d folder" | BUSYBOX tee -a $LOG_FILE
  echo "     $INIT.GAFT" | BUSYBOX tee -a $LOG_FILE
  mv $INIT $INIT.GAFT
  chmod -R 000 $INIT.GAFT     # Remove permissions
  mkdir $INIT                 # Create clean init.d folder
  fi
else     # If init.d folder not exist
  echo " - $INIT NOT found!" | BUSYBOX tee -a $LOG_FILE
  if [ $DIR == "/tmp" ]; then   # If run in recovery mode
    echo "     Probably ROM didn't support init.d" | BUSYBOX tee -a $LOG_FILE
    GAFT_INIT
  fi
  echo " - Create clean and fresh init.d" | BUSYBOX tee -a $LOG_FILE
  mkdir $INIT
fi

echo " - Setup GAFT files and required binaries" | BUSYBOX tee -a $LOG_FILE
if [ "$(ls $INIT/*GAFT_* 2>&-)" ]; then
  rm -f $GAFT/logs/*.log 2>&-
  rm -f $INIT/*GAFT_* 2>&-
  echo "     Removed: Old GAFT init.d scripts" | BUSYBOX tee -a $LOG_FILE
fi
chmod -R 777 $GAFT/init.d
chmod -R 644 $GAFT/logs
cp -f $DIR/busybox $GAFT/bin/busybox
chmod 755 $GAFT/bin/busybox
chmod 644 $GAFT/bin/libncurses.so18
chmod 644 $GAFT/bin/libncurses.so19
chmod 755 $GAFT/bin/rngd
chmod 755 $GAFT/bin/sqlite318
chmod 755 $GAFT/bin/sqlite319
chmod 777 $GAFT/bin/zipalign18
chmod 777 $GAFT/bin/zipalign19
echo "     Installed: $GAFT" | BUSYBOX tee -a $LOG_FILE
[ ! -L /system/xbin/GAFT ] && ln -s $GAFT/Console /system/xbin/GAFT
chmod 755 $GAFT/Console
chmod 755 /system/xbin/GAFT
echo "     Syslinked: GAFT init.d Console" | BUSYBOX tee -a $LOG_FILE
cp -f $DIR/zZGAFT_init $INIT
chmod 777 $INIT/zZGAFT_init
echo "     Installed: $INIT/zZGAFT_init" | BUSYBOX tee -a $LOG_FILE

# Prop Tweaker
GAFT_PROP() {
  # $1: Entry     $2: Value
  if [ "`grep "$1" $PROP`" ]; then          # If entry found
    if [ "`grep "$1=$2" $PROP`" ]; then     # Entry okay
      echo "     Skipped: $1=$2" | BUSYBOX tee -a $LOG_FILE
    else
      # Comment out the existing entry not set to the preferred value
      BUSYBOX sed -i "/^$1/{ h; s/^$1\(.*\)/#GAFT# $1\1/ };" $PROP;
      # Add the build.prop entry with the preferred value
      echo $1=$2 >> $PROP;
      echo "     Updated: $1=$2" | BUSYBOX tee -a $LOG_FILE
    fi
  else
    echo $1=$2 >> $PROP;     # Add not found entry
    echo "     Added: $1=$2" | BUSYBOX tee -a $LOG_FILE
  fi
}

PROP=/system/build.prop
if [ ! -e $PROP.GAFT ]; then
  cp -f $PROP $PROP.GAFT     # Create backup if not exist
  echo " - Backup working build.prop" | BUSYBOX tee -a $LOG_FILE
  echo "     $PROP.GAFT" | BUSYBOX tee -a $LOG_FILE
fi
echo " - GAFT build.prop Tweaks" | BUSYBOX tee -a $LOG_FILE
if [ ! "`grep "# By GAFT (c)2014" $PROP`" ]; then
  echo -e "\n\n# Extra Tweaks" >> $PROP
  echo -e "# By GAFT (c)2014\n" >> $PROP
fi
GAFT_PROP "dalvik.vm.dexopt-flags" "m=y"
GAFT_PROP "persist.adb.notify" "0"
GAFT_PROP "pm.sleep_mode" "1"
GAFT_PROP "wifi.supplicant_scan_interval" "180"
GAFT_PROP "net.dns1" "8.8.8.8"
GAFT_PROP "net.dns2" "8.8.4.4"
GAFT_PROP "net.ppp0.dns1" "8.8.8.8"
GAFT_PROP "net.ppp0.dns2" "8.8.4.4"
GAFT_PROP "net.rmnet0.dns1" "8.8.8.8"
GAFT_PROP "net.rmnet0.dns2" "8.8.4.4"
GAFT_PROP "net.tcp.buffersize.default" "4096,87380,524288,4096,16384,524288"
GAFT_PROP "net.tcp.buffersize.edge" "4096,87380,524288,4096,16384,524288"
GAFT_PROP "net.tcp.buffersize.gprs" "4096,87380,524288,4096,16384,524288"
GAFT_PROP "net.tcp.buffersize.hsdpa" "4096,87380,524288,4096,16384,524288"
GAFT_PROP "net.tcp.buffersize.hspa" "4096,87380,524288,4096,16384,524288"
GAFT_PROP "net.tcp.buffersize.hspap" "4096,87380,1220608,4096,16384,1220608"
GAFT_PROP "net.tcp.buffersize.hsupa" "4096,87380,524288,4096,16384,524288"
GAFT_PROP "net.tcp.buffersize.lte" "524288,1048576,2097152,262144,524288,1048576"
GAFT_PROP "net.tcp.buffersize.umts" "4096,87380,524288,4096,16384,524288"
GAFT_PROP "net.tcp.buffersize.wifi" "524288,1048576,2097152,262144,524288,1048576"
GAFT_PROP "ro.ril.enable.a52" "0"
GAFT_PROP "ro.ril.enable.a53" "1"
GAFT_PROP "ro.ril.enable.dtm" "1"
GAFT_PROP "ro.ril.enable.gea3" "1"
GAFT_PROP "ro.ril.gprsclass" "12"
GAFT_PROP "ro.ril.hep" "1"
GAFT_PROP "ro.ril.hsdpa.category" "8"
GAFT_PROP "ro.ril.hsupa.category" "9"
GAFT_PROP "ro.ril.hsxpa" "2"
chmod 644 $PROP

BUSYBOX sed -i '/^VERSION/s/=.*/='$VERSION'/' $GAFT/Settings
# If default is read-only, remount /system back to default
[ $DEFMNT == "ro" ] && mount -o remount,ro /system

echo "" | BUSYBOX tee -a $LOG_FILE
echo "  ######################################## " | BUSYBOX tee -a $LOG_FILE
echo " #                                        #" | BUSYBOX tee -a $LOG_FILE
echo " #          FLASHED AT OWN RISK!          #" | BUSYBOX tee -a $LOG_FILE
echo " #      Absolutely no guarantees. :P      #" | BUSYBOX tee -a $LOG_FILE
echo " #       Reboot your device now ...       #" | BUSYBOX tee -a $LOG_FILE
echo " #                                        #" | BUSYBOX tee -a $LOG_FILE
echo "  ######################################## " | BUSYBOX tee -a $LOG_FILE
