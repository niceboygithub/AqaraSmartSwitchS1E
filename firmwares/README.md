# Aqara Smart Magic Switch S1E (CJPKG01LM) Firmware

Note that flashing firmware is USING AT YOUR OWN RISK.
## Flash S1E Custom firmware method

```shell
cd /tmp && wget -O /tmp/curl "http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1" && chmod a+x /tmp/curl
/tmp/curl -s -k -L -o /tmp/s1e_update.sh https://raw.githubusercontent.com/niceboygithub/AqaraSmartSwitchS1E/master/firmwares/modified/S1E/s1e_update.sh
chmod a+x /tmp/s1e_update.sh && /tmp/s1e_update.sh
```
