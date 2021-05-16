#!/usr/bin/expect

set timeout 20
spawn telnet 127.0.0.1 33011
expect "(qemu) "
send "info status\n"
expect "(qemu) "
send "\x1d"
send "close\n"
