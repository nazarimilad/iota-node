#!/usr/bin/env bash
# exit if any command fails
set -o errexit
# exit if any undeclared variable is used
set -o nounset

### VARIABLES ###############################################################################################

declare -r IOTA_NODE_VERSION="2.1.3"
declare REQUIRED_MINIMUM_AMOUNT_OF_RAM=4
declare AMOUNT_OF_RAM=$(sudo dmidecode -t 17 | awk '( /Size/ && $2 ~ /^[0-9]+$/ ) { x+=$2 } END{ print ((x/1024))}' | xargs)

# IRI
declare IRI_PORT=14265
declare IRI_UDP_RECEIVER_PORT=14600
declare IRI_TCP_RECEIVER_PORT=15600
declare IRI_CONFIG_FILE_NAME="$HOME/.iota-node/iri.ini"
declare IRI_FILE_NAME="iri.jar"

# NodeJS
declare NODEJS_VERSION=9.4.0

# IPM
declare IOTA_PM_PORT=8888

# Nelson cli
declare NELSON_CLI_PORT=18600
declare NELSON_CLI_TCP_PORT=16600
declare -r NELSON_CLI_CONFIG_FILE_NAME="$HOME/.iota-node/nelson.ini"
declare NELSON_CLI_USERNAME=""
declare NELSON_CLI_PASSWORD=""

# TUI
declare -i TUI_WIDTH=60
declare -i TUI_HEIGHT=10
declare IS_TUI_ON=false

# Regex
declare URI_REGEX="TODO"
declare PORT_REGEX="^[1-9][0-9]+$"

### FUNCTIONS #################################################################################################

update_node_daemon() {
    sudo systemctl daemon-reload && sudo systemctl restart iota-node
    
    # check if any extra package is installed too and restart it too
    if [[ -s /etc/systemd/system/iota-pm.service ]]; then
        sudo systemctl restart iota-pm
    fi
    if [[ -s /etc/systemd/system/nelson-cli.service ]]; then
        sudo systemctl restart nelson-cli
    fi

    if [[ "$IS_TUI_ON" = true ]]; then
        whiptail --title "IRI restart" \
                 --msgbox "The IRI has been restarted." $TUI_HEIGHT $TUI_WIDTH
    else
        printf "The IRI has been restarted\n"
    fi
}

download_iri() {
    if [[ "$IS_TUI_ON" = true ]]; then
        URL=$(curl -s https://api.github.com/repos/iotaledger/iri/releases/latest | \
              grep browser_download_url | cut -d '"' -f 4 | grep -P \/iri-.*\.jar$ | cat)
        # download IRI in the background and save download logs in new created file to let the progressbar use  it
        sudo curl -L $URL --output $HOME/.iota-node/$IRI_FILE_NAME &>> curl_iri_status.log &
        {
            PERCENTAGE="0"
            while (true); do
                PROC=$(ps aux | grep -v grep | grep -e "curl")
                if [[ "$PROC" == "" ]]; then
                    # no curl process active anymore, download ended, end progressbar                
                    break
                fi
                echo $PERCENTAGE
                PERCENTAGE=$(cat curl_iri_status.log | tr $'\r' $'\n' | tail -1 | awk -F' ' '{print $1}')
            done
        } | whiptail --title "IOTA-node" --gauge "\nDownloading iri.jar ..." $TUI_HEIGHT $TUI_WIDTH 0
        sudo rm curl_iri_status.log
    else
        printf "Downloading iri.jar ...\n"
        sudo curl -L $URL --output $HOME/.iota-node/$IRI_FILE_NAME
        printf "iri.jar has been downloaded\n"
    fi
}

upgrade_node() {
    download_iri
    update_node_daemon
    if [[ "$IS_TUI_ON" = true ]]; then
        whiptail --title "IRI upgrade" \
                 --msgbox "The IRI has been upgraded." $TUI_HEIGHT $TUI_WIDTH
    else
        printf "The IRI has been upgraded\n"
    fi
}

