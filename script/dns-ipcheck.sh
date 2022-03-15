#!/bin/bash
declare -A dns_address

####################################################
# uncomment and update with DNS address(es) to allow
####################################################
NODE_ID="Mainnet Node"
PASSIVE_MODE="true"
SCRIPT_PATH=/opt/cardano/cnode/scripts


dns_address[your-node1-location]=https://www.w3.org/
#dns_address[your-node2-location]=<your-nodes-dns-address>
#dns_address[your-node3-location]=<your-nodes-dns-address>
#dns_address[your-node4-location]=<your-nodes-dns-address>

dns_port=6000

###############################################
# Do not modify bellow this line
###############################################
if [ -n "$1" ] && [ "$1" == "-f" ] ; then
    PASSIVE_MODE="false"
fi
for i in "${dns_address[@]}"
do
   : 
    if [[ $EUID -ne 0 ]]; then
    echo This script must be run as root: $(date '+%A %B %d %Y %r')
    exit 1
    fi

    new_ip=$(host $i | head -n1 | cut -f4 -d ' ')
    old_ip=$(/usr/sbin/ufw status | grep $i | head -n1 | tr -s ' ' | cut -f3 -d ' ')

    # Healthy condition: do nothing
    if [ "$new_ip" = "$old_ip" ] ; then
        echo $i IP check passed: $(date '+%B %d %Y %r')
    # New setup likely: complete setup with "sudo ./dns-ipcheck.sh -f"
    elif [ -z "$old_ip" ] && [ $PASSIVE_MODE == "true" ]; then
        $SCRIPT_PATH/telegram-allert.sh "$NODE_ID Alert!%0A$i%0Ahas no ufw rule:%0AConsider adding rule with:%0A<sudo ./dns-ipcheck.sh -f>%0A$(date '+%B %d %Y %r')"
        echo "$i has no ufw rule: Consider adding rule with: <sudo ./dns-ipcheck.sh -f> " $(date '+%B %d %Y %r') >> /opt/cardano/cnode/logs/dns-ipcheck.log
    # Could not resolve DNS for some reason. Likely a connction issue.
    elif [ -z "$new_ip" ] ; then
        $SCRIPT_PATH/telegram-allert.sh "$NODE_ID Alert!%0A$i was unreachable at: %0A$old_ip %0AAwaiting connectivity. %0A$(date '+%B %d %Y %r')"
        echo "$i was unreachable at: $old_ip. Awaiting connectivity.": $(date '+%B %d %Y %r') >> /opt/cardano/cnode/logs/dns-ipcheck.log
    # No matching firewall rule found. Lets add it now.
    elif [ -z "$old_ip" ] && [ $PASSIVE_MODE != "true" ]; then
        /usr/sbin/ufw allow proto tcp from $new_ip to any port $dns_port comment $i
        $SCRIPT_PATH/telegram-allert.sh "$NODE_ID Alert!%0A$i has no ufw rule:%0AAdding $new_ip ufw rule: %0A**Updating firewall** %0A$(date '+%B %d %Y %r')"
        echo "Could not locate $new_ip in firewall for $i: **Updating firewall**" $(date '+%B %d %Y %r') >> /opt/cardano/cnode/logs/dns-ipcheck.log
    else
    # Detected IP address change. Taking action and/or notifiy operator.
        if [ $PASSIVE_MODE == "true" ] ; then
            $SCRIPT_PATH/telegram-allert.sh "$NODE_ID Alert!%0AIP address change detected!%0A$i: %0APrevious IP:$old_ip%0ANew IP:$new_ip%0A %0AFirewall NOT updated! %0AVerify new IP then add ufw rule with <sudo ./dns-ipcheck.sh -f>: %0A$(date '+%B %d %Y %r')"
            echo "IP address change detected on $i from $old_ip to $new_ip! Firewall NOT updated. Verify new IP and add ufw rule with  <sudo ./dns-ipcheck.sh -f>:" $(date '+%B %d %Y %r') >> /opt/cardano/cnode/scripts/dns-ipcheck.log
        else
            $SCRIPT_PATH/telegram-allert.sh "$NODE_ID Alert!%0AIP address change detected!%0A$i: %0APrevious IP:$old_ip%0ANew IP:$new_ip%0A %0A**Updating firewall now!** %0A$(date '+%B %d %Y %r')"
            /usr/sbin/ufw delete allow proto tcp from $old_ip to any port $dns_port
            /usr/sbin/ufw allow proto tcp from $new_ip to any port $dns_port comment $i
            echo "IP updated from $old_ip to $new_ip: "$(date '+%B %d %Y %r') >> /opt/cardano/cnode/logs/dns-ipcheck.log
        fi
    fi
done