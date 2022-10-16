# Resources for Aqara Smart Switch S1E


# official
This folder will offer the things from Aqara inlcuding themes.

# images
Some pictures related to Aqara Smart Swich S1E, like the UART (tx, rx, gnd) and 5V

# scripts
Some scripts help you to speed up some works.

For example, pic_resizer.py can help to resize and convert the pictures which are using in theme. More detail to use pic_resizer.py etc., please see the [readme](/scripts/README.md).

# homeassistant
The custom_component of S1E to integrate to Home Assistant.

The Aqara Smart Switch S1E supports HomeKit, so you can use HomeKit integration of HA to connect S1E to HA.
Use HomeKit to integrat to HA, there are three switchs and six wireless buttons you can control and use them in HA.

Here is another solution which is using MQTT to integrate to HA and provides more informations and features to use S1E.

<img src="/images/s1e2ha_controls.png" alt="controls" height="634" width="160"> <img src="/images/s1e2ha_sensors.png" alt="sensors" height="190" width="160"> <img src="/images/s1e2ha_diagnostic.png" alt="diagnostic" height="440" width="160">

To use the integration, you need to enable telnet and login to telnet to install this integraton.
After enabled telent, please make sure that you had *MQTT broker* running then following the intrustions.

```
wget -O /tmp/curl "http://master.dl.sourceforge.net/project/aqarahub/binutils/curl?viasf=1"; chmod +x /tmp/curl
/tmp/curl -s -k -L -o /tmp/install_s1e2ha.sh https://raw.githubusercontent.com/niceboygithub/AqaraSmartSwitchS1E/master/homeassistant/install_s1e2ha.sh; chmod a+x /tmp/install_s1e2ha.sh
/tmp/install_s1e2ha.sh
```

Then enter the ip, port, username and password of your MQTT broker.
<img src="/images/s1e2ha_installation.png" alt="Installation" height="350" width="650">

Then, enjoy!

## Theme
You can use settheme to download theme from your HA to your S1E.
1. Put the themefile.zip to /config/www/ of HA.
2. Find the topic of settheme, go to MQTT_INFO, search "theme/config", there is a "send_command_topic".
3. Go to services page in the developer tools page, find mqtt publish
4. Set the topic to "homeassistant/select/0x0054XXXXXXXXXX/theme/settheme" and the Payload is the url, like "http://homeassistant.local:8123/local/theme7_6.zip".
5. Press CALL SERVICE button

To create your own theme, you can replace any pictures in the theme with png file. Please the see [directory tree](/scripts/tree.md) of theme first. Also you can use "pic_resizer.py" to help you resize and convert the pictures.

<img src="/images/s1e2ha_settheme.gif" alt="controls" height="178" width="316">