upgrade_node_js() {
    sudo npm cache clean -f
    sudo npm install -g n
    sudo n stable
    sudo ln -sf /usr/local/n/versions/node/$NODEJS_VERSION/bin/node /usr/bin/nodejs
}

add_neighbor() {

    # check if the ini configuration file exists and is not empty
    if [[ -s $IRI_CONFIG_FILE_NAME ]]; then
        if [[ "$IS_TUI_ON" = true ]]; then
            ADDRESS_NEW_NEIGHBOR=$(whiptail --inputbox "\nWhat's the address of your new neighbor?" $TUI_HEIGHT $TUI_WIDTH \
                                            --title "New neighbor" 3>&1 1>&2 2>&3)
            sed -i -E "s#(NEIGHBORS.*)#\1 $ADDRESS_NEW_NEIGHBOR#g" $IRI_CONFIG_FILE_NAME
            update_node_daemon
        else
            sed -i -E "s#(NEIGHBORS.*)#\1 $1#g" $IRI_CONFIG_FILE_NAME
            update_node_daemon
        fi

        if [[ "$IS_TUI_ON" = true ]]; then
            whiptail --title "New neighbor" \
                     --msgbox "Neighbor $ADDRESS_NEW_NEIGHBOR has been added." $TUI_HEIGHT $TUI_WIDTH
        else
            printf "Neighbor $1 has been added.\n\n"            
        fi
    else 
        if [[ "$IS_TUI_ON" = true ]]; then
            whiptail --title "Error" \
                     --msgbox "You either don't have an ini configuration file or it's empty" $TUI_HEIGHT $TUI_WIDTH
        else
            printf "You either don't have an ini configuration file or it's empty.\n\n"    
        fi
    fi
}

get_ip_address() { printf "$(dig +short myip.opendns.com @resolver1.opendns.com)\n"; }    

get_neighbors() {
    JSON_OUTPUT=$(curl -s http://localhost:14265 -X POST -H 'Content-Type: application/json' -H 'X-IOTA-API-Version: 1' \
                       -d '{"command": "getNeighbors"}' | python -m json.tool)
    printf "Your neighbors:\n$JSON_OUTPUT\n"         

}

get_node_info() {
    JSON_OUTPUT=$(curl -s http://localhost:14265 -X POST -H 'Content-Type: application/json' -H 'X-IOTA-API-Version: 1' \
                   -d '{"command": "getNodeInfo"}' | python -m json.tool)         
    printf "Information about your node:\n$JSON_OUTPUT\n"
}

get_status() {
    printf "\nInformation about the iota-node daemon:\n\n"
    printf "$(systemctl status iota-node | tr $'\r' $'\n' | tail -n 10 | cut -d' ' -f 13-27 | grep -v "^-")\n\n"
}

get_tcp_address() { printf "tcp://$(get_ip_address):$IRI_TCP_RECEIVER_PORT"; }

get_udp_address() { printf "udp://$(get_ip_address):$IRI_UDP_RECEIVER_PORT"; }

install_iota_ipm() {
    npm i -g iota-pm

    # configure IOTA-PM port if necessary
    if ( whiptail --title "IOTA-PM Port configuration" --yesno "Default port is: $IOTA_PM_PORT\nDo you want to change this port (not recommended)?" $TUI_HEIGHT $TUI_WIDTH ); then
        IOTA_PM_PORT=$(whiptail --inputbox "\nWhich port should be used for IOTA-PM?" $TUI_HEIGHT $TUI_WIDTH $IOTA_PM_PORT --title "IOTA-PM port" 3>&1 1>&2 2>&3)
        while [[ ! $IOTA_PM_PORT =~ $PORT_REGEX ]]; do
            IOTA_PM_PORT=$(whiptail --inputbox "\nError: please enter a valid port number" $TUI_HEIGHT $TUI_WIDTH --title "Invalid port" 3>&1 1>&2 2>&3)
        done

        whiptail --title "New IOTA-PM Port" --msgbox "IOTA-PM port: $IOTA_PM_PORT." $TUI_HEIGHT $TUI_WIDTH
    fi

    setup_iota_ipm_daemon
}

