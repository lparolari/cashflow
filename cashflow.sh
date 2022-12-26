nocolor='\033[0m'
red='\033[0;31m'
orange='\033[0;33m'
blue='\033[0;34m'
darkgrey='\033[1;30m'

available_providers="intesa vivid revolut"


function process() {
    local inp=$1
    local out=$2
    local provider=$3

    python main.py $inp $out --processor $provider
}

function scan_input() {
    local file=$1

    if [ -f "$file" ]; then
        echo "$file"
        return
    fi

    if [ -d "$file" ]; then
        find "${file}" -maxdepth 1 -type f -regex ".*\(csv\)"
        return
    fi

    find . -type f -regex ".*${file}.*\(csv\)"
}

function extract_provider() {
    local file=$1
    local basename=$(basename $file)
    
    for provider in $available_providers; do
        if [[ $basename == *$provider* ]]; then
            echo $provider
            return
        fi
    done

    echo ""
}

function make_processed_filepath() {
    local file=$1
    local basename=$(basename $file)
    local processed=$(echo $basename | sed 's/\./_processed./')

    if [ -z "$tmp_dir" ]; then
        echo "${processed}"
        return
    fi

    echo "${tmp_dir}/${processed}"
}

function info() {
    printf "${blue}INFO${nocolor}: $1\n" >&2
}

function warn() {
    printf "${orange}WARN${nocolor}: $1\n" >&2
}

function error() {
    printf "${red}ERR${nocolor}: $1\n" >&2
}

function debug() {
    if [ ! -z "$debug" ]; then
        printf "${darkgrey}DEBUG${nocolor}: $1\n" >&2
    fi  
}

function show_help() {
    printf "Usage: $0 [OPTION]... INPUT\n"
    printf "Import transaction in Notion cashflow and budget manager\n"
    printf "\n"
    printf "Starting from bank statements in CSV format this script generates processed\n"
    printf "transactions with a category and a budget item. Then, imports data into\n"
    printf "cashflow and budget manager in notion.\n"
    printf "Currently supported bank statements are: intesa, vivid, revolut.\n"
    printf "\n"
    printf "  -t, --notion-token   token for notion APIs\n"
    printf "  -u, --notion-url     url representing a notion database\n"
    printf "  -o, --tmp-dir        directory where processed file are saved\n"
    printf "  -p  --processor      processor for input files\n"
    printf "  -f, --force          force notion upload without confirmation prompt\n"
    printf "  -d, --debug          show debug information\n"
    printf "  -h, --help           display this help and exit\n"
}

function parse_args() {
    positional_args=()

    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force=true
                shift # past argument
                ;;
            -t|--notion-token)
                notion_token=$2
                shift
                shift
                ;;
            -u|--notion-url)
                notion_url=$2
                shift
                shift
                ;;
            -o|--tmp-dir)
                tmp_dir=$2
                shift
                shift
                ;;
            -p|--processor)
                processor=$2
                shift
                shift
                ;;
            -d|--debug)
                debug=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*|--*)
                error "Unknown option $1"
                exit 1
                ;;
            *)
                positional_args+=("$1") # save positional arg
                shift
            ;;
        esac
    done
}

function main() {
    if [ ! -f .env ]; then
        $(cat .env | xargs)
    fi

    parse_args $@
    set -- "${positional_args[@]}" # restore positional parameters

    notion_token=${notion_token:-$NOTION_TOKEN}
    notion_url=${notion_url:-$NOTION_URL}
    file=${1:-$FILE}
    tmp_dir=${tmp_dir:-${TMP_DIR:-"/tmp"}}
    processor=${processor:-${PROCESSOR}}

    info "you may hide logs by redirecting stderr to /dev/null with \`cashflow.sh 2>/dev/null\`"

    debug "notion_token: $notion_token"
    debug "notion_url: $notion_url"
    debug "file: $file"
    debug "processor: $processor"
    debug "tmp dir: $tmp_dir"

    if [ ! -d "$tmp_dir" ]; then
        mkdir -p $tmp_dir
        info "created tmp directory '$tmp_dir'"
    fi
    
    printf "Scanning for input files... "

    input_files=$(scan_input $file)
    n_files=$(echo $input_files | wc -w)

    printf "OK (${n_files} files found)\n"

    if [ $n_files -eq 0 ]; then
        info "$file is empty"
        exit 0
    fi

    printf "Processing files... "

    for input_file in ${input_files}; do
        inp=$input_file
        out=$(make_processed_filepath $input_file)

        provider=$(extract_provider $input_file)

        if [ -z "$provider" ]; then
            if [ -z "$processor" ]; then
                printf "\rProcessing files... FAILED\n"
                error "could not infer processor from file name, please specify a processor"
                exit 1
            fi
        fi

        provider=${processor:-$provider}

        if [ -f "$out" ]; then
            printf "\r"
            warn "output file '$out' already exists, overwriting"
        fi

        cmd_output=$(( process $inp $out $provider ) 2>&1)

        if [ $? -ne 0 ]; then
            printf "\rProcessing files... FAILED\n"
            error "failed processing $inp with provider $provider"
            printf "$cmd_output\n" >&2
            exit 1
        fi
    done
    printf "\rProcessing files... OK\n"

    if [ -z "$force" ]; then
        printf "${orange}If you proceed, processed file will be uploaded. Continue? [y/N] ${nocolor}"
        read -r answer

        if [ "$answer" != "y" ]; then
            exit 0
        fi
    fi

    printf "Uploading to notion... "
    for input_file in ${input_files}; do
        output_file=$(make_processed_filepath $input_file)
        inp=$input_file
        out=$output_file

        if ! command -v csv2notion &> /dev/null 2>&1
        then
            printf "FAILED\n"
            error "csv2notion is not installed, please install it with \`pip install csv2notion\`"
            exit 1
        fi

        cmd_output=$(csv2notion --token "${notion_token}" --url "${notion_url}" --merge --add-missing-relations ${out} 2>&1)

        if [ $? -ne 0 ]; then
            printf "FAILED\n"
            error "failed uploading $out to notion"
            printf "$cmd_output\n"
            exit 1
        fi
    done
    printf "OK\n"
}

main $@
