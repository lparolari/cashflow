import abc
import argparse
import json
from hashlib import sha256

import pandas as pd


class Vocab(dict):
    @staticmethod
    def from_json(path: str) -> "Vocab":
        with open(path) as f:
            return Vocab(**json.load(f))

class CategoryClassifier:
    def __init__(self, vocab: Vocab):
        self.vocab = vocab

    def classify(self, description: str) -> str:
        for keyword, category in self.vocab.items():
            if keyword in description.lower():
                return category

        return "unknown"


class Processor:
    def __init__(self, df: pd.DataFrame, category_classifier: CategoryClassifier):
        self.inp = df
        self.out = None
        self.category_classifier = category_classifier

    def process(self):
        df = self.inp.copy()

        df = self.convert(df)

        self.preflight_check(df)

        df = self.add_uuid(df)
        df = self.add_category(df)
        df = self.add_budget(df)
        df = self.add_month(df)
        df = self.format_date(df)
        df = self.order_columns(df)

        self.validate(df)

        self.out = df
    
    @abc.abstractmethod
    def convert(self, df: pd.DataFrame) -> pd.DataFrame:
        raise NotImplementedError

    def add_uuid(self, df: pd.DataFrame) -> pd.DataFrame:
        df["UUID"] = df.apply(
            lambda x: sha256((str(x["Date"]) + str(x["Amount"]) + str(x["Description"])).encode("UTF-8")).hexdigest()[:7], axis=1
        )

        return df
    
    def add_category(self, df: pd.DataFrame) -> pd.DataFrame:
        if "Category" not in df.columns:
            df["Category"] = df["Description"].apply(self.category_classifier.classify)

        return df
    
    def add_budget(self, df: pd.DataFrame) -> pd.DataFrame:
        df["Budget"] = "utilities"

        return df
    
    def add_month(self, df: pd.DataFrame) -> pd.DataFrame:
        df["Month"] = df["Date"].apply(lambda x: x.strftime("%B %Y"))

        return df

    def format_date(self, df: pd.DataFrame) -> pd.DataFrame:
        df["Date"] = df["Date"].dt.strftime("%Y-%m-%d %H:%M:%S")

        return df

    def order_columns(self, df: pd.DataFrame) -> pd.DataFrame:
        return df[["UUID", "Description", "Date", "Amount", "Category", "Budget", "Month"]]
    
    def preflight_check(self, df: pd.DataFrame) -> None:
        if df.empty:
            raise ValueError("No rows found")

        if "Description" not in df.columns:
            raise ValueError("Missing 'Category' column")
        if "Date" not in df.columns:
            raise ValueError("Missing 'Date' column")
        if "Amount" not in df.columns:
            raise ValueError("Missing 'Amount' column")

        if not isinstance(df["Date"].iloc[0], pd.Timestamp):
            raise ValueError("Column 'Date' should be a datetime")

    def validate(self, df: pd.DataFrame) -> None:
        pass

    def unwrap(self) -> pd.DataFrame:
        return self.out



class RevolutProcessor(Processor):
    def convert(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        # Example

        ```csv
        Type       Product      Started Date             Completed Date           Description                   Amount  Fee  Currency  State      Balance
        TOPUP      Current      2022-05-01 20:36:10      2022-05-01 20:36:15      Google Pay Top-Up by *3304     10     0     EUR       COMPLETED  10
        TRANSFER   Current      2022-05-16 21:01:05      2022-05-16 21:01:08      To Luca Parolari              -10     0     EUR       COMPLETED  0
        TOPUP      Current      2022-05-24 6:20:07       2022-05-24 6:20:07       Payment from Parolari Luca    250     0     EUR       COMPLETED  250
        ```
        """

        # process values

        df["Description"] = df["Description"].str.lower()

        df = df[df["State"] == "COMPLETED"]

        df = df[df["Amount"] != 0]

        df["Started Date"] = pd.to_datetime(df["Started Date"], format="%Y-%m-%d %H:%M:%S")

        # process columns

        df = df.drop(
            columns=[
                "Type",
                "Product",
                "Completed Date",
                "Fee",
                "Currency",
                "State",
                "Balance",
            ]
        )

        df = df.rename(columns={"Started Date": "Date"})

        return df


class IntesaProcessor(Processor):
    def convert(self, df: pd.DataFrame) -> pd.DataFrame:
        # fix csv errors

        df["Categoria"] = df["Categoria "]  # fix typo
        df = df.drop(columns=["Categoria "])

        df["Importo"] = df["Importo"].str.replace(",", "").astype(float)

        df["Operazione"] = df["Operazione"].str.replace(",", "")
        df["Categoria"] = df["Categoria"].str.replace(",", "")

        # process values

        # df["UUID"] = self.uuid

        df["Operazione"] = df["Operazione"].str.lower()
        df["Categoria"] = df["Categoria"].str.lower()

        df = df[df["Importo"] != 0]

        # process columns

        df = df.drop(
            columns=["Dettagli", "Conto o carta", "Contabilizzazione", "Valuta"]
        )

        df["Data"] = pd.to_datetime(df["Data"], format="%m/%d/%Y")

        df = df.rename(
            columns={
                "Data": "Date",
                "Operazione": "Description",
                "Importo": "Amount",
                "Categoria": "Category",
            }
        )

        return df


class VividProcessor(Processor):
    def convert(self, df: pd.DataFrame) -> pd.DataFrame:
        df = self.inp.copy()
        
        df["Date"] = pd.to_datetime(df["Value Date"], format="%d.%m.%Y")
        df["Date"] = df["Date"].dt.strftime("%Y-%m-%d")

        df = df.drop(columns=["Booking Date", "Value Date", "Type", "Currency", "FX-rate", "Included Markup"])

        return df


def get_processor_cls(processor: str):
    processors = {
        "revolut": RevolutProcessor,
        "intesa": IntesaProcessor,
        "vivid": VividProcessor,
    }

    processor_cls = processors.get(processor)

    if processor_cls is None:
        raise ValueError(f"Invalid processor type '${processor}'")
    
    return processor_cls


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--processor", choices=["revolut", "intesa", "vivid"], required=True)
    parser.add_argument("--vocab-path", default=str("vocab.json"))

    args = parser.parse_args()

    input_file = args.input
    output_file = args.output
    processor = args.processor
    vocab_path = args.vocab_path

    category_classifier = CategoryClassifier(Vocab.from_json(vocab_path))
    df = pd.read_csv(input_file)

    processor_cls = get_processor_cls(processor)
    processor = processor_cls(df, category_classifier)

    processor.process()

    df_processed = processor.unwrap()
    df_processed.to_csv(output_file, index=False)
