#!/usr/bin/env python3
"""
Project 2: Python Web Page Parsing
This script reads HTML tables from a webpage or file and outputs them to CSV format.
Usage: python read_html_table.py <URL|FILENAME>
"""

import sys
import csv
import re
from html.parser import HTMLParser
from urllib.request import urlopen
from urllib.error import URLError


class TableParser(HTMLParser):
    """HTML Parser that extracts table data from HTML content."""
    
    def __init__(self):
        super().__init__()
        self.tables = []
        self.current_table = []
        self.current_row = []
        self.current_cell = ''
        self.in_table = False
        self.in_row = False
        self.in_cell = False
        
    def handle_starttag(self, tag, attrs):
        if tag == 'table':
            self.in_table = True
            self.current_table = []
        elif tag == 'tr' and self.in_table:
            self.in_row = True
            self.current_row = []
        elif tag in ('td', 'th') and self.in_row:
            self.in_cell = True
            self.current_cell = ''
            
    def handle_endtag(self, tag):
        if tag == 'table' and self.in_table:
            if self.current_table:
                self.tables.append(self.current_table)
            self.in_table = False
            self.current_table = []
        elif tag == 'tr' and self.in_row:
            if self.current_row:
                self.current_table.append(self.current_row)
            self.in_row = False
            self.current_row = []
        elif tag in ('td', 'th') and self.in_cell:
            # Clean up the cell content
            cell_text = self.current_cell.strip()
            cell_text = re.sub(r'\s+', ' ', cell_text)
            self.current_row.append(cell_text)
            self.in_cell = False
            self.current_cell = ''
            
    def handle_data(self, data):
        if self.in_cell:
            self.current_cell += data


def read_html_from_url(url):
    """Read HTML content from a URL."""
    try:
        with urlopen(url) as response:
            return response.read().decode('utf-8')
    except URLError as e:
        print(f"Error fetching URL: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading from URL: {e}")
        sys.exit(1)


def read_html_from_file(filename):
    """Read HTML content from a local file."""
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            return f.read()
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)


def parse_tables(html_content):
    """Parse HTML content and extract tables."""
    parser = TableParser()
    parser.feed(html_content)
    return parser.tables


def save_tables_to_csv(tables):
    """Save tables to CSV files."""
    if not tables:
        print("No tables found in the HTML content.")
        return
    
    for i, table in enumerate(tables, 1):
        if not table:
            continue
            
        filename = f"table_{i}.csv"
        
        try:
            with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.writer(csvfile)
                for row in table:
                    writer.writerow(row)
            print(f"Table {i} saved to {filename} ({len(table)} rows)")
        except Exception as e:
            print(f"Error saving table {i}: {e}")


def main():
    """Main function to parse HTML tables and save to CSV."""
    if len(sys.argv) != 2:
        print("Usage: python read_html_table.py <URL|FILENAME>")
        print("Example: python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages")
        sys.exit(1)
    
    source = sys.argv[1]
    
    # Determine if source is URL or file
    if source.startswith('http://') or source.startswith('https://'):
        print(f"Fetching HTML from URL: {source}")
        html_content = read_html_from_url(source)
    else:
        print(f"Reading HTML from file: {source}")
        html_content = read_html_from_file(source)
    
    print("Parsing tables...")
    tables = parse_tables(html_content)
    
    print(f"Found {len(tables)} table(s)")
    save_tables_to_csv(tables)
    print("Done!")


if __name__ == '__main__':
    main()
