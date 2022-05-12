import os
import sys, getopt, time, subprocess

# Defining some colors
RED     = '\033[0;31m'
NC      = '\033[0m' # No Color
YELLOW  = '\033[0;33m'
GREEN   = '\033[0;32m'
BLUE    = '\033[0;34m'
MAGENTA = '\033[0;35m'
CYAN    = '\033[0;36m'
WHITE   = '\033[0;37m'

def log_msg(color, msg):
    msgLength = len(msg) + 6
    header = "#" * msgLength
    print(f'{color} {header}')
    print(f'{color} ## {msg} ##')
    print(f'{color} {header}')

def log_result(color, result):
    print(f'{color} ## {result}')

def usage():
    print("Usage: "+sys.argv[0]+" [-h] -p <REMOTE_HOME_DIR> -i <VM_IP> -n <CLUSTER_NAME> -t <TCE_VERSION> -r <TKR_VERSION> -k <K8S_PORT>")
    print(''' 
-p --path : (Remote) home directory (e.g /home/snowdrop)
-i --ip   : IP address of the machine or remote VM (e.g 65.108.148.216)
-n --name : TCE Cluster name (e.g toto)
-t --tce  : TCE Version (e.g: v0.12.0)
-r --tkr  : TKE (Kubernetes) Version (e.g: v1.22.5)
-k --port : Kubernetes API Port (e.g: 31452)
-h --help : This help.
''')

def main(argv):
    remoteHomeDir = vmIP = clusterName = ''
    tceVersion = "v0.12.0"
    tkrVersion = "v1.22.5"
    remoteK8sPort = "31452"
    tceDir = ''

    try:
        opts, args = getopt.getopt(argv, "hp:i:n:trk",["dir=","ip=","name=","tce=","tkr=","port="])
    except getopt.error:
        usage()
        exit(2)

    for opt, arg in opts:
        if opt in ('-h', '--help'):
            usage()
            exit(2)
        elif opt in ("-p", "--path"):
            remoteHomeDir = arg
            tceDir = remoteHomeDir + "/tce"
        elif opt in ("-i", "--ip"):
            vmIP = arg
        elif opt in ("-n", "--name"):
            clusterName = arg
        elif opt in ("-t", "--tce"):
            tceVersion = arg
        elif opt in ("-r", "--tkr"):
            tkrVersion = arg
        elif opt in ("-k", "--port"):
            remoteK8sPort = arg

    start = time.time()
    print(f'{GREEN} (remote)home dir    : {remoteHomeDir}')
    print(f'{GREEN} VM IP               : {vmIP}')
    print(f'{GREEN} Cluster Name        : {clusterName}')
    print(f'{GREEN} TCE Version         : {tceVersion}')
    print(f'{GREEN} TKR Version         : {tkrVersion}')
    print(f'{GREEN} Kubernetes API port : {remoteK8sPort}')
    print(f'{GREEN} Temp TCE dir        : {tceDir}')

    log_msg(GREEN,f'Install the tanzu client version: {tceVersion}')
    cmd = f'curl -s -H "Accept: application/vnd.github.v3.raw" -L https://api.github.com/repos/vmware-tanzu/community-edition/contents/hack/get-tce-release.sh | bash -s {tceVersion} linux'
    log_result(GREEN,f'{ os.popen(cmd).read() }')

    #log_msg(GREEN,'Moving the tar.gz to the tce directory')
    #cmd = f'tce-linux-amd64-{tceVersion}.tar.gz'
    #log_result(GREEN,f'{ os.popen(cmd).read() }')

    #log_msg(GREEN,'Extracting the TCE Client tar.gz file')
    #cmd = f'tar xzvf {tceDir}/tce-linux-amd64-{tceVersion}.tar.gz -C {tceDir}/'
    #log_result(GREEN,f'{ os.popen(cmd).read() }')

    end = time.time()
    elapsed = end - start
    converted = time.strftime("%Mm:%Ss", time.gmtime(elapsed))
    print(f'{GREEN} Elapsed: {converted}')
    print(f'{NC} Job done !')

if __name__ == "__main__":
    main(sys.argv[1:])