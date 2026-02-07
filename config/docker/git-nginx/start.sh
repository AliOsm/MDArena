#!/bin/sh
spawn-fcgi -s /var/run/fcgiwrap.socket -U nginx -G nginx -- /usr/bin/fcgiwrap
nginx -g 'daemon off;'
