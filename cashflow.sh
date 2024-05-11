nocolor='\033[0m'
red='\033[0;31m'
orange='\033[0;33m'
blue='\033[0;34m'
darkgrey='\033[1;30m'

available_statement_processors="intesa vivid revolut"
csv2notion_supported_backends="csv2notion csv2notion_neo"
csv2notion_default_backend="csv2notion"


function process_statement() {
    local inp=$1
    local out=$2
    local provider=$3
    
    if [ ! -z "$dev" ]; then
        poetry run statement_processor $inp $out --processor $provider
        return $?
    fi

    statement_processor $inp $out --processor $provider
}

function scan_statements() {
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

function extract_statement_processor() {
    local file=$1
    local basename=$(basename $file)
    
    for processor in $available_statement_processors; do
        if [[ $basename == *$processor* ]]; then
            echo $processor
            return
        fi
    done

    echo ""
}

function make_transaction_filepath() {
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
    printf "Options:\n"
    printf "  -t, --notion-token   token for notion APIs\n"
    printf "      --notion-transactions-database-url\n"
    printf "                       url to transactions database\n"
    printf "      --notion-budget-month-database-url\n"
    printf "                       url to budget month database\n"
    printf "      --notion-workspace\n"
    printf "                       workspace name in notion (e.g. John Doe's Notion)\n"
    printf "      --csv2notion-backend\n"
    printf "                       backend to use for uploading csv to notion\n"
    printf "                       available options are "csv2notion", "csv2notion_neo"\n"
    printf "                       default is "csv2notion"\n"
    printf "  -o, --tmp-dir        directory where processed file are saved\n"
    printf "  -f, --force          force notion upload without confirmation prompt\n"
    printf "  -d, --debug          show debug information\n"
    printf "      --dev            use poetry script instead of system installed cashflow\n"
    printf "                       and budget processor\n"
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
            --notion-transactions-database-url)
                notion_transactions_database_url=$2
                shift
                shift
                ;;
            --notion-budget-month-database-url)
                notion_budget_month_database_url=$2
                shift
                shift
                ;;
            --notion-workspace)
                notion_workspace=$2
                shift
                shift
                ;;
            --csv2notion-backend)
                csv2notion_backend=$2
                shift
                shift
                ;;
            -o|--tmp-dir)
                tmp_dir=$2
                shift
                shift
                ;;
            -d|--debug)
                debug=true
                shift
                ;;
            --dev)
                dev=true
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
    if [ -f .env ]; then
        export $(cat .env | xargs)
    fi

    parse_args $@
    set -- "${positional_args[@]}" # restore positional parameters

    notion_token=${notion_token:-$NOTION_TOKEN}
    notion_transactions_database_url=${notion_transactions_database_url:-$NOTION_TRANSACTIONS_DATABASE_URL}
    notion_budget_month_database_url=${notion_budget_month_database_url:-$NOTION_BUDGET_MONTH_DATABASE_URL}
    notion_workspace=${notion_workspace:-$NOTION_WORKSPACE}
    file=${1:-$FILE}
    tmp_dir=${tmp_dir:-${TMP_DIR:-"/tmp"}}
    csv2notion_backend=${csv2notion_backend:-$csv2notion_default_backend}

    info "you may hide logs by redirecting stderr to /dev/null with \`cashflow.sh 2>/dev/null\`"

    debug "notion_token: <secret>"
    debug "notion_transactions_database_url: $notion_transactions_database_url"
    debug "notion_budget_month_database_url: $notion_budget_month_database_url"
    debug "notion_workspace: $notion_workspace"
    debug "csv2notion_backend: $csv2notion_backend"
    debug "file: $file"
    debug "tmp dir: $tmp_dir"

    if [ -z "$notion_token" ]; then
        error "notion token is not set"
        printf "An error occurred. Notion v2 token not set\n"
        exit 1
    fi

    if [ -z "$notion_transactions_database_url" ]; then
        warn "notion transactions database url is not set"
        printf "An error occurred. Transactions database url not set\n"
        exit 1
    fi

    if [ -z "$notion_budget_month_database_url" ]; then
        warn "notion budget month database url is not set"
        printf "An error occurred. Budget items database url not set\n"
        exit 1
    fi

    if [ -z "$notion_workspace" ]; then
        error "notion workspace is not set"
        printf "An error occurred. Workspace not set\n"
        exit 1
    fi

    if [[ ! " ${csv2notion_supported_backends[@]} " =~ " ${csv2notion_backend} " ]]; then
        error "csv2notion backend '${csv2notion_backend}' is not supported"
        printf "An error occurred. Backend '${csv2notion_backend}' not supported\n"
        exit 1
    fi

    if ! command -v $csv2notion_backend &> /dev/null 2>&1
    then
        error "csv2notion backend '${csv2notion_backend}' is not installed, please install it with \`pip install ${csv2notion_backend}\`"
        printf "An error occurred. Backend '${csv2notion_backend}' not intalled\n"
        exit 1
    fi

    if [ ! -d "$tmp_dir" ]; then
        mkdir -p $tmp_dir
        info "created tmp directory '$tmp_dir'"
    fi
    
    printf "Scanning for statements... "

    statement_files=$(scan_statements $file)
    n_statements=$(echo $statement_files | wc -w)

    printf "OK (${n_statements} statements found)\n"

    if [ $n_statements -eq 0 ]; then
        info "$file is empty"
        printf "No statements found\n"
        exit 0
    fi

    printf "Processing statements... "

    for statement_file in ${statement_files}; do
        inp=$statement_file
        out=$(make_transaction_filepath $statement_file)

        processor=$(extract_statement_processor $statement_file)

        if [ -z "$processor" ]; then
            printf "\rProcessing statements... FAILED\n"
            error "could not infer processor from file name"
            exit 1
        fi

        if [ -f "$out" ]; then
            printf "\r"
            warn "output file '$out' already exists, overwriting"
        fi

        cmd_output=$(( process_statement $inp $out $processor ) 2>&1)

        if [ $? -ne 0 ]; then
            printf "\rProcessing statements... FAILED\n"
            error "failed processing $inp with processor $processor"
            printf "$cmd_output\n" >&2
            exit 1
        fi
    done
    printf "\rProcessing statements... OK\n"

    printf "${orange}YOU HAVE TO MANUALLY CREATE BUDGET ITEMS FOR EACH MONTH OF TRANSACTION TO UPLOAD${nocolor}\n"
    printf "${orange}I'm waiting... Press a key to continue ${nocolor}"
    read -r answer

    if [ -z "$force" ]; then
        printf "${orange}If you proceed, processed file will be uploaded. Continue? [y/N] ${nocolor}"
        read -r answer

        if [ "$answer" != "y" ]; then
            exit 0
        fi
    fi

    printf "Uploading transactions to notion... "
    for statement_file in ${statement_files}; do
        transaction_file=$(make_transaction_filepath $statement_file)

        debug "processing $transaction_file"

        cmd_output=$($csv2notion_backend \
            --token "${notion_token}" \
            --url "${notion_transactions_database_url}" \
            --merge \
            --add-missing-relations \
            --max-threads 1 \
            "${transaction_file}")

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
