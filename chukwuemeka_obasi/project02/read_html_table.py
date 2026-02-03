import sys
import csv
import urllib.request
def read_html(source):
    if source.startswith("http"):
        req = urllib.request.Request(
            source,
            headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req) as response:
            return response.read().decode("utf-8")
    else:
        with open(source, encoding="utf-8") as f:
            return f.read()
from html.parser import HTMLParser


class SimpleTableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_row = False
        self.in_cell = False
        self.row = []
        self.rows = []

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.in_row = True
            self.row = []
        elif tag in ("td", "th") and self.in_row:
            self.in_cell = True
            self.cell = ""

    def handle_data(self, data):
        if self.in_cell:
            self.cell += data.strip()

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.in_cell:
            self.row.append(self.cell)
            self.in_cell = False
        elif tag == "tr" and self.in_row:
            if self.row:
                self.rows.append(self.row)
            self.in_row = False


def read_html(source):
    if source.startswith("http"):
        req = urllib.request.Request(
            source,
            headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req) as response:
            return response.read().decode("utf-8")
    else:
        with open(source, encoding="utf-8") as f:
            return f.read()


def main():
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL | HTML_FILE>")
        return

    html = read_html(sys.argv[1])

    parser = SimpleTableParser()
    parser.feed(html)

    with open("output.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(parser.rows)

    print("Saved table data to output.csv")


if __name__ == "__main__":
    main()
