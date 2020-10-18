#!/usr/bin/env bash

#+------------------------------------------------------------------------------+
#|                     SoftetherVPN Connection Management                       |
#|                            License: GPL 3.0                                  |
#|                              Version: 1.0                                    |
#+------------------------------------------------------------------------------+

CLIENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VPNCLIENT="$CLIENT_DIR/vpnclient"
VPNCMD="$CLIENT_DIR/vpncmd"
COMMAND=${!#}
VPN_CLIENT_HOST="localhost"
DEFAULT_GATEWAY="192.168.1.1"
VPN_GATEWAY="192.168.30.1"
VERBOSE=0
NIC_NAME="secm_nic"
ACCOUNT_NAME="SECM_ACCT"

# Test if we are in correct working directory
if [[ (! -f "$VPNCLIENT") || (! -f "$VPNCLIENT") ]]; then
  echo 'Please move this script to your SoftEther VPN client directory.'
  exit 1
fi

# Test if the user is root or not
[ ${EUID:-$(id -u)} -eq 0 ]
if [ ! $? -eq 0 ]; then
  echo 'This script should be run as root.'
  exit 1
fi

# Read options
while getopts ":h:v:" opt; do
  case ${opt} in
    h )
      VPN_CLIENT_HOST=$OPTARG
      ;;
    v )
      VERBOSE=1
      ;;
    \? )
      echo "Invalid option: $OPTARG" 1>&2
      ;;
  esac
done
shift $((OPTIND -1))

echo "VPN Client Host: $VPN_CLIENT_HOST"
echo "System Default Gateway: $VPN_CLIENT_HOST"
echo "VPN Network Gateway: $VPN_GATEWAY"

set_connect_routes() {
  local VPN_SERVER_IP=$($VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountList | grep -A2 "$ACCOUNT_NAME" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
  #local VPN_GATEWAY=$(dhclient "vpn_$NIC_NAME" -v | grep "DHCPACK" | cut --only-delimited --delimiter=" " --fields=5)
  #local DEFAULT_GATEWAY=$(ip route | grep default | cut --only-delimited --delimiter=" " --fields=3 | tail -1)
  
  dhclient "vpn_$NIC_NAME"
  ip route add "$VPN_SERVER_IP" via "$DEFAULT_GATEWAY"
  ip route flush 0/0 #ip route del default via "$DEFAULT_GATEWAY"
  ip route add default via "$VPN_GATEWAY"
}

set_disconnect_routes() {
  local VPN_SERVER_IP=$($VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountList | grep -A2 "$ACCOUNT_NAME" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
  #local DEFAULT_GATEWAY=$(ip route | grep "$VPN_SERVER_IP via" | cut --only-delimited --delimiter=" " --fields=3 | tail -1)
  
  ip route flush 0/0 #ip route del default via "$VPN_GATEWAY"
  ip route add default via "$DEFAULT_GATEWAY"
  ip route del "$VPN_SERVER_IP" via "$DEFAULT_GATEWAY"
  resolvconf -u
}

manage_account() {
  # Check if any VPN account exist
  $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountList | grep "$ACCOUNT_NAME" > /dev/null
  if [ $? -eq 0 ]; then
    
    $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountList | grep -A1 "$ACCOUNT_NAME" | grep "Offline" > /dev/null
    
    if [ $? -eq 0 ]; then
    
      # Connect VPN account
      $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountConnect "$ACCOUNT_NAME"
      if [ $? -eq 0 ]; then   
        echo "VPN account connected successfully."
        
        set_connect_routes
        echo "Softether VPN connected successfully. Your publuc IP is: $(curl -s ifconfig.me | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")"
        exit 0
        
      else
        echo "Error connecting VPN account."
        exit 1
      fi
    else
      echo "Account connection is establishing or already connected."
    fi
    
    $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountList | grep -A1 "$ACCOUNT_NAME" | grep "Connected" > /dev/null
    if [ $? -eq 0 ]; then
      set_connect_routes
      echo "Softether VPN connected successfully. Your publuc IP is: $(curl -s ifconfig.me | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")"
      exit 0
    fi
    
  else
    echo -n "There is no any enabled VPN account in the client. A new account will be created. Is this OK? (y/n) "
    read yesno < /dev/tty
    
    if [ "x$yesno" = "xy" ]; then
      read -p "Destination VPN Server Host Name and Port Number: (IP:PORT) " SERVER_HOST
      read -p "Destination Virtual Hub Name: " HUB_NAME
      read -p "Connecting User Name: " USER_NAME
      read -p "User Password: " -s USER_PASSWORD
      
      $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountCreate "$ACCOUNT_NAME" /SERVER:"$SERVER_HOST" /HUB:"$HUB_NAME" /USERNAME:"$USER_NAME" /NICNAME:SECM_NIC
      if [ $? -eq 0 ]; then
        echo "A new VPN account created."
        
        # Setting password for this account
        $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountPasswordSet "$ACCOUNT_NAME" /PASSWORD:"$USER_PASSWORD" /TYPE:standard
        
        # Connect VPN account
        $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountConnect "$ACCOUNT_NAME"
        if [ $? -eq 0 ]; then   
          echo "VPN account connected successfully."
          
          set_connect_routes
          echo "Softether VPN connected successfully. Your publuc IP is: $(curl -s ifconfig.me | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")"
          exit 0
          
          exit 0
        else
          echo "Error connecting VPN account."
          exit 1
        fi
        
      else
        echo "Error creating a new VPN account. Exiting now."
        exit 1
      fi
    else
      echo "A valid VPN account is required to create and establish a VPN connection. Exiting now."
      exit 1
    fi
  fi
}

