# iota-node
CLI to manage a full IOTA node

## Description

There are a lot of tutorials like [this one](https://www.simform.com/iota-iiot-tutorial-part-2/) or [this one](https://forum.helloiota.com/2424/Setting-up-a-VPS-IOTA-Full-Node-from-scratch). The problem with this tutorials is that they take quite some time and they aren't easy to follow for people who are new to a Linus environement.

The purpose of this script is to automate the installation of an IOTA full node. It compiles the IRI, it generates an ini configuration file, it sets up a daemon, 
it can be used to add new neighbor nodes, etc.

## Prerequisites

* Maven
* Java 8
* Git

## Installation and usage

First download the repository: `git clone https://github.com/nazarimilad/iota-node.git`
Then enter into the directory: `cd iota-node`
Make the script executable   : `chmod +x iota-node.sh`
Run the script               : `sudo ./iota-node.sh`

After restarting your terminal, you can run iota-node from everywhere: `sudo iota-node <option>`

## Options
The script currently supports the following options:

* --add-neighbor <address> : add a neighbor specified by its address 
* --get-neighbors : get information about your neighbors
* --get-node-info : get information about your own node
* --get-ip-address : get your public IP address
* --get-status : get the status of the IRI daemon
* --get-tcp-address : get the TCP address of your node
* --get-udp-address : get the UDP address of your node
* --install-node : reinstall the node
* --remove-neighbors : remove all of your neighbors
* --start : start the node daemon
* --stop : stop the node daemon
* --update : restart the node daemon

Any issue or pull request is welcome.
