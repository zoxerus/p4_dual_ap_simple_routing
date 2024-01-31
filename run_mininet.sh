#!/bin/bash
source ~/.bashrc
# get path to this sh file and change to it's directory so it can be called
# from any folder.
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}";
cd "$( dirname -- "$SCRIPT_PATH"; )";

./compile.sh

# path to the switch control CLI in order to set the flow rules and other
# control parameters of the switch.
#PATH_CLI="../../../behavioral-model-main/targets/simple_switch/simple_switch_CLI"
PATH_CLI="/usr/bin/simple_switch_CLI"

# path to the executable switch file, in order to start the switch.
#PATH_BEHAVIORAL="../../../behavioral-model-main/targets/simple_switch/simple_switch"
PATH_BEHAVIORAL="/usr/bin/simple_switch"

# path to the network and collector siwtches
PATH_NETSW="./p4out/ap.json"


# clear the mininet cash
sudo mn -c




# commands for installing the flow rules to the switches.
# added a sleep 5 seconds to wait for the switches to boot up before installing
# the flow rules, varies with system performance.
gnome-terminal --tab -- bash -c "sleep 5; python3 $PATH_CLI --thrift-port 9091 < ./cli/ap1.txt"
gnome-terminal --tab -- bash -c "sleep 5; python3 $PATH_CLI --thrift-port 9092 < ./cli/ap2.txt"

# gnome-terminal --tab -- bash -c "sleep 5; python3 $PATH_CLI --thrift-port 9092 < ./cli/sw2.txt"
# gnome-terminal --tab -- bash -c "sleep 5; python3 $PATH_CLI --thrift-port 9093 < ./cli/sw3.txt"



# start the relevant mininet
sudo python3 ./mininet/mynet.py --behavioral-exe "$PATH_BEHAVIORAL" --json-net "$PATH_NETSW"

