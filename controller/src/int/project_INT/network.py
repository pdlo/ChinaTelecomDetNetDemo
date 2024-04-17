from p4utils.mininetlib.network_API import NetworkAPI

net = NetworkAPI()

# Network general options
net.setLogLevel('info')
net.enableCli()

# Network definition
net.addP4Switch('s1', cli_input='s1-commands.txt')
net.addP4Switch('s2', cli_input='s2-commands.txt')
net.addP4Switch('s3', cli_input='s3-commands.txt')
net.addP4Switch('s4', cli_input='s4-commands.txt')
net.addP4Switch('s5', cli_input='s5-commands.txt')

net.setP4Source('s1', 'start_end.p4')
net.setP4Source('s2', 'middle.p4')
net.setP4Source('s3', 'middle.p4')
net.setP4Source('s4', 'fstart_end.p4')
net.setP4Source('s5', 'middle.p4')

net.addHost('h1')
net.addHost('h2')
net.addHost('h3')
net.addHost('h4')

net.addLink('h1','s1')
net.setIntfPort('s1', 'h1', 1)
net.addLink('h3','s1')
net.setIntfPort('s1', 'h3', 2)
net.addLink('s1','s2')
net.setIntfPort('s1', 's2', 3)
net.setIntfPort('s2', 's1', 1)
net.addLink('s2','s3')
net.setIntfPort('s2', 's3', 2)
net.setIntfPort('s3', 's2', 1)
net.addLink('s3','s4')
net.setIntfPort('s3', 's4', 2)
net.setIntfPort('s4', 's3', 1)
net.addLink('s2','s5')
net.setIntfPort('s2', 's5', 3)
net.setIntfPort('s5', 's2', 1)
net.addLink('s3','s5')
net.setIntfPort('s3', 's5', 3)
net.setIntfPort('s5', 's3', 2)
net.addLink('h2','s4')
net.setIntfPort('s4', 'h2', 3)
net.addLink('h4','s4')
net.setIntfPort('s4', 'h4', 2)
# Assignment strategy
net.mixed()

# Nodes general options
net.enablePcapDumpAll()
net.enableLogAll()

# Start network
net.startNetwork()
