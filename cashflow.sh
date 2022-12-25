nocolor='\033[0m'
red='\033[0;31m'
orange='\033[0;33m'
blue='\033[0;34m'

function process() {
    inp=$1
    out=$2
    provider=$3

    python main.py $inp $out --processor $provider
}

function or_fail() {
    local error_code=$1
    local command_output=$2
    local message=$3

    if [ $error_code -eq 0 ]; then
        printf "OK\n"
    else
        printf "FAILED\n"
        printf "${red}ERR${nocolor}: $message\n"
        printf "$command_output\n"
        exit 1
    fi
}

function scan_input() {
    name=$1
    data_dir=$2

    ls "${data_dir}" | grep "${name}" | grep -v processed
}

function extract_provider() {
    file_name=$1

    echo $file_name | cut -d '.' -f 2
}

function make_output_file_name() {
    name=$1
    provider=$2

    echo "${name}.${provider}.processed.csv"
}

function info() {
    printf "${blue}INFO${nocolor}: $1\n"
}

function warn() {
    printf "${orange}WARN${nocolor}: $1\n"
}

function error() {
    printf "${red}ERR${nocolor}: $1\n"
}

function parse_args() {
    positional_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force=true
                shift # past argument
                ;;
            --notion-token)
                notion_token=$2
                shift
                shift
                ;;
            --notion-url)
                notion_url=$2
                shift
                shift
                ;;
            --data-dir)
                data_dir=$2
                shift
                shift
                ;;
            --debug)
                debug=true
                shift
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
    data_dir=${data_dir:-${DATA_DIR:-"data"}}
    name=${1:-$NAME}

    if [ ! -z "$debug" ]; then
        echo "notion_token: $notion_token"
        echo "notion_url: $notion_url"
        echo "data_dir: $data_dir"
        echo "name: $name"
    fi

    available_processors="intesa vivid revolut"

    printf "Scanning for input files... "

    input_files=$(scan_input $name $data_dir)
    n_files=$(echo $input_files | wc -w)

    printf "OK (${n_files} files found)\n"

    if [ $n_files -eq 0 ]; then
        info "no input files found for name '$name'"
        exit 0
    fi

    printf "Processing files... "

    for input_file in ${input_files}; do
        output_file=$(make_output_file_name $name $provider)
        inp=$data_dir/$input_file
        out=$data_dir/$output_file

        provider=$(extract_provider $input_file)

        if [ -z "$provider" ]; then
            printf "FAILED\n"
            error "failed to extract provider from file name '$input_file'"
            exit 1
        fi

        if [[ ! $available_processors =~ (^|[[:space:]])$provider($|[[:space:]]) ]]; then
            printf "FAILED\n"
            error "provider '$provider' is not supported"
            exit 1
        fi

        cmd_output=$(( process $inp $out $provider ) 2>&1)

        if [ $? -ne 0 ]; then
            printf "FAILED\n"
            error "failed processing $inp with provider $provider"
            printf "$cmd_output\n"
            exit 1
        fi
    done
    printf "OK\n"

    if [ -z "$force" ]; then
        printf "${orange}By continuing you will upload processed data to notion. Are you sure? [y/N] ${nocolor}"
        read -r answer

        if [ "$answer" != "y" ]; then
            exit 0
        fi
    fi

    printf "Uploading to notion... "
    for input_file in ${input_files}; do
        output_file=$(make_output_file_name $name $provider)
        inp=$data_dir/$input_file
        out=$data_dir/$output_file

        cmd_output=$(csv2notion --token "${notion_token}" --url "${notion_url}" --merge --add-missing-relations ${out})

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
