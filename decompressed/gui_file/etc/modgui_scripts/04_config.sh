. /etc/init.d/rootdevice

check_webui_config() {
  if [ -f /tmp/web_unlock ]; then
    if [ ! "$(uci get -q web.changelog)" ] || [ ! "$(uci get -q web.mmpbxstatisticsmodal)" ]; then
      mv /etc/config/web /etc/config/web_back #backup of the stock web config
      mv /tmp/web_unlock /etc/config/web      #apply unlocked universal config
    else
      rm /tmp/web_unlock
    fi
  fi
  if [ "$(uci get -q wireless.global.wifi_analyzer_disable)" ]; then
    if [ "$(uci get -q wireless.global.wifi_analyzer_disable)" != "0" ]; then
      uci set wireless.global.wifi_analyzer_disable='0'
    fi
  fi
}

check_variant_friendly_name() {
  #Get variant friendly name and save
  if [ ! "$(uci get -q env.var.variant_friendly_name)" ]; then
    variant=$(uci get env.var.prod_friendly_name)
    case "$variant" in

    DGA4130)
      variant=AGTEF
      ;;
    DGA4132)
      variant=AGTHP
      ;;
    Technicolor*)
      variant=${variant#Technicolor }
      ;;
    MediaAccess*)
      variant=${variant#MediaAccess }
      ;;
    esac
    uci set env.var.variant_friendly_name="$variant"
  fi
}

orig_config_gen() {
  if [ ! -f /etc/config/wol ]; then
    touch /etc/config/wol
    uci set wol.config=wol
    uci set wol.config.enabled='0'
    uci set wol.config.src_intf='wan'
    uci set wol.config.src_dport='9'
    uci set wol.config.dest_port='9'
    uci set wol.config.dest_intf='br-lan'
    uci set wol.config.dest_ip='192.168.1.253'
    uci commit wol
  fi
  if [ ! -f /etc/config/fcctlsettings ]; then
    touch /etc/config/fcctlsettings
    uci set fcctlsettings.state=state
    uci set fcctlsettings.state.enabled='1'
    uci set fcctlsettings.option=option
    uci set fcctlsettings.option.l2tp='1'
    uci set fcctlsettings.option.gre='1'
    uci set fcctlsettings.option.ipv6='1'
    uci set fcctlsettings.option.mcast='1'
    uci set fcctlsettings.option.mcast_learn='1'
    uci commit fcctlsettings
  fi
}

check_uci_gui_skin() {
  if [ ! "$(uci get -q modgui.gui.gui_skin)" ]; then
    uci set modgui.gui.gui_skin="green"
  fi
}

remove_https_check_cwmpd() {
  uci set cwmpd.cwmpd_config.enforce_https='0'
  uci set cwmpd.cwmpd_config.ssl_verifypeer='0'
}

create_driver_setting() {
  #Get xdsl driver(s) version and save to GUI config file
  if [ ! "$(uci get -q modgui.var.driver_version)" ]; then
    uci set modgui.var.driver_version="$(xdslctl --version 2>&1 >/dev/null | grep 'version -' | awk '{print $6}' | sed 's/\..*//')"
  else
    if [ "$(uci get -q modgui.var.driver_version | grep -F .)" ]; then
      uci set modgui.var.driver_version="$(xdslctl --version 2>&1 >/dev/null | grep 'version -' | awk '{print $6}' | sed 's/\..*//')"
    fi
  fi
}

dropbear_config_check() {
  if [ ! "$(uci get -q dropbear.wan)" ]; then
    logger_command "Adding Dropbear wan config"
    uci set dropbear.wan=dropbear
    uci set dropbear.wan.Interface='wan'
    uci set dropbear.wan.RootLogin='1'
    uci set dropbear.wan.RootPasswordAuth='on' #dropbear root related
    uci set dropbear.wan.PasswordAuth='on'
    uci set dropbear.wan.Port='22'
    uci set dropbear.wan.enable='0'

    uci commit dropbear
  else
    if [ "$(uci get -q dropbear.wan.RootLogin)" != "1" ]; then
      logger_command "Enabling Dropbear wan RootLogin"
      uci set dropbear.wan.RootLogin='1'
      uci commit dropbear
    fi
    if [ "$(uci get -q dropbear.wan.PasswordAuth)" != "on" ]; then #TELMEX firmware got it OFF
      logger_command "Enabling Dropbear wan PasswordAuth"
      uci set dropbear.wan.PasswordAuth='on'
      uci commit dropbear
    fi
    if [ "$(uci get -q dropbear.wan.RootPasswordAuth)" != "on" ]; then #TELMEX firmware got it OFF
      logger_command "Enabling Dropbear wan RootPasswordAuth"
      uci set dropbear.wan.RootPasswordAuth='on'
      uci commit dropbear
    fi
  fi
}