write_nelson_cli_config_file() {
cat > $NELSON_CLI_CONFIG_FILE_NAME << EOL
[nelson]
name = IOTA-node Nelson-CLI interface
cycleInterval = 60
epochInterval = 300
apiPort = ${NELSON_CLI_PORT}
apiHostname = 0.0.0.0
port = ${NELSON_CLI_TCP_PORT}
IRIHostname = localhost
IRIProtocol = any
IRIPort = ${IRI_PORT}
TCPPort = ${IRI_TCP_RECEIVER_PORT}
UDPPort = ${IRI_UDP_RECEIVER_PORT}
dataPath = ${HOME}/.iota-node/data/neighbors.db
; maximal incoming connections. Please do not set below this limit:
incomingMax = 5
; maximal outgoing connections. Only set below this limit, if you have trusted, manual neighbors:
outgoingMax = 4
isMaster = false
silent = false
gui = false
getNeighbors = https://raw.githubusercontent.com/SemkoDev/nelson.cli/master/ENTRYNODES
; add as many initial Nelson neighbors, as you like
neighbors[] = mainnet.deviota.com/16600
neighbors[] = mainnet2.deviota.com/16600
neighbors[] = mainnet3.deviota.com/16600
neighbors[] = iotairi.tt-tec.net/16600

; Protect API with basic auth
[nelson.apiAuth]
username=${NELSON_CLI_USERNAME}
password=${NELSON_CLI_PASSWORD}
EOL
}

install_nelson_cli() {
    npm i -g nelson.cli

    # configure nelson cli ports if necessary
    if ( whiptail --title "Nelson CLI Ports configuration" --yesno "Default API port is: $NELSON_CLI_PORT\nDefault TCP port is: $NELSON_CLI_TCP_PORT\nDo you want to change this ports (not recommended)?" $TUI_HEIGHT $TUI_WIDTH ); then
        NELSON_CLI_PORT=$(whiptail --inputbox "\nWhich port should be used for the Nelson CLI API?" $TUI_HEIGHT $TUI_WIDTH $NELSON_CLI_PORT --title "Nelson CLI API port" 3>&1 1>&2 2>&3)
        while [[ ! $NELSON_CLI_PORT =~ $PORT_REGEX ]]; do
            NELSON_CLI_PORT=$(whiptail --inputbox "\nError: please enter a valid port number" $TUI_HEIGHT $TUI_WIDTH --title "Invalid port" 3>&1 1>&2 2>&3)
        done

        NELSON_CLI_TCP_PORT=$(whiptail --inputbox "\nWhich port should be used for TCP packets?" $TUI_HEIGHT $TUI_WIDTH $NELSON_CLI_TCP_PORT --title "Nelson CLI TCP port" 3>&1 1>&2 2>&3)
        while [[ ! $NELSON_CLI_TCP_PORT =~ $PORT_REGEX ]]; do
            NELSON_CLI_TCP_PORT=$(whiptail --inputbox "\nError: please enter a valid port number" $TUI_HEIGHT $TUI_WIDTH --title "Invalid port" 3>&1 1>&2 2>&3)
        done

        whiptail --title "New Nelson CLI Ports" --msgbox "Nelson CLI API port: $NELSON_CLI_PORT.\nNelson CLI TCP port: $NELSON_CLI_TCP_PORT." $TUI_HEIGHT $TUI_WIDTH        
    fi

    NELSON_CLI_USERNAME=$(whiptail --inputbox "\nPlease choose a username for Nelson authentification:" $TUI_HEIGHT $TUI_WIDTH --title "Nelson authentification" 3>&1 1>&2 2>&3)
    NELSON_CLI_PASSWORD=$(whiptail --passwordbox "\nPlease choose a password for Nelson authentification:" $TUI_HEIGHT $TUI_WIDTH --title "Nelson authentification" 3>&1 1>&2 2>&3)
    NELSON_CLI_TEMP_PASSWORD=$(whiptail --passwordbox "\nPlease re-enter your password:" $TUI_HEIGHT $TUI_WIDTH --title "Nelson authentification" 3>&1 1>&2 2>&3)
    while [[ ! "$NELSON_CLI_PASSWORD" == "$NELSON_CLI_TEMP_PASSWORD" ]]; do
        NELSON_CLI_PASSWORD=$(whiptail --passwordbox "\nPasswords didn't match. Please choose again:" $TUI_HEIGHT $TUI_WIDTH --title "Nelson authentification" 3>&1 1>&2 2>&3)
        NELSON_CLI_TEMP_PASSWORD=$(whiptail --passwordbox "\nPlease re-enter your password:" $TUI_HEIGHT $TUI_WIDTH --title "Nelson authentification" 3>&1 1>&2 2>&3)
    done

    write_nelson_cli_config_file
    setup_nelson_cli_daemon
}

