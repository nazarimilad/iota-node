#!/bin/bash
set -o errexit
set -o nounset

# This script manages the IRI

declare -i PORT=14265
declare -i UDP_RECEIVER_PORT=14600
declare -i TCP_RECEIVER_PORT=15600
declare -i IPM_RECEIVER_PORT=8888
declare -r CONFIG_FILE_NAME="$HOME/.iota-node/iri.ini"
declare -r ADRES_REGEX="TODO"

#############################################################################################################"

# update the daemon
update() {
    systemctl daemon-reload && systemctl restart iota-node
    
    # check if IOTA-PM is installed
    if [ -s /etc/systemd/system/iota-pm.service ]
    then
        systemctl restart iota-pm
    fi
}

add_neighbor() {
    if [ -s $CONFIG_FILE_NAME ]
    then 
        # delete example addresses first
        sed -i -E "s# udp://neighbor-1:14600 udp://neighbor-2:14600##g" $CONFIG_FILE_NAME
        sed -i -E "s#(NEIGHBORS.*)#\1 $1#g" $CONFIG_FILE_NAME
        update
        printf "Address $1 had been added to your list of neighbors.\n\n"
    else 
        printf "You either don't have an ini configuration file or it's empty.\nYou can create one by running iota-node without any argument.\n\n"
    fi
}

compile_iri() {
    git clone https://github.com/iotaledger/iri
    mvn -f iri/pom.xml clean compile
    mvn -f iri/pom.xml package
}

get_ip_address() {
    echo $(dig +short myip.opendns.com @resolver1.opendns.com)
}    

get_neighbors() {
    printf "$(curl -s http://$(get_ip_address):$PORT -X POST -H 'Content-Type: application/json' -H 'X-IOTA-API-Version: 1' -d '{\"command\": \"getNeighbors\"}')\n"
}

get_node_info() {
    printf "$(curl -s http://$(get_ip_address):$PORT -X POST -H 'Content-Type: application/json' -H 'X-IOTA-API-Version: 1' -d '{\"command\": \"getNodeInfo\"}')\n"
}

# get daemon status
get_status() {
    printf "$(systemctl status iota-node)\n"
}

get_tcp_address() {
    echo "tcp://$(get_ip_address):$TCP_RECEIVER_PORT"
}

get_udp_address() {
    echo "udp://$(get_ip_address):$UDP_RECEIVER_PORT"
}

install_ipm() {
    npm i -g iota-pm
    read_input "IOTA Peer Manager" "IPM_RECEIVER_PORT"
    setup_ipm_daemon
}
    

install_node() {    
    compile_iri

    clear 
    printf "Welcome to the IOTA node installation!\n\n"
    
    # Generate the configuration file
    read_input "API command" "PORT"
    read_input "UDP" "UDP_RECEIVER_PORT"
    read_input "TCP" "TCP_RECEIVER_PORT"
    
    write_config_file
    
    # copy the freshly compiled iri.jar to the .iota-node folder
    IRI_FILE_NAME=$(ls iri/target/| grep -P -w "^iri.*\.jar$")
    cp -R iri/target/$IRI_FILE_NAME $HOME/.iota-node/
    mv $HOME/.iota-node/$IRI_FILE_NAME $HOME/.iota-node/iri.jar
  
    setup_node_daemon
    
    # copy this script to the .iota-node folder
    cp iota-node.sh $HOME/.iota-node/
    chmod +x $HOME/.iota-node/iota-node.sh
    
    # create an alias
    echo "alias sudo='sudo '" >> $HOME/.bashrc
    echo "alias iota-node='bash $HOME/.iota-node/iota-node.sh'" >> $HOME/.bashrc
    source $HOME/.bashrc
    
    # delete unnecessary files
    rm -rf iri/
    
    printf "\nWould you like to install IOTA-PM? This is a program for monitoring and managing IOTA peers connected with your node.\n"
    printf "[y/n]: "
    read IPM_INSTALLATION_ANSWER
    if [ $IPM_INSTALLATION_ANSWER == "y" ];
    then
        printf "\n"
        install_ipm
    fi

    printf "\nThe installation has been completed!\nYour TCP address to share with others is $(get_tcp_address) .\nYour UDP address to share with others is $(get_udp_address) .\n\nAdd a neighbor to start the node by running the following command:\niota-node --add-neighbor addressOfYourNeighbor\n\n"

    printf "If you previously chose to install IOTA-PM too, AFTER adding a neighbor you can access your dashboard here:\nhttp://$(get_ip_address):$IPM_RECEIVER_PORT\n\n"
}

