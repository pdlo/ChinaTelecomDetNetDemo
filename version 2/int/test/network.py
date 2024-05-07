from p4utils.mininetlib.network_API import NetworkAPI

net = NetworkAPI()

# Network general options
net.setLogLevel('info')
net.enableCli()

# Network definition
net.addP4Switch('s1', cli_input='s1-commands.txt')
net.addP4Switch('s2', cli_input='s2-commands.txt')
net.addP4Switch('s3', cli_input='s3-commands.txt')


net.setP4Source('s1', 'start_end.p4')
net.setP4Source('s2', 'middle.p4')
net.setP4Source('s3', 'start_end.p4')


net.addHost('h1')
net.addHost('h2')

net.addLink('h1','s1')
net.setIntfPort('s1', 'h1', 1)
net.addLink('s1','s2')
net.setIntfPort('s1','s2',2)
net.setIntfPort('s2','s1',1)
net.addLink('s2','s3')
net.setIntfPort('s2','s3',2)
net.setIntfPort('s3','s2',1)

net.addLink('s3','h2')
net.setIntfPort('s3','h2',2)


# Assignment strategy
net.mixed()

# Nodes general options
net.enablePcapDumpAll()
net.enableLogAll()

# Start network
net.startNetwork()
