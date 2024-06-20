Generally the idea is when I get to a place I want to use the router, I can connect to it either via a USB ethernet dongle, the projected wifi, or by turning on my phone hotspot.
Should only need to connect via phone hotspot of I forgot the dongle or the wifi network that's supposed to be projected isn't turned on.
Once phone hotspot is on, I can ssh to the pi via wireguard because pi is configured to auto connnect to my phone and wireguard
If hostapd is failing to start `journalctl -u hostapd -f` then it means it isn't configured to use a channel that works. 
`iw list` is how I determine what channels I can use. There'll be 2 phys listed and the more complicated one is the one connected via usb (at least for pi 4)