eco_param() {
  #Set CPU to full power (full clock)
  if [ ! "$(uci get -q power.cpu)" ]; then
    uci set power.cpu=cpu
    uci set power.cpu.cpuspeed='256'
    uci set power.cpu.wait='1'
    logger_command "Restarting power management"
    /etc/init.d/power restart
  fi
}

create_gui_type() {
  #Gathers various infomation about what programs are installed and saves it in the modgui config file
  if [ ! "$(uci get -q modgui.app.aria2_webui)" ]; then
    if [ -d /www/docroot/aria ]; then
      uci set modgui.app.aria2_webui="1"
    else
      uci set modgui.app.aria2_webui="0"
    fi
  fi
  if [ ! "$(uci get -q modgui.app.luci_webui)" ]; then
    if [ -d /www_luci ]; then
      uci set modgui.app.luci_webui="1"
    else
      uci set modgui.app.luci_webui="0"
    fi
  fi
  if [ ! "$(uci get -q modgui.app.amule_webui)" ]; then
    if [ -d /www/docroot/amule ]; then
      uci set modgui.app.amule_webui="1"
    else
      uci set modgui.app.amule_webui="0"
    fi
  fi
  if [ ! "$(uci get -q modgui.app.transmission_webui)" ]; then
    if [ -d /www/docroot/transmission ]; then
      uci set modgui.app.transmission_webui="1"
    else
      uci set modgui.app.transmission_webui="0"
    fi
  fi
  if [ ! "$(uci get -q modgui.app.xupnp_app)" ]; then
    if [ -d /usr/share/xupnpd ]; then
      uci set modgui.app.xupnp_app="1"
    else
      uci set modgui.app.xupnp_app="0"
    fi
  fi
  if [ ! "$(uci get -q modgui.app.blacklist_app)" ]; then
    if [ -d /etc/asterisk ]; then
      uci set modgui.app.blacklist_app="1"
    else
      uci set modgui.app.blacklist_app="0"
    fi
  elif [ "$(uci get -q modgui.app.blacklist_app)" == "1" ] &&
    [ ! -f /www/docroot/modals/mmpbx-contacts-modal.lp.orig ] &&
    [ -f /usr/share/transformer/scripts/appInstallRemoveUtility.sh ]; then
    /usr/share/transformer/scripts/appInstallRemoveUtility.sh install blacklist
  fi
}

add_new_web_rule() {
  /usr/share/transformer/scripts/unlock_and_refresh_web_config.lua
}

check_relay_dhcp() {
  #Check if dhcp relay is enabled
  if [ ! "$(uci get -q dhcp.relay)" ]; then
    uci set dhcp.relay=relay
  fi
}

