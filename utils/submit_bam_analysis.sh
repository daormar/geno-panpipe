# *- bash -*

########
print_desc()
{
    echo "submit_bam_analysis performs analyses given normal and tumor bam files"
    echo "type \"submit_bam_analysis --help\" to get usage information"
}

########
usage()
{
    echo "submit_bam_analysis       -r <string> -n <string> -t <string> -o <string>"
    echo "                          -a <int> [-c <int>] [-m <int>]"
    echo "                          [-debug] [--help]"
    echo ""
    echo "-r <string>               File with reference genome."
    echo "-n <string>               File with normal bam."
    echo "-t <string>               File with tumor bam."
    echo "-o <string>               Output directory."
    echo "-a <int>                  Analysis type:"
    echo "                           1 -> Basic analysis (Manta, Strelka2 and MSIsensor)"
    echo "                           2 -> Complementary analysis (CNVkit)"
    echo "-c <int>                  Number of CPUs used to execute each analysis"
    echo "                          (default: 1)."
    echo "                          NOTE: only 1 CPU will be used for those analyses not"
    echo "                                allowing more than one thread."
    echo "-m <int>                  Memory in MBs used to execute the different analyses"
    echo "                          (default: 1024MB)."
    echo "-debug                    After ending, do not delete temporary files"
    echo "                          (for debugging purposes)."
    echo "--help                    Display this help and exit."
}

########
init_bash_shebang_var()
{
    echo "#!${BASH}"
}

########
exclude_readonly_vars()
{
    $AWK -F "=" 'BEGIN{
                         readonlyvars["BASHOPTS"]=1
                         readonlyvars["BASH_VERSINFO"]=1
                         readonlyvars["EUID"]=1
                         readonlyvars["PPID"]=1
                         readonlyvars["SHELLOPTS"]=1
                         readonlyvars["UID"]=1
                        }
                        {
                         if(!($1 in readonlyvars)) printf"%s\n",$0
                        }'
}

########
exclude_bashisms()
{
    $AWK '{if(index($1,"=(")==0) printf"%s\n",$0}'
}

########
write_functions()
{
    for f in `$AWK '{if(index($1,"()")!=0) printf"%s\n",$1}' $0`; do
        sed -n /^$f/,/^}/p $0
    done
}

########
create_script()
{
    # Init variables
    local_name=$1
    local_command=$2

    # Save previous file (if any)
    if [ -f ${local_name} ]; then
        cp ${local_name} ${local_name}.previous
    fi
    
    # Write bash shebang
    echo ${BASH_SHEBANG} > ${local_name}

    # Write SLURM commands
    echo "#SBATCH --job-name=${local_command}" >> ${local_name}
    echo "#SBATCH --output=${outd}/${local_command}.out" >> ${local_name}

    # Write environment variables
    set | exclude_readonly_vars | exclude_bashisms >> ${local_name}

    # Write functions if necessary
    $GREP "()" ${local_name} -A1 | $GREP "{" > /dev/null || write_functions >> ${local_name}
    
    # Write command to be executed
    echo "${local_command}" >> ${local_name}

    # Give execution permission
    chmod u+x ${local_name}

    # Archive script with date info
    curr_date=`date '+%Y_%m_%d'`
    cp ${local_name} ${local_name}.${curr_date}
}

########
launch()
{
    local_file=$1
    local_cpus=$2
    local_mem=$3
    
    if [ -z "${SBATCH}" ]; then
        $local_file
    else
        $SBATCH --cpus-per-task=${local_cpus} --mem=${local_mem} $local_file
    fi
}

