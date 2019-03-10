# *- bash -*

# INCLUDE BASH LIBRARY
. ${PANPIPE_HOME_DIR}/bin/panpipe_lib || exit 1

########
print_desc()
{
    echo "create_genref_for_bam create genome reference specific for bam file"
    echo "type \"create_genref_for_bam --help\" to get usage information"
}

########
usage()
{
    echo "create_genref_for_bam  -r <string> -b <string> [-cm <string>]"
    echo "                       -o <string> [--help]"
    echo ""
    echo "-r <string>            File with base reference genome"
    echo "-b <string>            bam file"
    echo "-cm <string>           File containing a mapping between contig names and"
    echo "                       accession numbers or file names (when the mapping"
    echo "                       starts with a '/' character, it is considered a"
    echo "                       file, hence, absolute paths should be given)"
    echo "-o <string>            Output directory"
    echo "--help                 Display this help and exit"
}

########
read_pars()
{
    r_given=0
    b_given=0
    cm_given=0
    contig_mapping=${NOFILE}
    o_given=0
    while [ $# -ne 0 ]; do
        case $1 in
            "--help") usage
                      exit 1
                      ;;
            "-r") shift
                  if [ $# -ne 0 ]; then
                      baseref=$1
                      r_given=1
                  fi
                  ;;
            "-b") shift
                  if [ $# -ne 0 ]; then
                      bam=$1
                      b_given=1
                  fi
                  ;;
            "-cm") shift
                  if [ $# -ne 0 ]; then
                      contig_mapping=$1
                      cm_given=1
                  fi
                  ;;
            "-o") shift
                  if [ $# -ne 0 ]; then
                      outd=$1
                      o_given=1
                  fi
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
        if [ ! -f ${baseref} ]; then
            echo "Error! file ${baseref} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${b_given} -eq 0 ]; then   
        echo "Error! -b parameter not given!" >&2
        exit 1
    else
        if [ ! -f ${bam} ]; then
            echo "Error! file ${bam} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${cm_given} -eq 1 ]; then   
        if [ ! -f ${contig_mapping} ]; then
            echo "Error! file ${contig_mapping} does not exist" >&2
            exit 1
        fi
    fi

    if [ ${o_given} -eq 0 ]; then   
        echo "Error! -o parameter not given!" >&2
        exit 1
    else
        if [ ! -d ${outd} ]; then
            echo "Error! directory ${outd} does not exist" >&2
            exit 1
        fi
    fi
}

########
print_pars()
{
    if [ ${r_given} -eq 1 ]; then
        echo "-r is ${baseref}" >&2
    fi

    if [ ${b_given} -eq 1 ]; then
        echo "-b is ${bam}" >&2
    fi

    if [ ${cm_given} -eq 1 ]; then
        echo "-cm is ${contig_mapping}" >&2
    fi

    if [ ${o_given} -eq 1 ]; then
        echo "-o is ${outd}" >&2
    fi
}

########
contig_in_list()
{
    local contig=$1
    local clist=$2

    while read cname clen; do
        if [ "$contig" = "$cname" ]; then
            return 0
        fi
    done < ${clist}

    return 1
}

########
extract_contig_info_from_fai()
{
    local faifile=$1
    $AWK '{printf "%s %s\n",$1,$2}' ${faifile}
}

########
get_ref_contig_names()
{
    local ref=$1

    samtools faidx ${baseref} || return 1
    extract_contig_info_from_fai ${baseref}.fai
}

########
get_bam_contig_names()
{
    local bam=$1

    samtools view -H $bam | $AWK '{if($1=="@SQ") printf "%s %s\n",substr($2,4),substr($3,4)}'
}

########
get_missing_contig_names()
{
    local refcontigs=$1
    local bamcontigs=$2
            
    while read bamcontigname contiglen; do
        if ! contig_in_list $bamcontigname $refcontigs; then
            echo $bamcontigname $contiglen
        fi
    done < $bamcontigs    
}

########
get_ref_contig_names_to_keep()
{
    local refcontigs=$1
    local bamcontigs=$2
            
    while read refcontigname contiglen; do
        if contig_in_list $refcontigname $bamcontigs; then
            echo $refcontigname $contiglen
        fi
    done < $refcontigs    
}

