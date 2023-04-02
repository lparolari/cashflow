function parse_args() {
    positional_args=()

    if [ $# -eq 0 ]; then
        printf "Usage: $0 [OPTION]...\n"
        printf "\n"
        printf "Generate and upload days to notion.\n"
        printf "\n"
        printf "Options:\n"
        printf "  -m, --month          month\n"
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--month)
                month=$2
                shift
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
    if [ -f .env ]; then
        export $(cat .env | xargs)
    fi

    parse_args $@
    set -- "${positional_args[@]}" # restore positional parameters

    notion_token=${NOTION_TOKEN}
    notion_budget_month_database_url=${NOTION_BUDGET_MONTH_DATABASE_URL}

    if [ -z "$notion_token" ]; then
        error "Notion token is not set"
        exit 1
    fi

    if [ -z "$notion_budget_month_database_url" ]; then
        error "Budget month database url is not set"
        exit 1
    fi

    if [ -z "$month" ]; then
        error "Month is not set"
        exit 1
    fi

    file="/tmp/budget_month.csv"

    cmd_output=$(poetry run budget_processor --month "$month" "$file" 2>&1)

    if [ $? -ne 0 ]; then
        error "Failed to generate budget month file"
        error "$cmd_output"
        exit 1
    fi

    n_lines=$(cat $file | wc -l)

    printf "Written ${n_lines} lines to '$file'. Upload to notion? [y/N] "

    read -r answer

    if [ "$answer" != "y" ]; then
        exit 0
    fi

    csv2notion --token "${notion_token}" --url "${notion_budget_month_database_url}" --merge --icon-column Icon ${file}
}

main "$@"