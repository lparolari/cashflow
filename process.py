import argparse
import json
import uuid
from hashlib import sha256

import pandas as pd


class Vocab(dict):
    @staticmethod
    def from_json(path: str) -> "Vocab":
        with open(path) as f:
            return Vocab(**json.load(f))

class Classifier:
    def __init__(self, vocab: Vocab):
        self.vocab = vocab

    def classify(self, description: str) -> str:
        for keyword, category in self.vocab.items():
            if keyword in description.lower():
                return category

        return "unknown"


class Processor:
    def __init__(self, df: pd.DataFrame, classifier: Classifier):
        self.df = df
        self.classifier = classifier

    def process(self) -> pd.DataFrame:
        raise NotImplementedError


class RevolutProcessor(Processor):
    def process(self) -> pd.DataFrame:
        """
        # Example

        ```csv
        Type       Product      Started Date             Completed Date           Description                   Amount  Fee  Currency  State      Balance
        TOPUP      Current      2022-05-01 20:36:10      2022-05-01 20:36:15      Google Pay Top-Up by *3304     10     0     EUR       COMPLETED  10
        TRANSFER   Current      2022-05-16 21:01:05      2022-05-16 21:01:08      To Luca Parolari              -10     0     EUR       COMPLETED  0
        TOPUP      Current      2022-05-24 6:20:07       2022-05-24 6:20:07       Payment from Parolari Luca    250     0     EUR       COMPLETED  250
        ```
        """
        df = self.df.copy()

        # process values

        df["Description"] = df["Description"].str.lower()

        df = df[df["State"] == "COMPLETED"]

        df = df[df["Amount"] != 0]

        df["Category"] = "unknown"

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

        df["UUID"] = compute_uuid(df)

        df = df[["UUID", "Description", "Date", "Amount", "Category"]]

        return df


class IntesaProcessor(Processor):
    def process(self) -> pd.DataFrame:
        df = self.df.copy()

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

        df = df.rename(
            columns={
                "Data": "Date",
                "Operazione": "Description",
                "Importo": "Amount",
                "Categoria": "Category",
            }
        )

        df["UUID"] = compute_uuid(df)

        df = df[["UUID", "Description", "Date", "Amount", "Category"]]

        return df


class VividProcessor(Processor):
    def process(self) -> pd.DataFrame:
        df = self.df.copy()

        df["Category"] = df["Description"].apply(self.classifier.classify)
        
        df["Date"] = pd.to_datetime(df["Value Date"], format="%d.%m.%Y")
        df["Date"] = df["Date"].dt.strftime("%Y-%m-%d")

        df = df.drop(columns=["Booking Date", "Value Date", "Type", "Currency", "FX-rate", "Included Markup"])

        df["UUID"] = compute_uuid(df)
        df = df[["UUID", "Description", "Date", "Amount", "Category"]]
        return df


def compute_uuid(df):
    return df.apply(
        lambda x: sha256((str(x["Date"]) + str(x["Amount"]) + str(x["Description"])).encode("UTF-8")).hexdigest()[:7], axis=1
    )


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

    classifier = Classifier(Vocab.from_json(vocab_path))
    df = pd.read_csv(input_file)

    processor_cls = get_processor_cls(processor)
    processor = processor_cls(df, classifier)

    df_processed = processor.process()
    df_processed.to_csv(output_file, index=False)
