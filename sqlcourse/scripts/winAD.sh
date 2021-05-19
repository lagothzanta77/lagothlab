#!/bin/bash
sh Win2016server.sh
until ( ping -c 1 192.168.2.38 >/dev/null 2>/dev/null );do sleep 4;done
sleep 6
sh windows10pro.sh