suppress_excessive_logging() {
  #Lowers the log level of daemons to suppress excessive logging to /root/messages.log
  if [ "$(uci get -q igmpproxy.globals.trace)" == "1" ]; then
    logger_command "Suppressing igmpproxy logs"
    uci set igmpproxy.globals.trace='0'
  fi

  logger_command "Triggering mobiled restart"
  /etc/init.d/mobiled restart #Restart this to actually disable it... (broken and shitt init.d)

  if [ "$(uci get -q mmpbx.global.trace_level)" != "3" ]; then
    logger_command "Suppressing wansensing logs"
    uci set wansensing.global.tracelevel='3' #we don't need that we are still connected to vdsl -.-
  fi
  if [ ! "$(uci get -q transformer.@main[0].log_level)" ]; then #shutup no description warn
    logger_command "Setting transformer log level to 2"
    uci set transformer.@main[0].log_level='2'
  fi
  if [ ! "$(uci get -q system.@system[0].cronloglevel)" ] || [ "$(uci get -q system.@system[0].cronloglevel)" == '0' ]; then #resolve spamlog of trafficdata
    logger_command "Setting cron log level to 5"
    uci set system.@system[0].cronloglevel="5"
    /etc/init.d/cron restart
  fi
  if [ ! "$(uci get -q ledfw.syslog)" ]; then #suppress loggin of ledfw... we don't need it...
    logger_command "Suppressing syslog (avoid ledfw spam)"
    uci set ledfw.syslog=syslog
    uci set ledfw.syslog.trace='0'
  fi
  if [ "$(uci get -q mmpbx.global.trace_level)" == "2" ]; then
    logger_command "Suppressing mmpbx logs"
    uci set mmpbx.global.trace_level='0'
  fi
}

real_ver_entitied() {
  if [ -f /rom/etc/uci-defaults/tch_5000_versioncusto ] && [ -f /etc/config/versioncusto ]; then
    local short_ver="$(grep </proc/banktable/activeversion -Eo '.*\..*\.[0-9]*-[0-9]*')"
    local real_ver=$(grep </rom/etc/uci-defaults/tch_5000_versioncusto "$short_ver" | awk '{print $2}')
    uci set versioncusto.override.fwversion_override_latest="$latest_version_on_TIM_cwmp"
    if [ "$real_ver" == "" ]; then
      real_ver="Not Found"
    fi
    if [ ! "$(uci get -q versioncusto.override.fwversion_override_real)" ]; then
      uci set versioncusto.override.fwversion_override_real="$real_ver"
    elif [ "$(uci get -q versioncusto.override.fwversion_override_real)" != "$real_ver" ]; then
      uci set versioncusto.override.fwversion_override_real="$real_ver"
    fi
    if [ "$(uci get -q modgui.var.skip_version_spoof)" ]; then
      uci del modgui.var.skip_version_spoof
    fi
    #Set version to latest stable...
    if [ -f /overlay/.skip_version_spoof ]; then
      uci set modgui.var.version_spoof_mode="disabled"
      uci set versioncusto.override.fwversion_override="$real_ver"
      rm /overlay/.skip_version_spoof
    else
      if [ "$(uci get -q modgui.var.version_spoof_mode)" ]; then
        if [ "$(uci get -q modgui.var.version_spoof_mode)" == "enabled" ]; then
          uci set versioncusto.override.fwversion_override="$latest_version_on_TIM_cwmp"
        elif [ "$(uci get -q modgui.var.version_spoof_mode)" == "disabled" ]; then
          uci set versioncusto.override.fwversion_override="$real_ver"
        fi
      else
        uci set modgui.var.version_spoof_mode="enabled"
        uci set versioncusto.override.fwversion_override="$latest_version_on_TIM_cwmp"
      fi
    fi
    uci commit modgui
  fi
}

new_wol_implementation() {
  #Enable WoL
  if [ -f /lib/functions/firewall-wol.sh ]; then
    rm /lib/functions/firewall-wol.sh
    uci set wol.config.dest_port=9
    /etc/init.d/wol restart
  fi
}

add_xdsl_option() {
  if [ ! "$(uci get -q xdsl.dsl0.sra)" ]; then
    uci set xdsl.dsl0.sra=1
  fi
  if [ ! "$(uci get -q xdsl.dsl0.bitswap)" ]; then
    uci set xdsl.dsl0.bitswap=1
  fi
  if [ ! "$(uci get -q xdsl.dsl0.snr)" ]; then
    uci set xdsl.dsl0.snr=0
  fi
  # Trying to understanding why this option were not applied i found that this option was the culprit
  # So this hex code means something... i found that the first bit is related to sra (>5 activate sra)
  # The third is related to bitswap (>2) enables it
  # demod_cap2_value (default 0x390000)
  # setting them to 0x000000 disable  sesdrop (second bit <6) CoMinMgn (first bit >1) 24k (first bit 1)
  uci set xdsl.dsl0.demod_cap_mask="0x00047a"
  uci set xdsl.dsl0.demod_cap_value="0x00047a"
}

