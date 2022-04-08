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

def usage():
    print("Usage: "+sys.argv[0]+" [-h] -p <REMOTE_HOME_DIR> -i <VM_IP> -n <CLUSTER_NAME> -t <TCE_VERSION> -r <TKR_VERSION> -k <K8S_PORT>")
    print(''' 
-p --path : (Remote) home directory (e.g /home/snowdrop)
-i --ip   : IP address of the machine or remote VM (e.g 65.108.148.216)
-n --name : TCE Cluster name (e.g toto)
-t --tce  : TCE Version (e.g: v0.11.0)
-r --tkr  : TKE (Kubernetes) Version (e.g: v1.22.5)
-k --port : Kubernetes API Port (e.g: 31452)
-h --help : This help.
''')

def main(argv):
    remoteHomeDir = vmIP = clusterName = ''
    tceVersion = "v0.11.0"
    tkrVersion = "v1.22.5"
    remoteK8sPort = "31452"

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
    print(f'{GREEN} (remote)home dir is: {remoteHomeDir}')
    # curl -H "Accept: application/vnd.github.v3.raw" \
    #     -L https://api.github.com/repos/vmware-tanzu/community-edition/contents/hack/get-tce-release.sh | \
    #     bash -s $TCE_VERSION linux

    subprocess.run(["ls", "-l"])

    end = time.time()
    elapsed = end - start
    converted = time.strftime("%Mm:%Ss", time.gmtime(elapsed))
    print(f'{GREEN} Elapsed: {converted}')

if __name__ == "__main__":
    main(sys.argv[1:])