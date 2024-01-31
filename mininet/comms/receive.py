#!/usr/bin/env python3
import sys
import struct
import os

from socket import *
from scapy.all import sniff, sendp, hexdump, get_if_list, get_if_hwaddr
from scapy.all import Packet, IPOption
from scapy.all import ShortField, IntField, LongField, BitField, FieldListField, FieldLenField
from scapy.all import IP, TCP, UDP, Raw
from scapy.layers.inet import _IPOption_HDR


pkt_in = 0
def handle_pkt(pkt):
    global pkt_in
    pkt_in = pkt_in + 1
    print('Packet in: {}'.format(pkt_in))
    print("-------------- New Packet --------------")
    pkt.show2()

    print('-------------- end --------------\n')
    sys.stdout.flush()
        
    # if UDP in pkt: # and pkt[UDP].dport == int(sys.argv[1]):
    #     pkt_in = pkt_in + 1
    #     print('Packet in: {}'.format(pkt_in))
    #     print("-------------- New Packet --------------")
    #     pkt.show2()
        # data = pkt[Raw].load
        # print('\n---- Telemetry Packet ----')
        # print('sw_id: {0}.{1}.{2}.{3}'.format(data[0],data[1],data[2],data[3] ) )
        # print('latency: {}'.format(int.from_bytes(data[4:10],'little') ))
        # print('-------------- end --------------\n')
    #    hexdump(pkt)

        # sys.stdout.flush()


def main():
    # ifaces = [i for i in os.listdir('/sys/class/net/') if 'enp1s0f0' in i]
    # iface = ifaces[0]
    iface = "eth0"
    serverSocket = socket(AF_INET, SOCK_DGRAM)

    # Assign IP address and port number to socket
    serverSocket.bind(('', 12345))

    print(("sniffing on %s" % iface))
    sys.stdout.flush()
    sniff(iface = iface,
          prn = lambda x: handle_pkt(x), filter='udp and port 12345')

if __name__ == '__main__':
    main()


 # We will need the following module to generate randomized lost packets
    import random


    # Create a UDP socket
    # Notice the use of SOCK_DGRAM for UDP packets


    while True:
        # Generate random number in the range of 0 to 10
        rand = random.randint(0, 10)

        # Receive the client packet along with the address it is coming from
        message, address = serverSocket.recvfrom(1024)

        # Capitalize the message from the client
        message = message.upper()

        # If rand is less is than 4, we consider the packet lost and do notrespond
        if rand < 4:
            continue

        # Otherwise, the server responds
        serverSocket.sendto(message, address) 