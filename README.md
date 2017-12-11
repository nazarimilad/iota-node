# iota-node
A CLI to manage a full IOTA node

## Description

There are a lot of tutorials like [this one](https://www.simform.com/iota-iiot-tutorial-part-2/) or [this one](https://forum.helloiota.com/2424/Setting-up-a-VPS-IOTA-Full-Node-from-scratch). The problem with this tutorials is that they take quite some time and they aren't easy to follow for people who are new to a Linux environement.

The purpose of this script is to automate the installation of an IOTA full node. It compiles the IRI, it generates an ini configuration file, it sets up a daemon etc. 

It can also be used to adjust settings while it's running. You can add new neighbors for example, remove them, get your TCP address, get information about your own node, and more.

![alt text](https://i.imgur.com/BDhVs35.png "Terminal screenshot")

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

### One-letter options:

* `-a address` : add a neighbor specified by its address
* `-i` : reinstall the node
* `-I` : get your public IP address
* `-n` : get information about your own node
* `-N` : get information about your neighbors
* `-r` : remove all of your neighbors
* `-s` : get the status of the IRI daemon
* `-t` : get the TCP address of your node
* `-u` : restart the node daemon
* `-U` : get the UDP address of your node
* `-x` : start the iota-node daemon
* `-X` : stop the iota-node daemon

## Full word options:

* `--add-neighbor address` : add a neighbor specified by its address 
* `--get-neighbors` : get information about your neighbors
* `--get-node-info` : get information about your own node
* `--get-ip-address` : get your public IP address
* `--get-status` : get the status of the IRI daemon
* `--get-tcp-address` : get the TCP address of your node
* `--get-udp-address` : get the UDP address of your node
* `--install-node` : reinstall the node
* `--remove-neighbors` : remove all of your neighbors
* `--start` : start the node daemon
* `--stop` : stop the node daemon
* `--update` : restart the node daemon

## Code structure 

The first section contains the global variables and script settings.

The second sections consists of the procedures and methodes.

And finally the third block contains the "main method".

## TODO

* Add an option to install [iota-pm](https://github.com/akashgoswami/ipm) during the installation of the node and integrate it in the iota-node daemon
* Add input safety checks (for the ports mainly)
* Make an equivalent powershell script

---

Any issue or pull request is welcome.

Donations: 

* IOTA-address: `MCVMFBGRJRHMOMFKMTJCIKWSLVQOUASOIHLVHXMVFDPTJYDPUTWITJASHWBDFNRQTYVZIEVYIRYMRSFM9CVDPLSYY9`

* Monero-address: `49y3pVR9mgDhTXgtMnZ4JLCcdKRKTEQTFcVvYaBPGJTfX3sEX2Y9CtBHrLrUBTzSNa2yRSWz69SjJR6uNmszgvfURt2KMR2`