# Start Connection
if [ "$COMMAND" = start ]; then
  
  # Start SoftEther VPN Client
  $VPNCLIENT start
  [[ $? -eq 0 ]] && CLIENT_STARTED=1 || CLIENT_STARTED=0
  
  # Check the environment
  $VPNCMD /tools /cmd Check > /dev/null
  [[ $? -eq 0 ]] && CHECK_PASSED=1 || CHECK_PASSED=0
    
  if [[ ($CLIENT_STARTED -eq 1) && ($CHECK_PASSED -eq 1) ]]; then
  
    # Check if any Nic exist
    $VPNCMD /client "$VPN_CLIENT_HOST" /cmd NicList | grep "Virtual Network Adapter Name" | grep "$NIC_NAME" > /dev/null
  
    if [ $? -eq 0 ]; then
    
      # Connect
      manage_account
      if [ $? -eq 0 ]; then
        exit 0
      else
        exit 1
      fi
      
    else
      echo -n "There is no any enabled virtual adapter for the client. A new virtual adapter will be created. Is this OK? (y/n) "
      read yesno < /dev/tty

      if [ "x$yesno" = "xy" ]; then
        $VPNCMD /client "$VPN_CLIENT_HOST" /cmd NicCreate "$NIC_NAME"
      
        if [ $? -eq 0 ]; then
          echo "A new virtual adapter created."

          # Connect
          manage_account
          if [ $? -eq 0 ]; then
            echo "Account connected."
            exit 0
          else
            exit 1
          fi
          
        else
          echo "Error creating a new virtual adapter. Exiting now."
          exit 1
        fi
      else
        echo "An enabled virtual adapter is required to create and establish a VPN connection. Exiting now."
        exit 1
      fi
    fi
  else
    echo "There was an error initializing the VPN client."
    exit 1;
  fi

elif [ "$COMMAND" = stop ]; then
  $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountList | grep -A1 "$ACCOUNT_NAME"> /dev/null
  
  
  if [ $? -eq 0 ]; then
  
    # Disconnect Account
    $VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountDisconnect "$ACCOUNT_NAME"
    if [ $? -eq 0 ]; then   
      echo "VPN account disconnected successfully."
    else
      echo "Error disconnecting VPN account."
    fi
    
    # Stop VPN client
    $VPNCLIENT stop
    
    # Restore default routes
    set_disconnect_routes
    
    echo "VPN connection has been successfully disconnected. Your publuc IP is: $(curl -s ifconfig.me | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")"
    exit 0

  else
    echo "Please start the connection before stopping it!"
    exit 1
  fi
  
elif [ "$COMMAND" = status ]; then
  echo "Account $($VPNCMD /client "$VPN_CLIENT_HOST" /cmd AccountList | grep -A1 "$ACCOUNT_NAME" | grep "Status")"
  echo "Your public IP address is: $(curl -s ifconfig.me | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")"  
  exit 0;
else
  echo "Please pass a valid command as the first parameter."
  echo "Valid commands are: start, stop, status"
  exit 1;
fi
