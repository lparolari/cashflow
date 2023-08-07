# *******************************************************************
# *************************** HELPERS *******************************
# *******************************************************************

nocolor='\033[0m'
red='\033[0;31m'
orange='\033[0;33m'
blue='\033[0;34m'
darkgrey='\033[1;30m'

function _show_help() {
    printf "Usage: $0 [OPTION]...\n"
    printf "\n"
    printf "Generate and upload days to notion.\n"
    printf "\n"
    printf "Options:\n"
    printf "  --start              start day\n"
    printf "  --end                end day\n"
    printf "  -t, --notion-token   token for notion APIs\n"
    printf "      --notion-days-database-url\n"
    printf "                       url to days database\n"
    printf "  -y, --yes            continue withtout promting\n"
    printf "      --dev            use poetry script instead of system installed\n"
    printf "  -h, --help           display this help and exit\n"
}

function _error() {
    printf "${red}ERR${nocolor}: $1\n" >&2
}

function _parse_args() {
    positional_args=()

    if [ $# -eq 0 ]; then
        _show_help
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--notion-token)
                notion_token=$2
                shift
                shift
                ;;
            --notion-days-database-url)
                notion_transactions_database_url=$2
                shift
                shift
                ;;
            --start)
                start_date=$2
                shift
                shift
                ;;
            --end)
                end_date=$2
                shift
                shift
                ;;
            -y|--yes)
                yes=true
                shift
                ;;
            --dev)
                dev=true
                shift
                ;;
            -h|--help)
                _show_help
                exit 0
                ;;
            -*|--*)
                _error "Unknown option $1"
                exit 1
                ;;
            *)
                positional_args+=("$1") # save positional arg
                shift
            ;;
        esac
    done
}

# *******************************************************************
# ***************************** MAIN ********************************
# *******************************************************************

function main() {
    if [ -f .env ]; then
        export $(cat .env | xargs)
    fi

    _parse_args $@
    set -- "${positional_args[@]}" # restore positional parameters

    notion_token=${notion_token:-$NOTION_TOKEN}
    notion_days_database_url=${notion_days_database_url:-$NOTION_DAYS_DATABASE_URL}

    if [ -z "$notion_token" ]; then
        _error "Notion v2 token not set\n"
        exit 1
    fi

    if [ -z "$notion_days_database_url" ]; then
        _error "Days database url not set\n"
        exit 1R
    fi

    file="/tmp/days.csv"

    cmd_output=$(run_generate_days $file $start_date $end_date)

    if [ $? -ne 0 ]; then
        _error $cmd_output
        exit 1
    fi

    n_lines=$(cat $file | wc -l)

    # if not yes, prompt

    if [ -z "$yes" ]; then
        printf "Written ${n_lines} lines to '$file'. Upload to notion? [y/N] "

        read -r answer

        if [ "$answer" != "y" ]; then
            exit 0
        fi
    fi

    csv2notion --token "${notion_token}" --url "${notion_days_database_url}" --merge --icon-column Icon ${file} 2>&1
}

function run_generate_days() {
    local file=$1
    local start=$2
    local end=$3
    
    if [ ! -z "$dev" ]; then
        cmd_output=$(poetry run days_generator --start $start --end $end)
        res=$?
    else
        cmd_output=$(days_generator --start $start --end $end)
        res=$?
    fi

    if [ $res -ne 0 ]; then
        echo $cmd_output
        return $res
    fi

    echo "$cmd_output" > $file

    return 0
}

main $@