#!/bin/bash 

# This file contains the functions for connecting to Fuel VM, checking if the installation process completed
# and Fuel became operational, and also enabling outbound network/internet access for this VM through the
# host system

is_product_vm_operational() {
    ip=$1
    username=$2
    password=$3
    prompt=$4

    # Log in into the VM, see if Puppet has completed its run
    # Looks a bit ugly, but 'end of expect' has to be in the very beginning of the line 
    result=$(
        expect << ENDOFEXPECT
        spawn ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null $username@$ip
        expect "connect to host" exit
        expect "*?assword:*"
        send "$password\r"
        expect "$prompt"
        send "grep -o 'Finished catalog run' /var/log/puppet/bootstrap_admin_node.log\r"
        expect "$prompt"
ENDOFEXPECT
    )

    # When you are launching command in a sub-shell, there are issues with IFS (internal field separator)
    # and parsing output as a set of strings. So, we are saving original IFS, replacing it, iterating over lines,
    # and changing it back to normal
    #
    # http://blog.edwards-research.com/2010/01/quick-bash-trick-looping-through-output-lines/
    OIFS="${IFS}"
    NIFS=$'\n'
    IFS="${NIFS}"

    for line in $result; do
        IFS="${OIFS}"
        if [[ $line == Finished* ]]; then
	    IFS="${NIFS}"
            return 0;
        fi    
        IFS="${NIFS}"
    done

    return 1
}

wait_for_product_vm_to_install() {
    ip=$1
    username=$2
    password=$3
    prompt=$4

    echo "Waiting for product VM to install. Please do NOT abort the script..."

    # Loop until master node gets successfully installed
    while ! is_product_vm_operational $ip $username $password "$prompt"; do
        sleep 5
    done
}

enable_outbound_network_for_product_vm() {
    ip=$1
    username=$2
    password=$3
    prompt=$4
    interface_id=$(($5-1))   # Subtract one to get ethX index (0-based) from the VirtualBox index (from 1 to 4)
    gateway_ip=$6

    # Check for internet access on the host system
    echo -n "Checking for internet connectivity on the host system... "
    if [ "`ping -c 5 google.com || ping -c 5 wikipedia.com`" ]; then
        echo "OK"
    else
        echo "FAIL"
        print_no_internet_connectivity_banner
	return 1
    fi

    # Enable internet access on inside the VMs
    echo -n "Enabling outbound network/internet access for the product VM... "

    # Log in into the VM, bring up the NAT interface, set default gateway, check internet connectivity
    # Looks a bit ugly, but 'end of expect' has to be in the very beginning of the line 
    result=$(
        expect << ENDOFEXPECT
        spawn ssh -oConnectTimeout=5 -oStrictHostKeyChecking=no -oCheckHostIP=no -oUserKnownHostsFile=/dev/null $username@$ip
        expect "connect to host" exit
        expect "*?assword:*"
        send "$password\r"
        expect "$prompt"
        send "dhclient eth$interface_id\r"
        expect "$prompt"
        send "ip route replace default via $gateway_ip dev eth$interface_id\r"
        expect "$prompt"
        send "ping -c 5 google.com || ping -c 5 wikipedia.com\r"
	expect "$prompt"
ENDOFEXPECT
    )

    # When you are launching command in a sub-shell, there are issues with IFS (internal field separator)
    # and parsing output as a set of strings. So, we are saving original IFS, replacing it, iterating over lines,
    # and changing it back to normal
    #
    # http://blog.edwards-research.com/2010/01/quick-bash-trick-looping-through-output-lines/
    OIFS="${IFS}"
    NIFS=$'\n'
    IFS="${NIFS}"

    for line in $result; do
        IFS="${OIFS}"
        if [[ $line == *icmp_seq* ]]; then
	    IFS="${NIFS}"
            echo "OK"
	    return 0;
        fi
        IFS="${NIFS}"
    done

    echo "FAIL"
    print_no_internet_connectivity_banner

    return 1
}

print_no_internet_connectivity_banner() {

    echo "############################################################"
    echo "# WARNING: some of the Fuel features will not be supported #"
    echo "#          (e.g. RHOS/RHEL integration) because there is   #"
    echo "#          no Internet connectivity                        #"
    echo "############################################################"

}

