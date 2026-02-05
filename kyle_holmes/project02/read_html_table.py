import sys
import urllib.request
from html.parser import HTMLParser

class SimpleTableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.is_cell = False
        self.current_row = []
        self.all_rows = []

    def handle_starttag(self, tag, attrs):
        if tag == "td" or tag == "th":
            self.is_cell = True

    def handle_data(self, data):
        if self.is_cell:
            clean_data = data.strip()
            if clean_data:
                self.current_row.append(clean_data)

    def handle_endtag(self, tag):
        if tag == "td" or tag == "th":
            self.is_cell = False
        if tag == "tr":
            if self.current_row:
                self.all_rows.append(self.current_row)
            self.current_row = []

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python script.py <URL>")
        sys.exit(1)

    url = sys.argv[1]
    
    # Ensure URL has a scheme (http:// or https://)
    if not url.startswith(('http://', 'https://')):
        url = 'https://' + url

    try:
        # Some sites block Python; this 'Header' makes us look like a browser
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        
        with urllib.request.urlopen(req) as response:
            raw_html = response.read().decode('utf-8')

        parser = SimpleTableParser()
        parser.feed(raw_html)

        # Let's just print the first 5 rows so we don't flood the terminal
        print(f"Successfully found {len(parser.all_rows)} rows of data.")
        for row in parser.all_rows[:5]:
            print(row)

    except Exception as e:
        print(f"Test failed: {e}")