# Enable Telnet of S1E

## Easy way (works till 2.0.5_1032), but you may need to wait for a long time
1. Call or Email to Aqara for did and key of the S1E
2. Run generate_pswd.sh
```
scripts/generate_pswd.sh s1e_did s1e_mac s1e_key
```
example:

<img src="/images/s1e2ha_generate_pswd.png" alt="uart" height="170" width="850">

3. Then you can get the password of telnet
4. Run telnet to S1E, the username is 'root' and the password is the one you got in step 2
5. Reset the password
```
passwd -d root
```

## Hard way
1. Open the case
2. Connect to UART, reference to the picture. Suggestion use soldering.
<img src="/images/s1e_uart.png" alt="uart" height="520" width="460">
3.