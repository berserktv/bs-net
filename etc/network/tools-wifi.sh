#!/bin/sh

# скрипт предназначен для сканирования ближайших WiFi сетей утилитой "iw" 
# и генерацию хеша паролей, командой wpa_passphrase
# autor: "Alexander Demachev", project: "Berserk", site: https://berserk.tv
# примечание: имена WiFi сетей в которых есть пробелы, не поддерживаются
# так как такие имена вносят большее количество неодназначности
# (например пробел в конце имени сети)
#
# license -  The MIT License (MIT)

WLAN_SCAN="/tmp/wifi.scan"

scan_wifi() {
    local wlan="$1"
    iw $wlan scan > $WLAN_SCAN
    if [ $? -ne 0 ]; then
        # ошибка выполнения команды
        return 1
    fi

    awk '
/^BSS / {
    MAC = $2
}
/SSID/ {
    wifi[MAC]["SSID"] = $2
    wifi[MAC]["secure"] = "NOT"
}
/primary channel/ {
    wifi[MAC]["channel"] = $NF
}

/signal: / {
    # quality = 2 * (dBm + 100)
    # dBm = quality / 2 - 100
    wifi[MAC]["signal"] = 2 * ($2 + 100)
}

# определение протокола шифрования:
# NOT      => отсутствие полей WPA и RSN
# WPA-PSK  => наличие поля WPA:
# WPA2-PSK => наличие поля RSN:
/WEP:/ {
    wifi[MAC]["secure"] = "WEP"
}
/WPA:/ {
    if (wifi[MAC]["secure"] != "WPA2-PSK") wifi[MAC]["secure"] = "WPA-PSK"
}
/RSN:/ {
    wifi[MAC]["secure"] = "WPA2-PSK"
}


END {
    #printf "%s\t\t\t%s\t\t\t%s\n","SSID","signal","secure"

    for (w in wifi) {
        if (wifi[w]["SSID"]) printf "%s Quality %s%% %s\n",wifi[w]["SSID"],wifi[w]["signal"],wifi[w]["secure"]
    }
}' $WLAN_SCAN

# | column -t
# FIXME:
# утилита column входит в пакет bsdmainutils (необходимо собрать пакет)

}




# arg1 - wlan interface
# arg2 - command
iface="$1"
cmd="$2"
code=0

if [ "$cmd" = "scan" ]; then
    scan_wifi "$1"
    code=$?

elif [ "$cmd" = "gen" ]; then
    if [ -z "$3" ] || [ -z "$4" ] || [ -z "$5" ]; then echo "args - not found"; code=2
    else
       wpa_passphrase "$3" "$4" > "$5"
       code=$?
       # в случае удачной генерации пароля оставляю только хеш
       if [ $code -eq 0 ]; then sed -i "/#psk=/d" "$5"; chmod 600 "$5";
       else rm -f "$5"; fi
    fi
fi



exit $code