install_iri_and_script() {
    # create necessary directories
    mkdir -p $HOME/.iota-node/data/   

    # download iri.jar if it isn't present
    if [[ ! -s $HOME/.iota-node/$IRI_FILE_NAME ]]; then
        download_iri
    fi

    # copy this bash script to the .iota-node folder
    cp iota-node.sh $HOME/.iota-node/
    chmod +x $HOME/.iota-node/iota-node.sh
    
    # create an iota-node alias for the terminal if it isn't already present
    if ( ! grep -q iota-node $HOME/.bashrc ); then 
        echo "alias sudo='sudo '" >> $HOME/.bashrc
        echo "alias iota-node='bash $HOME/.iota-node/iota-node.sh'" >> $HOME/.bashrc
    fi
}

control_minimum_requirements() {
    if [[ $AMOUNT_OF_RAM -lt $REQUIRED_MINIMUM_AMOUNT_OF_RAM ]]; then 
        if ( ! whiptail --title "Unsufficient RAM" --yesno "\nRequired minimum amount of RAM: $REQUIRED_MINIMUM_AMOUNT_OF_RAM GB\nAmount of RAM you have:         $AMOUNT_OF_RAM GB\nDo you still want to continue?" $TUI_HEIGHT $TUI_WIDTH ); then
            exit
        fi
    fi
}