########
contig_is_accession()
{
    local contig=$1

    if [[ $contig == *"."* ]]; then
        return 0
    else
        return 1
    fi
}

########
map_contig_using_file()
{
    local contig_mapping=$1
    local contig=$2

    while read entry; do
        local fields=($entry)
        local num_fields=${#fields[@]}
        if [ ${num_fields} -eq 2 ]; then
            if [ ${fields[0]} = $contig ]; then
                echo ${fields[1]}
                break
            fi
        fi
    done < ${contig_mapping}
}

########
map_contig()
{
    local contig_mapping=$1
    local contig=$2

    if contig_is_accession ${contig}; then
        echo ${contig}
    else
        if [ ${contig_mapping} != "${NOFILE}" ]; then
            map_contig_using_file ${contig_mapping} ${contig} || return 1
        fi
    fi
}

########
get_contigs()
{
    local contig_mapping=$1
    local contiglist=$2

    while read contig contiglen; do
        local mapping=`map_contig ${contig_mapping} ${contig}` || return 1
        if [ "$mapping" = "" ]; then
            echo "Error: contig $contig is not a valid accession nor there were mappings for it" >&2
            return 1
        else
            echo "Getting data for contig ${contig} (mapped to $mapping)..." >&2
            # Determine whether the mapping is an accession number of a
            # file name (absolute file paths should be given)
            if is_absolute_path ${mapping}; then
                cat ${mapping} || return 1
            else
                ${biopanpipe_bindir}/get_entrez_fasta -a ${mapping} | ${SED} "s/${mapping}/${contig}/"; pipe_fail || return 1
            fi
        fi
    done < ${contiglist}
}

########
get_uniq_contigs()
{
    local cfile1=$1
    local cfile2=$2

    ${SORT} $cfile1 $cfile2 | ${UNIQ} -u
}

########
process_pars()
{
    outfile=$outd/genref_for_bam.fa
    
    # Activate conda environment
    echo "* Activating conda environment (samtools)..." >&2
    conda activate samtools || exit 1

    # Get reference contigs
    echo "* Obtaining list of current reference contig names..." >&2
    get_ref_contig_names $baseref > ${outd}/refcontigs

    # Get bam contigs
    echo "* Obtaining list of bam contig names and their lengths..." >&2
    get_bam_contig_names $bam > ${outd}/bamcontigs
    
    # Obtain list of contigs to keep in the reference file
    echo "* Obtaining list of reference contigs to keep..." >&2
    get_ref_contig_names_to_keep ${outd}/refcontigs ${outd}/bamcontigs > ${outd}/refcontigs_to_keep || exit 1

    # Copy base genome reference without extra contigs
    echo "* Copying base genome reference without extra contigs..." >&2
    ${biopanpipe_bindir}/filter_contig_from_genref -g $baseref -l ${outd}/refcontigs_to_keep > $outfile

    # Obtain list of missing contigs
    echo "* Obtaining list of missing contigs..." >&2
    get_missing_contig_names ${outd}/refcontigs_to_keep ${outd}/bamcontigs > ${outd}/missing_contigs || exit 1

    # Enrich reference
    echo "* Enriching reference..." >&2
    get_contigs ${contig_mapping} ${outd}/missing_contigs >> $outfile || { echo "Error during FASTA data downloading" >&2; exit 1; }

    # Index created reference
    echo "* Indexing created reference..." >&2
    samtools faidx ${outfile} || exit 1
    extract_contig_info_from_fai ${outfile}.fai > ${outd}/created_ref_contigs

    # Check created reference
    echo "* Checking created reference..." >&2
    get_uniq_contigs ${outd}/bamcontigs ${outd}/created_ref_contigs > ${outd}/uniq_contigs
    num_uniq_contigs=`$WC -l ${outd}/uniq_contigs | $AWK '{print $1}'`
    if [ ${num_uniq_contigs} -gt 0 ]; then
        echo "Bam file and created genome reference do not have the exact same contigs (see ${outd}/uniq_contigs file)" >&2
        exit 1
    fi
    
    # Deactivate conda environment
    echo "* Deactivating conda environment..." >&2
    conda deactivate
}

########

if [ $# -eq 0 ]; then
    print_desc
    exit 1
fi

read_pars $@ || exit 1

check_pars || exit 1

print_pars || exit 1

process_pars || exit 1