parse_arguments() {
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -a) add_neighbor "$2"; shift 2;;
        -i) install_node; shift 1;;
        -I) get_ip_address; shift 1;;
        -n) get_node_info; shift 1;;
        -N) get_neighbors; shift 1;;
        -r) remove_neighbors; shift 1;;
        -s) get_status; shift 1;;
        -t) get_tcp_address; shift 1;;
        -u) update; shift 1;;
        -U) get_udp_address; shift 1;;
        -x) systemctl start iota-node; shift 1;;
        -X) systemctl stop iota-node; shift 1;;

        --get-ip-address) get_ip_address; shift 1;;
        --add-neighbor=*) add_neighbor "${1#*=}"; shift 1;;
        --get-neighbors) get_neighbors; shift 1;;
        --get-node-info) get_node_info; shift 1;;
        --get-status) get_status; shift 1;;
        --get-tcp-address) get_tcp_address; shift 1;;
        --get-udp-address) get_udp_address; shift 1;;
        --install-node) install_node; shift 1;;
        --remove-neighbors) remove_neighbors; shift 1;;
        --start) systemctl start iota-node; shift 1;;
        --stop) systemctl stop iota-node; shift 1;;
        --update) update; shift 1;;
        --add-neighbor) printf "Command $1 requires an argument.\n\n" >&2; exit 1;;

        -*) printf "Unknown option: $1.\n\n" >&2; exit 1;;
        *) printf "Commando not recongnized\n"; shift 1;;
      esac
    done
}

read_input() { 
    local PORT_LOCAL="$2"
    printf "Which port should be used to receive $1 data?\n"
    printf "The default port ${!2} will be used if no input is given.\n\n"
    printf "PORT: "
    read PORT_INPUT
    if [ -n "${PORT_INPUT}" ]; then
        until [ $PORT_INPUT -eq $PORT_INPUT 2> /dev/null ]
        do
            printf "A port can be identified only by numbers. Try again.\n"
            printf "PORT: "
            read PORT_INPUT
        done

        eval $PORT_LOCAL=${PORT_INPUT}
    fi
    printf "\n"
}

remove_neighbors() {
    if [ -s $CONFIG_FILE_NAME ]
    then
        sed -i -E 's/(NEIGHBORS = ).*/\1/g' $CONFIG_FILE_NAME
        printf "Your neighbor addresses have been deleted. You're alone now.\n\n"
    else 
        printf "You either don't have an ini configuration file or it's empty.\n\
                You can create one by running iota-node without any argument.\n"
    fi
}

setup_ipm_daemon() {
cat > /etc/systemd/system/iota-pm.service << EOL
[Unit] 
Description=IOTA Peer Manager
After=network.target 

[Service] 
ExecStart=/usr/local/bin/iota-pm -i http://127.0.0.1:$PORT -p 127.0.0.1:$IPM_RECEIVER_PORT
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
ExecStart=/usr/bin/java -jar $HOME/.iota-node/iri.jar -c $CONFIG_FILE_NAME
ExecReload=/bin/kill -HUP \$MAINPID KillMode=process Restart=on-failure 

[Install] 
WantedBy=multi-user.target 
Alias=iota-node.service
EOL
}

write_config_file() {
mkdir -p $HOME/.iota-node/
cat > $CONFIG_FILE_NAME << EOL
[IRI]
PORT = ${PORT}
UDP_RECEIVER_PORT = ${UDP_RECEIVER_PORT}
TCP_RECEIVER_PORT = ${TCP_RECEIVER_PORT}
NEIGHBORS = udp://neighbor-1:14600 udp://neighbor-2:14600
IXI_DIR = ixi
HEADLESS = true
DEBUG = true
DB_PATH = mainnetdb
EOL
}


################################################################################################################

# control if script is being run as root
if [ "$EUID" -ne 0 ]
then
    printf "Please run as root\n\n"
    exit
else
    # if that's the case then: 
    # control if arguments are given in
    if [ "$#" -gt 0 ]
    then 
        parse_arguments "$@"
    else
        # control if the configuration file exists and isn't empty
        if [ -s $CONFIG_FILE_NAME ]
        then
            printf "To run this program, you need to specify at least one argument.\n\n"
        else
            install_node
        fi
    fi
fi