install_node() {   
    # welcome screen
    if ( ! whiptail --title "IOTA-node" --yesno "Welcome to the installation of IOTA-node.\nThis installation will create a full IOTA node.\n\nDo you want to continue?" $TUI_HEIGHT $TUI_WIDTH ); then
        exit
    fi

    control_minimum_requirements

    IS_TUI_ON=true
    install_iri_and_script

    # configure IOTA-PM port if necessary
    if ( whiptail --title "IRI Ports configuration" --yesno "Default API port is: $IRI_PORT\nDefault UDP port is: $IRI_UDP_RECEIVER_PORT\nDefault TCP port is: $IRI_TCP_RECEIVER_PORT\nDo you want to change this ports (not recommended)?" $TUI_HEIGHT $TUI_WIDTH ); then
        IRI_PORT=$(whiptail --inputbox "\nWhich port should be used for the IRI API?" $TUI_HEIGHT $TUI_WIDTH $IRI_PORT --title "IRI API port" 3>&1 1>&2 2>&3)
        while [[ ! $IRI_PORT =~ $PORT_REGEX ]]; do
            IRI_PORT=$(whiptail --inputbox "\nError: please enter a valid port number" $TUI_HEIGHT $TUI_WIDTH --title "Invalid port" 3>&1 1>&2 2>&3)
        done

        IRI_UDP_RECEIVER_PORT=$(whiptail --inputbox "\nWhich port should be used for UDP packets?" $TUI_HEIGHT $TUI_WIDTH $IRI_UDP_RECEIVER_PORT --title "UDP port" 3>&1 1>&2 2>&3)
        while [[ ! $IRI_UDP_RECEIVER_PORT =~ $PORT_REGEX ]]; do
            IRI_UDP_RECEIVER_PORT=$(whiptail --inputbox "\nError: please enter a valid port number" $TUI_HEIGHT $TUI_WIDTH --title "Invalid port" 3>&1 1>&2 2>&3)
        done

        IRI_TCP_RECEIVER_PORT=$(whiptail --inputbox "\nWhich port should be used for TCP packets?" $TUI_HEIGHT $TUI_WIDTH $IRI_TCP_RECEIVER_PORT --title "TCP port" 3>&1 1>&2 2>&3)
        while [[ ! $IRI_TCP_RECEIVER_PORT =~ $PORT_REGEX ]]; do
            IRI_TCP_RECEIVER_PORT=$(whiptail --inputbox "\nError: please enter a valid port number" $TUI_HEIGHT $TUI_WIDTH --title "Invalid port" 3>&1 1>&2 2>&3)
        done

        whiptail --title "New IRI Ports" \
                 --msgbox "API port: $IRI_PORT.\nUDP port: $IRI_UDP_RECEIVER_PORT.\nTCP port: $IRI_TCP_RECEIVER_PORT." $TUI_HEIGHT $TUI_WIDTH
    fi
    
    write_iri_config_file
    setup_node_daemon
    start_node_daemon

    PACKAGES=""
    while [[ -z $PACKAGES ]]; do
        PACKAGES=$(whiptail --title "Extra packages" --checklist \
                           "\nWhich of the following extra packages would you like to install?\
                            Select with Space and confirm your choice with Enter.\
                            If nothing is needed, cancel with Escape." 15 70 4 \
                           "IOTA-PM" "IRI and neighbor monitoring " OFF \
                           "Nelson.cli" "Automatic P2P neighbor management " OFF 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ! $exitstatus = 0 ]]; then
            break
        fi
    done
     
    if [[ $PACKAGES =~ "IOTA-PM" ]]; then
        upgrade_node_js     
        install_iota_ipm
        update_node_daemon
    fi
    if [[ $PACKAGES =~ "Nelson.cli" ]]; then
        upgrade_node_js
        install_nelson_cli
        update_node_daemon
    fi

    whiptail --title "Installation completed" \
             --msgbox "The installation has been completed!\nYour addresses to share with others are:\n$(get_tcp_address)\n$(get_udp_address)" $TUI_HEIGHT $TUI_WIDTH
}

setup_iota_ipm_daemon() {
cat > /etc/systemd/system/iota-pm.service << EOL
[Unit] 
Description=IOTA Peer Manager
After=network.target

[Service] 
ExecStart=/usr/local/bin/iota-pm -i http://127.0.0.1:$IRI_PORT -p 0.0.0.0:$IOTA_PM_PORT
Restart=on-failure
RestartSec=5s

[Install] 
WantedBy=multi-user.target 
EOL
}

write_iri_config_file() {
cat > $IRI_CONFIG_FILE_NAME << EOL
[IRI]
PORT = ${IRI_PORT}
UDP_RECEIVER_PORT = ${IRI_UDP_RECEIVER_PORT}
TCP_RECEIVER_PORT = ${IRI_TCP_RECEIVER_PORT}
NEIGHBORS =
API_HOST = 0.0.0.0
IXI_DIR = ixi
HEADLESS = true
DEBUG = false
TESTNET = false
DB_PATH = mainnetdb
RESCAN_DB = false

REMOTE_LIMIT_API = "removeNeighbors, addNeighbors, interruptAttachingToTangle, attachToTangle, getNeighbors, setApiRateLimit"
EOL
}

