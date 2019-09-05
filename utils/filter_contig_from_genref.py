# *- python -*

# import modules
import io, sys, getopt, operator

##################################################
def take_pars():
    flags={}
    values={}
    flags["g_given"]=False
    flags["r_given"]=False
    flags["k_given"]=False
    flags["l_given"]=False

    try:
        opts, args = getopt.getopt(sys.argv[1:],"g:r:k:l:",["genref=","contigrem=","contigkeep","listc="])
    except getopt.GetoptError:
        print_help()
        sys.exit(2)
    if(len(opts)==0):
        print_help()
        sys.exit()
    else:
        for opt, arg in opts:
            if opt in ("-g", "--genref"):
                values["genref"] = arg
                flags["g_given"]=True
            elif opt in ("-r", "--contigrem"):
                values["contigrem"] = arg
                flags["r_given"]=True
            elif opt in ("-k", "--contigkeep"):
                values["contigkeep"] = arg
                flags["k_given"]=True
            elif opt in ("-l", "--listc"):
                values["listc"] = arg
                flags["l_given"]=True
    return (flags,values)

##################################################
def check_pars(flags,values):
    if(flags["g_given"]==False):
        print >> sys.stderr, "Error! -g parameter not given"
        sys.exit(2)

    # Check mutually exclusive options
    num_simul=0
    if(flags["r_given"]):
        num_simul = num_simul + 1
    if(flags["k_given"]):
        num_simul = num_simul + 1
    if(flags["l_given"]):
        num_simul = num_simul + 1

    if num_simul==0:
        print >> sys.stderr, "Error! -r, -k or -l parameter not given"
        sys.exit(2)
    elif num_simul>1:
        print >> sys.stderr, "Error! -r, -k or -l cannot be given simultaneously"
        sys.exit(2)

##################################################
def print_help():
    print >> sys.stderr, "filter_contig_from_genref -g <string> {-r <string> | -k <string> | -l <string>}"
    print >> sys.stderr, ""
    print >> sys.stderr, "-g <string>    File with genome reference"
    print >> sys.stderr, "-r <string>    Name of contig to remove"
    print >> sys.stderr, "-k <string>    Name of contig to keep"
    print >> sys.stderr, "-l <string>    File with list of contigs to keep (one contig name per line)"

##################################################
def getContigsToKeep(listc):
    file = open(listc, 'r')
    contigs_to_keep={}
    for line in file:
        line=line.strip("\n")
        fields=line.split()
        contigs_to_keep[fields[0]]=1
    return contigs_to_keep
    
##################################################
def process_pars(flags,values):
    # Initialize variables
    if(flags["r_given"]):
        contig_to_filter=values["contigrem"]
    else:
        contig_to_filter=""
        
    if(flags["l_given"]):
        contigs_to_keep=getContigsToKeep(values["listc"])
    elif(flags["k_given"]):
        contigs_to_keep=values["contigkeep"]
    else:
        contigs_to_keep=None

    # Filter genome
    file = open(values["genref"], 'r')
    skip=False
    # read file line by line
    for line in file:
        line=line.strip("\n")
        fields=line.split()
        if(len(fields) > 0 and ">" in fields[0]):
            contigname=fields[0][1:]
            if(contigname==contig_to_filter or (contigs_to_keep is not None and not contigname in contigs_to_keep)):
                skip=True
            else:
                skip=False
            
        if(not skip):
            print line
                                   
##################################################
def main(argv):
    # take parameters
    (flags,values)=take_pars()

    # check parameters
    check_pars(flags,values)

    # process parameters
    process_pars(flags,values)
    
if __name__ == "__main__":
    main(sys.argv)
