# SoftEther VPN Client Connection Manager for Linux (SECM)

This Bash script is a connection manager for [SoftEtherVPN](https://github.com/SoftEtherVPN/SoftEtherVPN) client.

### SoftetherVPN Client Default Behaviour and Usage
In order to use [SofEtherVPN client for Linux](https://www.softether-download.com/en.aspx?product=softether), after the installation, the VPN client should be started using `vpnclient`, then a virtual adapter and a VPN account should be configurred using the `vpncmd` tool.  
To start the connection, the created account should be connected using `vpncmd`. At this stage the user should manually add/delete the needed static routes to the system to use the connection. To disconnect the VPN, user should add/delete the specific static routes again.

SECM can do all of the described proccess for you. Using two simple commands, it would be easy to manage the VPN connections.

## Installation & Usage
1. Get the latest script:  
`$ git clone https://github.com/bugfloyd/secm.git`

2. Move `secm.sh` to your SoftEther VPN client directory.  
```
$ mv ~/secm/secm.sh ~/vpnclient/
$ cd vpnclient
```
3. Allow executable permissions for `secm.sh`  
`$ chmod +x secm.sh`

4. Start the script and configure NIC and VPN account provideing the required data  
`$ sudo ./secm.sh start`  
  * This command should be run using root privlidges.  
  * The configuration proccess is only required on the first run.
  * This script creates and searches for a specific names for NIC and VPN account, so if you have configured some NIC and VPN accounts before, using the `vpncmd`, you should let the script to create new ones with the specific names.
  
* To disconnect the connection:  
`$ sudo ./secm.sh stop`  

* To view the current status of the VPN connection:  
`$ sudo ./secm.sh status`

## Bash Alias
1. Edit `~/.bash_aliases` or `~/.bashrc` file using: `vi ~/.bash_aliases`
2. Append the bash aliases like these:
```
alias vpnc='sudo ~/vpnclient/secm.sh start'
alias vpnd='sudo ~/vpnclient/secm.sh stop'
alias vpns='sudo ~/vpnclient/secm.sh status'
```
3. Save and close the file.
4. Activate alias by typing: `source ~/.bash_aliases` or `exec $SHELL`  

Now you can use `vpnc`, `vpns`, `vpnd` commands to manage the SoftEtherVPN client connection.

## LICENSE
Code released under the GNU GPL v3 License.
