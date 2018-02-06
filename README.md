# IOTA-node
A CLI and TUI to install and manage a full IOTA node

## Description

There are a lot of tutorials like [this one](https://www.simform.com/iota-iiot-tutorial-part-2/) or [this one](https://forum.helloiota.com/2424/Setting-up-a-VPS-IOTA-Full-Node-from-scratch). The problem with this tutorials is that they take quite some time and they aren't easy to follow for people who are new to a Linux environement.

The purpose of this script is to automate the installation of an IOTA full node. It takes care of installing the IRI, chosing the parameters, installing extra packages such as Nelson and IOTA-PM, managing your neighbors, get information about your node and more.

![alt text](https://i.imgur.com/6x2DXxd.png "Welcome screen")

![alt text](https://i.imgur.com/rjsaEiM.png "Installation of extra packages")

![alt text](https://i.imgur.com/YcNO8n3.png "IOTA-node menu")

More screenshots can be found [in this album](https://imgur.com/a/mWuWC).


## Prerequisites

* Java 8 or higher
* curl 
* dig
* NPM (if you want to install extra packages)
* Yarn (if you want to install the package [Nelson.gui](https://github.com/SemkoDev/nelson.gui))

## Installation and usage

Run the following command in your terminal: 

`curl -L -s $(curl -s https://api.github.com/repos/nazarimilad/iota-node/releases/latest | grep browser_download_url | cut -d '"' -f 4 ) --output iota-node.sh && sudo bash iota-node.sh`

**After** restarting your terminal, you can run iota-node from everywhere: `sudo iota-node <option>`

## Options
The script currently supports the following options:

### One-letter options:

* `-a address` : add a neighbor specified by its address
* `-I` : get your public IP address
* `-n` : get information about your own node
* `-N` : get information about your neighbors
* `-r` : remove all of your neighbors
* `-s` : get the status of the IRI daemon
* `-t` : get the TCP address of your node
* `-u` : restart IOTA-node
* `-U` : get the UDP address of your node
* `-x` : start iota-node
* `-X` : stop iota-node

## Full word options:

* `--add-neighbor=address` : add a neighbor specified by its address 
* `--get-neighbors` : get information about your neighbors
* `--get-node-info` : get information about your own node
* `--get-ip-address` : get your public IP address
* `--get-status` : get the status of the IRI daemon
* `--get-tcp-address` : get the TCP address of your node
* `--get-udp-address` : get the UDP address of your node
* `--remove-neighbors` : remove all of your neighbors
* `--start` : start IOTA-node
* `--stop` : stop IOTA-node
* `--update` : restart IOTA-node
* `--upgrade` : upgrade IOTA-node
* `--uninstall` : uninstall IOTA-node

## Code structure 

The first section contains the global variables and script settings.

The second sections consists of the procedures and methodes.

And finally the third block contains the "main method".

## TODO

* ~~Add an option to install [iota-pm](https://github.com/akashgoswami/ipm) during the installation of the node and integrate it in the iota-node daemon~~
* ~~Add port input safety check~~
* ~~Add a TUI~~
* ~~Add Nelson integration and upgrade option~~
* Add neighbor address input safety check
* Make it possible, With `upgrade`, to also upgrade the extra packages
* Make an equivalent powershell script

---

Any issue or pull request is welcome.

Donations: 

* IOTA-address: `MCVMFBGRJRHMOMFKMTJCIKWSLVQOUASOIHLVHXMVFDPTJYDPUTWITJASHWBDFNRQTYVZIEVYIRYMRSFM9CVDPLSYY9`

* Monero-address: `49y3pVR9mgDhTXgtMnZ4JLCcdKRKTEQTFcVvYaBPGJTfX3sEX2Y9CtBHrLrUBTzSNa2yRSWz69SjJR6uNmszgvfURt2KMR2`
