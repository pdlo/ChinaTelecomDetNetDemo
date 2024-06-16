from p4utils.mininetlib.network_API import NetworkAPI

net = NetworkAPI()

# Network general options
net.setLogLevel('info')
net.enableCli()

# Network definition
net.addP4Switch('s1', cli_input='s1-commands.txt')
net.addP4Switch('s2', cli_input='s2-commands.txt')
net.addP4Switch('s3', cli_input='s3-commands.txt')
net.setP4Source('s1','INT_gz.p4')
net.setP4Source('s2','forward.p4')
net.setP4Source('s3','INT_bj.p4')

net.addHost('h1')
net.addHost('h2')
net.addHost('h3')


# Add links with specified bandwidth
net.addLink('h1', 's1')  # 10 Mbps
net.addLink('s1', 'h2')  # 20 Mbps
net.addLink('s1', 's2')  # 30 Mbps
net.addLink('s2', 's3')  # 40 Mbps
net.addLink('s3','h3')
# Assignment strategy
net.mixed()

# Nodes general options
net.enablePcapDumpAll()
net.enableLogAll()

# Start network in a new thread
net.startNetwork()

