#!/bin/sh

# common function for dhclient, autor: Alexander Demachev, project: "Berserk",  site: https://berserk.tv
# license -  The MIT License (MIT)

# ps from BusyBox or normal
PS="/bin/ps"
#PS="/bin/ps aux"

find_pid() {
    local args="$1"
    # simple BusyBox
    local num_pid=$($PS | grep -v "grep" | grep "$args" | tr "\n" " " | tr -s " " | cut -d" " -f2)
    echo "$num_pid"
}

ifconfig_get_ip() {
    local iface="$1"
    local ip=$(ifconfig $iface | grep "inet addr:" | cut -d":" -f2 | cut -d" " -f1)
    if [ -n "$ip" ]; then echo "$ip"; return 0;
    else echo ""; return 1; fi
}

send_stop_task() {
   local args="$1"
   local logmark="$2"
   local num_pid=$(find_pid "$args")
   if [ -n "$num_pid" ]; then
       kill -HUP $num_pid; sleep 1;
       logger -s -t $logmark "SEND SIGHUP => kill -HUP $num_pid"
       num_pid=$(find_pid "$args")
       if [ -n "$num_pid" ]; then
           kill -INT $num_pid
           num_pid=$(find_pid "$args")
           if [ -n "$num_pid" ]; then kill -TERM $num_pid; sleep 1; fi
       fi
   fi
}

dhclient_start() {
    local dh_leases="$1"
    local iface="$2"
    local logmark="$3"
    #if ! $PS | grep -v "grep" | grep -q "$dh_leases $iface"; then
    if ! $PS | grep -v "grep" | grep -q "$dh_leases"; then
        test -f $dh_leases && rm -f $dh_leases
        logger -s -t $logmark "dhclient wait answer ..."
        /sbin/dhclient -lf $dh_leases $iface
        if [ $? -eq 0 ]; then logger -s -t $logmark "dhclient => OK"; return 0; fi
    fi
    return 1
}

dhclient_stop() {
    local dh_leases="$1"
    local iface="$2"
    local logmark="$3"
    local num_pid=$(find_pid "$dh_leases")
    if [ -n "$num_pid" ]; then
        send_stop_task "$dh_leases" "$logmark"
        test -f $dh_leases && rm -f $dh_leases
        logger -s -t $logmark "dhclient $dh_leases $iface => stop";
        return 0
    fi
    return 1
}

ntp_stop() {
    local logmark="$1"
    /etc/init.d/ntpd stop
    logger -s -t $logmark "ntp_stop"
}

ntp_start() {
    local logmark="$1"
    /etc/init.d/ntpd stop
    logger -s -t $logmark "/usr/sbin/ntpdate pool.ntp.org"
    /usr/sbin/ntpdate pool.ntp.org
    /etc/init.d/ntpd start
    logger -s -t $logmark "ntp_start"
}

create_resolv_conf() {
    local conf="$1"
    local dns1="$2"
    local dns2="$3"
    local logmark="$4"
    if [ -z "$dns1" ] && [ -z "$dns2" ]; then logger -s -t $logmark "$conf => not find DNS info"; return 1; fi

    echo "# DNS settings added by the script /etc/network/$logmark" > /etc/resolv.conf;
    if [ -n "$dns1" ]; then echo "nameserver $dns1" >> /etc/resolv.conf; fi
    if [ -n "$dns2" ]; then echo "nameserver $dns2" >> /etc/resolv.conf; fi
    return 0
}