check_wan_mode() {
  if [ ! "$(uci get -q network.config.wan_mode)" ]; then
    uci set network.config="config"
    uci set network.config.wan_mode="$(uci get -q network.wan.proto)"
  fi
}

dosprotect_inizialize() {
  logger_command "Checking DoSprotect kernel modules..."
  if [ -n "$(find /lib/modules/*/ -iname xt_hashlimit.ko)" ]; then
    if [ ! -f /etc/config/dosprotect ]; then
      if [ -f /tmp/dosprotect_orig ]; then
        mv /tmp/dosprotect_orig /etc/config/dosprotect
      fi
    fi
    [ -f /tmp/dosprotect_orig ] && rm /tmp/dosprotect_orig
    if [ -n "$(find /etc/rc.d/ -iname S*dosprotect)" ]; then
      logger_command "Enabling and starting DoSprotect service..."
      /etc/init.d/dosprotect enable
      /etc/init.d/dosprotect start
    fi
  fi
}

disable_intercept() {
  if [ "$(uci get -q intercept.config.enabled)" ]; then
    if [ "$(uci get -q intercept.config.enabled)" == "1" ]; then
      uci set intercept.config.enabled='0'
      uci commit intercept
      /etc/init.d/intercept restart
    fi
  fi
}

restore_nginx() {
  #This file contain settings specific for gui
  #For example
  #client_max_body_size
  if [ ! -f /etc/nginx/ui_server.conf ]; then
    #Execute defualt script to set this value
    /rom/etc/uci-defaults/tch_0080-nginx
  fi
}

adds_dnd_config() {
  if [ -z "$(uci get -q tod.voicednd)" ]; then
    uci set tod.voicednd=tod
    uci set tod.voicednd.ringing='off'
    uci set tod.voicednd.timerandactionmodified='0'
    uci set tod.voicednd.enabled='1'
    uci commit tod
  fi
}

move_gui_to_root() {
  if [ -f /tmp/GUI.tar.bz2 ]; then
    logger_command "Updating GUI in /root folder from /tmp"
    if [ -f /root/GUI.tar.bz2 ]; then
      rm /root/GUI.tar.bz2
    fi
    mv /tmp/GUI.tar.bz2 /root/GUI.tar.bz2
  fi
}