setup_nelson_cli_daemon() {
cat > /etc/systemd/system/nelson-cli.service << EOL    
[Unit] 
Description=Nelson CLI Neighbor Manager
After=network.target 

[Service] 
ExecStart=/usr/local/bin/nelson --config $NELSON_CLI_CONFIG_FILE_NAME
Restart=on-failure
RestartSec=5s

[Install] 
WantedBy=multi-user.target 
EOL
}

setup_node_daemon() {
cat > /etc/systemd/system/iota-node.service << EOL
[Unit] 
Description=IOTA-node 
After=network.target 

[Service] 
WorkingDirectory=$HOME/.iota-node
ExecStart=/usr/bin/java -Djava.net.preferIPv4Stack=true -jar $HOME/.iota-node/iri.jar -c $IRI_CONFIG_FILE_NAME
ExecReload=/bin/kill -HUP \$MAINPID KillMode=process 
Restart=on-failure 

[Install] 
WantedBy=multi-user.target
EOL
}

load_parameters() {
    IRI_PORT=$(awk -F "=" '/^PORT/ {print $2}' $IRI_CONFIG_FILE_NAME | tr -d ' ' | xargs)
    IRI_UDP_RECEIVER_PORT=$(awk -F "=" '/UDP_RECEIVER_PORT/ {print $2}' $IRI_CONFIG_FILE_NAME | tr -d ' ' | xargs)
    IRI_TCP_RECEIVER_PORT=$(awk -F "=" '/TCP_RECEIVER_PORT/ {print $2}' $IRI_CONFIG_FILE_NAME | tr -d ' ' | xargs)

    if [[ -s /etc/systemd/system/iota-pm.service ]]; then
        IOTA_PM_PORT=$(cat /etc/systemd/system/iota-pm.service | grep "\-p" | sed 's/.*-p .*:\(.*\)/\1/')
    fi
    if [[ -s /etc/systemd/system/nelson-cli.service ]]; then
        NELSON_CLI_PORT=$(awk -F "=" '/apiPort/ {print $2}' $NELSON_CLI_CONFIG_FILE_NAME | tr -d ' ' | xargs)
        NELSON_CLI_TCP_PORT=$(awk -F "=" '/port/ {print $2}' $NELSON_CLI_CONFIG_FILE_NAME | tr -d ' ' | xargs)
    fi
}

remove_neighbors() {
    if [[ -s $IRI_CONFIG_FILE_NAME ]]; then
        if [[ "$IS_TUI_ON" = true ]]; then
            if ( whiptail --title "Removing neighbors" --yesno \
                                  "Are you sure you want to delete all your neighbors?" $TUI_HEIGHT $TUI_WIDTH ); then
                sed -i -E 's/(NEIGHBORS = ).*/\1/g' $IRI_CONFIG_FILE_NAME
                update_node_daemon
                whiptail --title "Removing neighbors" \
                         --msgbox "All your neighbors have been removed. You're alone now." $TUI_HEIGHT $TUI_WIDTH
            else
                exit
            fi
        else
            sed -i -E 's/(NEIGHBORS = ).*/\1/g' $IRI_CONFIG_FILE_NAME
            update_node_daemon
            printf "Your neighbor addresses have been removed. You're alone now.\n\n"
        fi
    else
        if [[ "$IS_TUI_ON" = true ]]; then
            whiptail --title "Error" \
                     --msgbox "You either don't have an ini configuration file or it's empty" $TUI_HEIGHT $TUI_WIDTH
        else
            printf "You either don't have an ini configuration file or it's empty.\n\n"    
        fi
    fi
}

start_node_daemon() {
    sudo systemctl daemon-reload
    sudo systemctl start iota-node

    # check if any extra package is installed too and start it too
    if [[ -s /etc/systemd/system/iota-pm.service ]]; then
        sudo systemctl start iota-pm
    fi
    if [[ -s /etc/systemd/system/nelson-cli.service ]]; then
        sudo systemctl start nelson-cli
    fi

    if [[ "$IS_TUI_ON" = true ]]; then   
        whiptail --title "IOTA-node status" \
                 --msgbox "IOTA-node has been started." $TUI_HEIGHT $TUI_WIDTH
    fi
}