########
read_pars()
{
    r_given=0
    n_given=0
    t_given=0
    o_given=0
    a_given=0
    c_given=0
    cpus=1
    m_given=0
    mem=1024
    debug=0
    while [ $# -ne 0 ]; do
        case $1 in
            "--help") usage
                      exit 1
                      ;;
            "--version") version
                         exit 1
                         ;;
            "-r") shift
                  if [ $# -ne 0 ]; then
                      ref=$1
                      r_given=1
                  fi
                  ;;
            "-n") shift
                  if [ $# -ne 0 ]; then
                      normalbam=$1
                      n_given=1
                  fi
                  ;;
            "-t") shift
                  if [ $# -ne 0 ]; then
                      tumorbam=$1
                      t_given=1
                  fi
                  ;;
            "-o") shift
                  if [ $# -ne 0 ]; then
                      outd=$1
                      o_given=1
                  fi
                  ;;
            "-a") shift
                  if [ $# -ne 0 ]; then
                      atype=$1
                      a_given=1
                  fi
                  ;;
            "-c") shift
                  if [ $# -ne 0 ]; then
                      cpus=$1
                      c_given=1
                  fi
                  ;;
            "-m") shift
                  if [ $# -ne 0 ]; then
                      mem=$1
                      m_given=1
                  fi
                  ;;
            "-debug") debug=1
                      debug_opt="-debug"
                      ;;
        esac
        shift
    done   
}

########
check_pars()
{
    if [ ${r_given} -eq 0 ]; then   
        echo "Error! -r parameter not given!" >&2
        exit 1
    else
        if [ ! -f ${ref} ]; then
            echo "Error! file ${ref} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${n_given} -eq 0 ]; then   
        echo "Error! -n parameter not given!" >&2
        exit 1
    else
        if [ ! -f ${normalbam} ]; then
            echo "Error! file ${normalbam} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${t_given} -eq 0 ]; then
        echo "Error! -t parameter not given!" >&2
        exit 1
    else
        if [ ! -f ${tumorbam} ]; then
            echo "Error! file ${tumorbam} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${o_given} -eq 0 ]; then
        echo "Error! -o parameter not given!" >&2
        exit 1
    else
        if [ -d ${outd} ]; then
            echo "Warning! output directory does exist" >&2 
        fi
    fi

    if [ ${a_given} -eq 0 ]; then   
        echo "Error! -a parameter not given!" >&2
        exit 1
    fi
}

########
create_dirs()
{
    mkdir -p ${outd} || { echo "Error! cannot create output directory" >&2; return 1; }

    mkdir -p ${outd}/scripts || { echo "Error! cannot create scripts directory" >&2; return 1; }
}

########
get_step_dirname()
{
    local_stepname=$1
    echo ${outd}/${local_stepname}
}

########
get_step_status()
{
    local_stepname=$1
    local_outd=`get_step_dirname ${local_stepname}`
    
    if [ -d ${local_outd} ]; then
        if [ -f ${local_outd}/finished ]; then
            echo "FINISHED"
        else
            echo "UNFINISHED"
        fi
    else
        echo "TO-DO"
    fi
}