cumulative_check_gui() {
  #This create update_branch entities
  if [ ! "$(uci get -q modgui.gui.update_branch)" ]; then
    uci set modgui.gui.update_branch="stable"
    update_branch=""
    logger_command "Setting update branch to STABLE"
  elif [ "$(uci get -q modgui.gui.update_branch)" == "stable" ]; then
    update_branch=""
    logger_command "Update branch detected: STABLE"
  else
    update_branch="_dev"
    logger_command "Update branch detected: DEV"
  fi

  #Remove deprecated .gz GUI file if low space device
  overlay_space=$(df /overlay | sed -n 2p | awk {'{print $2}'})
  if [ "$overlay_space" -lt 33000 ]; then
    logger -s -t 'Root Script' "Detected low flash space device..."
    if [ -f /root/GUI.tar.gz ]; then
      logger -s -t 'Root Script' "Removing unneeded gz of Stable GUI"
      rm /root/GUI.tar.gz
    fi
  fi

  #This makes sure we have a recovery GUI package in /root
  if [ ! -f /root/GUI.tar.bz2 ]; then
    logger_command "Stable GUI not found in /root"
    if [ ! -f /tmp/GUI.tar.bz2 ]; then
      logger_command "Stable GUI not found in /tmp, checking for GUI_dev..."
      if [ -f /tmp/GUI_dev.tar.bz2 ]; then
        logger_command "Found GUI_dev in /tmp, copying in /root to generate a valid hash"
        mv /tmp/GUI_dev.tar.bz2 /tmp/GUI.tar.bz2
        move_gui_to_root
      elif ping -q -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        logger_command "Downloading stable..."
        curl -k -s https://raw.githubusercontent.com/Ansuel/gui-dev-build-auto/master/GUI.tar.bz2 --output /tmp/GUI.tar.bz2
        move_gui_to_root
      else
        logger_command "Can't download stable GUI!"
      fi
    else
      logger_command "Moving stable GUI from /tmp to /root"
      move_gui_to_root
    fi
    if [ -s /root/GUI.tar.bz2 ]; then
      logger_command "Assuming first time install, cleaning /www dir and re-extracting .bz2"
      rm -r /www/*
      bzcat /root/GUI.tar.bz2 | tar -C / -xf - www
    fi
  fi

  #This generates new hash
  if [ -f /root/GUI.tar.bz2 ]; then
    old_gui_hash=$(uci get -q modgui.gui.gui_hash)
    if [ -f /root/gui_dev.md5sum ]; then
      gui_hash=$(cat /root/gui_dev.md5sum)
    else
      gui_hash=$(md5sum /root/GUI.tar.bz2 | awk '{ print $1}')
    fi
    if [ "$old_gui_hash" != "$gui_hash" ]; then
      logger_command "Detected upgrade!"
      logger_command "Old GUI hash: $old_gui_hash"
      logger_command "New GUI hash: $gui_hash"
    else
      logger_command "GUI hash set: $old_gui_hash"
    fi
  else
    logger_command "Can't generate GUI hash, file not found!"
    gui_hash="0"
  fi

  if [ "$saved_gui_version" != "$version_gui" ]; then
    logger_command "Updating version saved to $version_gui"
    uci set modgui.gui.gui_version="$version_gui"
  else
    uci set modgui.gui.gui_version="$version_gui"
  fi

  saved_gui_version="$(uci -q get modgui.gui.gui_version)"

  #This is to fix a bug in older gui when stable gui is wrongly saved as dev and never replaced.
  major_ver="$(echo "$saved_gui_version" | cut -d. -f 0)"
  if [ "$major_ver" -lt 9 ]; then
    if [ -f /root/GUI.tar.bz2 ] && [ -f /root/GUI_dev.tar.bz2 ]; then
      rm /root/GUI.tar.bz2
      mv /root/GUI_dev.tar.bz2 /root/GUI.tar.bz2
    fi
  fi

  logger_command "Resetting version info..."

  if [ ! "$(uci get -q modgui.gui.gui_hash)" ]; then
    uci set modgui.gui.new_ver="Unknown"
    uci set modgui.gui.gui_hash=$gui_hash
    uci set modgui.gui.outdated_ver='0'
  elif [ "$(uci get -q modgui.gui.gui_hash)" != $gui_hash ]; then
    uci set modgui.gui.new_ver="Unknown"
    uci set modgui.gui.gui_hash=$gui_hash
    uci set modgui.gui.outdated_ver='0'
  fi
  if [ ! "$(uci get -q modgui.gui.autoupgrade)" ]; then
    uci set modgui.gui.autoupgrade_hour=0
    uci set modgui.gui.autoupgrade=0
  fi
  if [ ! "$(uci get -q modgui.gui.autoupgradeview)" ]; then
    uci set modgui.gui.autoupgradeview="none"
  fi
  if [ ! "$(uci get -q modgui.gui.firstpage)" ]; then
    uci set modgui.gui.firstpage="stats"
  fi
  if [ ! "$(uci get -q modgui.gui.randomcolor)" ]; then
    uci set modgui.gui.randomcolor="0"
  fi
  if [ ! "$(uci get -q modgui.gui.gui_animation)" ]; then
    uci set modgui.gui.gui_animation="1"
  fi
}

fcctlsettings_daemon() {
  if [ -f /etc/config/fcctlsettings ]; then
    if [ "$(grep </etc/config/fcctlsettings 'mcast-learn')" ]; then
      rm /etc/config/fcctlsettings #NEVER EVER WRITE - IN CONFIG FILE...
    fi
  fi
  if [ ! -f /etc/config/fcctlsettings ]; then
    if [ -f /etc/config/fcctlsettings_new ]; then
      mv /etc/config/fcctlsettings_new /etc/config/fcctlsettings
    fi
  else
    if [ -f /etc/config/fcctlsettings_new ]; then
      rm /etc/config/fcctlsettings_new
    fi
  fi
  if [ ! -k /etc/rc.d/S99fcctlsettings ] && [ -f /etc/init.d/fcctlsettings ]; then
    chmod 755 /etc/init.d/fcctlsettings
    /etc/init.d/fcctlsettings enable
    /etc/init.d/fcctlsettings start >/dev/null
  fi
}

led_integration() {
  #Restart statusledeventing if old version
  if [ -f /tmp/status-led-eventing.lua_new ]; then
    ledeventing_new_md5=$(awk </tmp/status-led-eventing.md5sum '{ print $1 }')
    ledeventing_md5=$(md5sum /sbin/status-led-eventing.lua | awk '{ print $1 }')
    logger_command "LedEventing new md5sum: $ledeventing_new_md5"
    logger_command "LedEventing md5sum: $ledeventing_md5"
    if [ "$ledeventing_new_md5" ] && [ "$ledeventing_new_md5" != "$ledeventing_md5" ]; then
      rm /sbin/status-led-eventing.lua
      mv /tmp/status-led-eventing.lua_new /sbin/status-led-eventing.lua
      rm /tmp/status-led-eventing.md5sum
      /usr/share/transformer/scripts/restart_leds.sh
      ubus send fwupgrade '{"state":"upgrading"}' # #continue blinking when service restarted
    else
      rm /tmp/status-led-eventing.lua_new /tmp/status-led-eventing.md5sum
    fi
  fi
}

decrypt_config_pass() {
  #With new base they started decrypting password stored in plaintext in config files...
  #This decrypts them back to originals
  lua /usr/share/transformer/scripts/decryptPasswordInUciConfig.lua
}

clean_ping_and_traceroute() {
  if [ -n "$(uci get -q traceroute.diagping.host)" ]; then
    uci set traceroute.diagping.host=""
  fi
  if [ -n "$(uci get -q ipping.diagping.host)" ]; then
    uci set ipping.diagping.host=""
  fi
}

clean_watchdog() {
  if [ -n "$(uci get -q watchdog.@watchdog[0].pidfile)" ]; then
    uci set watchdog.@watchdog[0].pidfile=""
  fi
}

logger_command "Check original config"
orig_config_gen #this check if new config are already present
logger_command "Unlocking web interface if needed"
check_webui_config
logger_command "Check if variant_friendly_name set"
check_variant_friendly_name
logger_command "Remove https check"
remove_https_check_cwmpd #cleanup
logger_command "Check for CSS themes"
check_uci_gui_skin #check css
logger_command "Check driver setting"
create_driver_setting #create diver setting if not present
logger_command "Check Dropbear config file"
dropbear_config_check #check dropbear config
logger_command "Check eco paramaters"
eco_param #This disable eco param as they introduce some latency
logger_command "Create GUI type in config"
create_gui_type #Gui Type
logger_command "Add new web options"
add_new_web_rule #This check new option so that we don't replace the one present
logger_command "New DHCPRelay Option"
check_relay_dhcp           #Sync option
suppress_excessive_logging #Suppress logging
logger_command "Create new option for led definitions"
led_integration #New option led
logger_command "Creating and checking real version"
real_ver_entitied #Support for spoofing firm
logger_command "Implementing WoL"
new_wol_implementation #New Wol
logger_command "Apply new xDSL options"
add_xdsl_option #New xdsl option
logger_command "Adding fast cache options"
fcctlsettings_daemon #Adds fast cache options
logger_command "Checking if wan_mode option exists..."
check_wan_mode        # wan_mode check
dosprotect_inizialize #dosprotected inizialize function
logger_command "Checking if intercept is enabled and disabling if it is..."
disable_intercept #Intercept check
logger_command "Disabling coredump reboot..."
disable_upload_coredump_and_reboot
logger_command "Restoring nginx additional options if needed..."
restore_nginx
logger_command "Adding missing voicednd rule if needed"
adds_dnd_config
logger_command "Doing various checks and generating hashes..."
cumulative_check_gui #Handle strange installation
logger_command "Decrypting any encrypted password present in config"
decrypt_config_pass
clean_ping_and_traceroute
clean_watchdog
