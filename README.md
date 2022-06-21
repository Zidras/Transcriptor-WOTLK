[![Game Version](https://img.shields.io/badge/wow-3.3.5-blue.svg)](https://github.com/Zidras/Transcriptor-WOTLK)
[![Discord](https://discordapp.com/api/guilds/598993375479463946/widget.png?style=shield)](https://discord.gg/CyVWDWS)

# Transcriptor-WOTLK
Event logging addon for 3.3.5a, suitable for boss encounters.
Integrates with both *DBM* and *BigWigs* backports.
- DBM backport: https://github.com/Zidras/DBM-Icecrown/
- BigWigs backport: https://github.com/bkader/BigWigs-WoTLK

## Screenshots
![image](https://user-images.githubusercontent.com/10605951/130322803-151c7345-97eb-45c2-8ba2-2c5b9e85a6be.png)
![image](https://user-images.githubusercontent.com/10605951/130322851-3ff67da9-0cef-4f86-a31b-bd22891d92ba.png)

## How to use
1. For DBM backport 9.2.20 or above (https://github.com/Zidras/DBM-Warmane), write `/dbm debuglevel 3` in chat to enable DBM debug messages. Doing that in conjunction with Transcriptor logs all DBM debug messages too.
3. Write `/ts` in chat at the start of the pull. You can also click the minimap icon (it will turn from dark red to bright red, meaning it's currently logging)

![image](https://user-images.githubusercontent.com/10605951/174873849-24c7231b-580c-4a88-b307-34709bdee343.png)
![image](https://user-images.githubusercontent.com/10605951/174873920-b98f2d90-7b0a-49cb-9320-fdfdfed4be73.png)

4. Write `/ts` in chat at the end of the fight. You can also click the minimap icon (bright red -> dark red = idle)
5. `/reload` (or logout normally) to save the log into the SavedVariables folder. DO NOT force close the client (ALT+F4, power outage, etc) or everything in memory will not be saved. This is very important!
6. Go to your `WTF/Account/<name>/SavedVariables/Transcriptor.lua` to view the log. If TranscriptDB is empty, it means you didn't follow the steps properly and the log is blank. Example of a blank log:

<img width="327" alt="image" src="https://user-images.githubusercontent.com/10605951/174875187-7fab707a-ce0f-407b-80b2-5dcd3e2b76cc.png">

Here is a short clip with all the steps combined on how to quickly generate a log:

https://user-images.githubusercontent.com/10605951/174875418-9e5d14cc-4fbd-4676-a0e8-6cae25b0ab7c.mp4

## How to install and update the addon
1. Download the addon from the **main** repository (https://github.com/Zidras/Transcriptor-WOTLK/archive/refs/heads/main.zip).
2. Inside the zip file, open Transcriptor-WOTLK-main and copy (Ctrl+C) **Transcriptor** folder over to your addons folder (Interface/Addons). 

![image](https://user-images.githubusercontent.com/10605951/130323064-08002ea7-550b-4df3-a877-4bfd6a349f2a.png)