########
reset_outdir_for_step() 
{
    local_stepname=$1
    local_outd=`get_step_dirname ${local_stepname}`

    if [ -d ${local_outd} ]; then
        echo "Warning: ${local_stepname} output directory already exists but analysis was not finished, directory content will be removed">&2
        rm -rf ${local_outd}/* || { echo "Error! could not clear output directory" >&2; return 1; }
    else
        mkdir ${local_outd} || { echo "Error! cannot create output directory" >&2; return 1; }
    fi
}

########
execute_manta()
{
    # Initialize variables
    MANTA_OUTD=`get_step_dirname ${stepname}`

    # Activate conda environment
    conda activate manta
    
    # Configure Manta
    configManta.py --normalBam ${normalbam} --tumorBam ${tumorbam} --referenceFasta ${ref} --runDir ${MANTA_OUTD} > ${MANTA_OUTD}/configManta.log 2>&1 || exit 1

    # Execute Manta
    ${MANTA_OUTD}/runWorkflow.py -m local -j ${cpus} > ${MANTA_OUTD}/runWorkflow.log 2>&1 || exit 1

    # Create file indicating that execution was finished
    touch ${MANTA_OUTD}/finished
}

########
execute_strelka()
{
    # Initialize variables
    STRELKA_OUTD=`get_step_dirname ${stepname}`

    # Activate conda environment
    conda activate strelka

    # Configure Strelka
    configureStrelkaSomaticWorkflow.py --normalBam ${normalbam} --tumorBam ${tumorbam} --referenceFasta ${ref} --runDir ${STRELKA_OUTD} > ${STRELKA_OUTD}/configureStrelkaSomaticWorkflow.log 2>&1 || exit 1

    # Execute Strelka
    ${STRELKA_OUTD}/runWorkflow.py -m local -j ${cpus} > ${STRELKA_OUTD}/runWorkflow.log 2>&1 || exit 1
    
    # Create file indicating that execution was finished
    touch ${STRELKA_OUTD}/finished
}

########
execute_msisensor()
{
    # Initialize variables
    MSISENSOR_OUTD=`get_step_dirname ${stepname}`
    
    # Activate conda environment
    conda activate msisensor

    # Create homopolymer and microsatellites file
    msisensor scan -d ${ref} -o ${MSISENSOR_OUTD}/msisensor.list > ${MSISENSOR_OUTD}/msisensor_scan.log 2>&1 || exit 1

    # Run MSIsensor analysis
    msisensor msi -d ${MSISENSOR_OUTD}/msisensor.list -n ${normalbam} -t ${tumorbam} -o ${MSISENSOR_OUTD}/output -l 1 -q 1 -b ${cpus} > ${MSISENSOR_OUTD}/msisensor_msi.log 2>&1 || exit 1
    
    # Create file indicating that execution was finished
    touch ${MSISENSOR_OUTD}/finished
}

########
execute_cnvkit()
{
    # Initialize variables
    CNVKIT_OUTD=`get_step_dirname ${stepname}`
    
    # Activate conda environment
    conda activate cnvkit

    # Run cnvkit
    cnvkit.py batch ${tumorbam} -n ${normalbam} -m wgs -f ${ref}  -d ${CNVKIT_OUTD} -p ${cpus} > ${CNVKIT_OUTD}/cnvkit.log 2>&1 || exit 1

    # Create file indicating that execution was finished
    touch ${CNVKIT_OUTD}/finished
}

########
execute_step()
{
    # Initialize variables
    local_stepname=$1
    local_cpus=$2
    local_mem=$3

    # Execute step
    create_script ${outd}/scripts/execute_${local_stepname} execute_${local_stepname}
    status=`get_step_status "${local_stepname}"`
    echo "STEP: ${local_stepname} ; STATUS: ${status}" >&2
    if [ "$status" != "FINISHED" ]; then
        reset_outdir_for_step ${local_stepname} || exit 1
        launch ${outd}/scripts/execute_${local_stepname} ${local_cpus} ${local_mem}
    fi
}

########
perform_basic_analysis()
{
    # Execute Manta
    stepname="manta"
    execute_step ${stepname} ${cpus} ${mem}

    # Execute Strelka
    stepname="strelka"
    execute_step ${stepname} ${cpus} ${mem}

    # Execute MSIsensor
    stepname="msisensor"
    execute_step ${stepname} ${cpus} ${mem}
}

########
perform_compl_analysis()
{
    # Execute CNVkit
    stepname="cnvkit"
    execute_step ${stepname} ${cpus} ${mem}
}

########
process_pars()
{
    case ${atype} in
        "1") perform_basic_analysis
             ;;
        "2") perform_compl_analysis
             ;;
    esac
}

########

if [ $# -eq 0 ]; then
    print_desc
    exit 1
fi

read_pars $@ || exit 1

check_pars || exit 1

create_dirs || exit 1

BASH_SHEBANG=`init_bash_shebang_var`

process_pars
