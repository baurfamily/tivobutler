# Introduction #

If you want to see the communication between TiVo Butler (or any other client app) and your TiVo, you can follow these instructions.

# Details #

## Install and configure stunnel ##

If you have mac ports installed, you can do this very easily by doing `sudo port install stunnel` (I assume that fink has it as an available package as well).  If not, you'll have to download the code and compile it by hand.

Create a file, called tivo\_stunnel.conf and paste in this configuration (change 192.168.1.101 to the IP of your TiVo box):
```
; Here's so you can see what is going on
foreground = yes

; This is the default key file
cert = /opt/local/etc/stunnel/stunnel.pem

; No PID file
pid = 

; Service-level configuration
[tivo]
client = yes
accept  = 8888
connect = 192.168.1.101:443

[faketivo]
client = no
accept = 443
connect = 8888
```

## Run stunnel and a sniffer ##

To run stunnel, type:

`sudo stunnel tivo_stunnel.conf`

You should see some messages printed to the console (if you are not running it in foreground mode, then the command will return immediately).  You can type Control-C to quit.

Now, run a sniffer to capture traffic going to port 8888.  If you are running stunnel on your desktop machine (as opposed to a server), then you can type:

`sudo tcpdump -i lo0 -s 0 -w tivo.cap port 8888`

## Connect with your client app ##

Now, when you run your client app, tell it that the IP address of your TiVo is the IP of the machine running stunnel.  When it connects, stunnel will accept the connection, decrypt it and send it across the local interface where stunnel will accept it again, re-encrypt it and send it on to the real TiVo box.  The network sniff, which is listening to traffic on the local interface should be able to read the traffic without a problem in between the two.

Note: my other application, [Eavesdrop](http://code.google.com/p/eavesdrop) cannot be used to capture this data and/or interpret it, since it can't use the local interface.  If you were to run one instance of stunnel as the server on one machine and another instance on a secondary machine, then it could be used to do the capture.