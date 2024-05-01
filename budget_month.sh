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
    printf "  -m, --month          the month to generate (format: YYYY-MM, eg: 2023-07) \n"
    printf "  -h, --help           display this help and exit\n"
}

function _error() {
    printf "${red}ERR${nocolor}: $1\n" >&2
}

function _info() {
    printf "${blue}INFO${nocolor}: $1\n" >&2
}

function _parse_args() {
    positional_args=()

    if [ $# -eq 0 ]; then
        _show_help
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--month)
                month=$2
                shift
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

    notion_token=${NOTION_TOKEN}
    notion_budget_month_database_url=${NOTION_BUDGET_MONTH_DATABASE_URL}

    if [ -z "$notion_token" ]; then
        _error "notion token is not set"
        exit 1
    fi

    if [ -z "$notion_budget_month_database_url" ]; then
        _error "budget month database url is not set"
        exit 1
    fi

    if [ -z "$month" ]; then
        _error "month is not set"
        exit 1
    fi

    file="/tmp/budget_month.csv"

    cmd_output=$(poetry run budget_processor --month "$month" "$file" 2>&1)

    if [ $? -ne 0 ]; then
        _error "failed to generate budget month file"
        _error "$cmd_output"
        exit 1
    fi

    n_lines=$(cat $file | wc -l)

    printf "Written ${n_lines} lines to '$file'. Upload to notion? [y/N] "

    read -r answer

    if [ "$answer" != "y" ]; then
        exit 0
    fi

    csv2notion \
      --token "${notion_token}" \
      --url "${notion_budget_month_database_url}" \
      --merge \
      --max-threads 1 \
      --icon-column Icon \
      ${file}
}

main "$@"