parse_arguments() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -a) add_neighbor "$2"; shift 2;;
            -I) get_ip_address; shift 1;;
            -n) get_node_info; shift 1;;
            -N) get_neighbors; shift 1;;
            -r) remove_neighbors; shift 1;;
            -s) get_status; shift 1;;
            -t) get_tcp_address; shift 1;;
            -u) update_node_daemon; shift 1;;
            -U) get_udp_address; shift 1;;
            -x) start_node_daemon; shift 1;;
            -X) stop_node_daemon; shift 1;;

            --get-ip-address) get_ip_address; shift 1;;
            --add-neighbor=*) add_neighbor "${1#*=}"; shift 1;;
            --get-neighbors) get_neighbors; shift 1;;
            --get-node-info) get_node_info; shift 1;;
            --get-status) get_status; shift 1;;
            --get-tcp-address) get_tcp_address; shift 1;;
            --get-udp-address) get_udp_address; shift 1;;
            --remove-neighbors) remove_neighbors; shift 1;;
            --start) start_node_daemon; shift 1;;
            --stop) stop_node_daemon; shift 1;;
            --update) update_node_daemon; shift 1;;
            --upgrade) upgrade_node; shift 1;;            
            --uninstall) uninstall_node; shift 1;;
            --add-neighbor) printf "Command $1 requires an argument.\n\n" >&2; exit 1;;

            -*) printf "Unknown option: $1.\n\n" >&2; exit 1;;
            *) printf "Commando not recongnized\n"; shift 1;;
        esac
    done
}

stop_node_daemon() {
    sudo systemctl stop iota-node

    # check if any extra package is installed too and stop it too
    if [[ -s /etc/systemd/system/iota-pm.service ]]; then
        sudo systemctl stop iota-pm
    fi
    if [[ -s /etc/systemd/system/nelson-cli.service ]]; then
        sudo systemctl stop nelson-cli
    fi

    if [[ "$IS_TUI_ON" = true ]]; then   
        whiptail --title "IOTA-node status" \
                 --msgbox "IOTA-node has been stopped." $TUI_HEIGHT $TUI_WIDTH
    fi
}

uninstall_node() {
    if [[ "$IS_TUI_ON" = true ]]; then   
        if ( ! whiptail --title "Uninstall" --yesno "Are you sure you want to uninstall your node?" \
                        $TUI_HEIGHT $TUI_WIDTH ); then
            exit
        fi
    fi

    sed -i '/iota-node/d' $HOME/.bashrc
    sed -i '/alias sudo/d' $HOME/.bashrc
    stop_node_daemon
    sudo rm /etc/systemd/system/iota*
    
    if [[ -s /etc/systemd/system/iota-pm.service ]]; then
        sudo npm -g uninstall iota-pm
        sudo rm /etc/systemd/system/iota-pm.service
    fi
    if [[ -s /etc/systemd/system/nelson-cli.service ]]; then
        sudo npm -g uninstall nelson-cli
        sudo rm /etc/systemd/system/nelson-cli.service
    fi

    sudo rm -rf $HOME/.iota-node/
    sudo systemctl daemon-reload
}

tui_get_addresses() {
    whiptail --title "Your addresses" \
             --msgbox "Your addresses to share with others:\n\nUDP address: $(get_udp_address)\nTCP address: $(get_tcp_address)" \
             $TUI_HEIGHT $TUI_WIDTH
}

