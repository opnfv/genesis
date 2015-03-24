#!/usr/bin/expect
spawn /opt/odl/distribution-karaf-0.2.2-Helium-SR2/bin/client
expect "root>"
send "feature:list | grep -i odl-restconf\r"
send "\r\r\r"
expect "root>"
send "logout\r"

