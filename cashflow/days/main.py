import argparse

import pandas as pd


def main():
    args = parse_args()

    start_date = args.start
    end_date = args.end

    if not is_date_valid(start_date):
        print(f"Given start date '{start_date}' is invalid")
        exit(1)

    if not is_date_valid(end_date):
        print(f"Given end date '{end_date}' is invalid")
        exit(1)

    start_date = pd.to_datetime(start_date)
    end_date = pd.to_datetime(end_date)

    if not start_date or not end_date:
        print("Both start and end dates are required")
        exit(1)

    df = pd.DataFrame(
        pd.date_range(start=start_date, end=end_date, freq="D"), columns=["raw"]
    )

    icons = {
        "Monday": "⚪",
        "Tuesday": "🔵",
        "Wednesday": "🟣",
        "Thursday": "🟢",
        "Friday": "🟡",
        "Saturday": "🟠",
        "Sunday": "🔴",
    }

    df["Date"] = df["raw"].dt.strftime("%B %d %Y")
    df["Name"] = df["raw"].dt.strftime("%Y %B %d %A")
    df["Month"] = df["raw"].dt.strftime("%B %Y").str.lower()
    df["Icon"] = df["raw"].dt.strftime("%A").map(icons)

    df = df[["Name", "Icon", "Date", "Month"]]

    print(df.to_csv(index=False))


def is_date_valid(date):
    try:
        pd.to_datetime(date)
        return True
    except ValueError:
        return False


def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument("--start", type=str, help="Start date")
    parser.add_argument("--end", type=str, help="End date")

    return parser.parse_args()


if __name__ == "__main__":
    main()