tui_get_node_info() {
    IRI_VERSION=$(get_node_info | grep appVersion | sed 's/\"appVersion\": \"\(.*\)\",/\1/' | xargs)
    LATEST_MILESTONE_INDEX=$(get_node_info | grep latestMilestoneIndex | sed 's/\"latestMilestoneIndex\": \(.*\),/\1/' | xargs)
    LATEST_SOLID_SUBTANGLE_MILESTONE_INDEX=$(get_node_info | grep latestSolidSubtangleMilestoneIndex | sed 's/\"latestSolidSubtangleMilestoneIndex\": \(.*\),/\1/' | xargs)
    AMOUNT_OF_NEIGHBORS=$(get_node_info | grep neighbors | sed 's/\"neighbors\": \(.*\),/\1/' | xargs)
    AMOUNT_OF_TIPS=$(get_node_info | grep tips | sed 's/\"tips\": \(.*\),/\1/' | xargs)
    AMOUNT_OF_TRANSACTIONS_TO_REQUEST=$(get_node_info | grep transactionsToRequest | sed 's/\"transactionsToRequest\": \(.*\)/\1/' | xargs)
    IS_IRI_SYNCED=""
    if [[ $LATEST_MILESTONE_INDEX -eq $LATEST_SOLID_SUBTANGLE_MILESTONE_INDEX ]]; then
        IS_IRI_SYNCED=Yes
    else
        IS_IRI_SYNCED=No
    fi

    whiptail --title "Node info" \
             --msgbox "IRI version: $IRI_VERSION\nNeighbors:   $AMOUNT_OF_NEIGHBORS\n\nTips:          $AMOUNT_OF_TIPS\nTx to request: $AMOUNT_OF_TRANSACTIONS_TO_REQUEST\n\nLatest Milestone index:           $LATEST_MILESTONE_INDEX\nLatest subtangle Milestone index: $LATEST_SOLID_SUBTANGLE_MILESTONE_INDEX\nIs your node synced:              $IS_IRI_SYNCED" \
             15 $TUI_WIDTH           
}

show_menu() {
    IS_TUI_ON=true
    CHOICE=$(
        whiptail --title "IOTA-node" --menu "\nMake your choice:" 20 60 10 \
            "1)" "Get your address to share with others"  \
            "2)" "Get information about your neighbors" \
            "3)" "Add a neighbor"   \
            "4)" "Remove your neighbors" \
            "5)" "Get information about your node" \
            "6)" "Start/stop node" \
            "7)" "Restart node" \
            "8)" "Upgrade node" \
            "9)" "About" \
            "10)" "Exit"  3>&2 2>&1 1>&3  
        )

    case $CHOICE in
        "1)") tui_get_addresses ;;

        "2)") get_neighbors ;;

        "3)") add_neighbor ;;

        "4)") remove_neighbors ;;

        "5)") tui_get_node_info ;;

        "6)")   
            if [[ $(ps aux | grep -v grep | grep -e "$IRI_FILE_NAME") =~ "$IRI_FILE_NAME" ]]; then             
                stop_node_daemon
            else
                start_node_daemon
            fi
        ;;

        "7)") update_node_daemon ;;

        "8)") upgrade_node ;;

        "9)")   
            whiptail --title "About IOTA-node" \
                     --msgbox "Version: $IOTA_NODE_VERSION\nSource: https://github.com/nazarimilad/iota-node\nLicense: MIT License\nCreator: Milad Nazari" \
                     $TUI_HEIGHT $TUI_WIDTH
        ;;
        
        "10)") exit ;;
    esac
}

##############################################################################################################

# control if script is being run as root
if [[ "$EUID" -ne 0 ]]; then
    whiptail --title "Not root" --msgbox "Please run as root." $TUI_HEIGHT $TUI_WIDTH
    exit
else
    # control if the configuration file exists and isn't empty
    if [[ -s $IRI_CONFIG_FILE_NAME ]]; then
        # if that's the case then: 
        load_parameters
        # control if arguments are given in
        if [[ "$#" -gt 0 ]]; then 
            parse_arguments "$@"
        else
            
            show_menu 
        fi  
    else
        install_node
    fi
fi