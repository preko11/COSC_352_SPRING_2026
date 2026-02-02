# Project 2: Python Web Page Parsing

## Description
This program reads HTML tables from a webpage or local file and outputs them to CSV format. It can parse any webpage with HTML tables and is specifically designed to work with the Wikipedia comparison of programming languages page.

## Requirements
- Python 3.x (uses only standard library modules)
- No external dependencies required

## Usage

### Basic Syntax
```bash
python read_html_table.py <URL|FILENAME>
```

### Example with URL
```bash
python read_html_table.py https://en.wikipedia.org/wiki/Comparison_of_programming_languages
```

### Example with Local File
If you have downloaded an HTML file locally:
```bash
python read_html_table.py comparison_of_programming_languages.html
```

## Output
The script will:
1. Parse all tables found in the HTML content
2. Create separate CSV files for each table (table_1.csv, table_2.csv, etc.)
3. Display progress information showing:
   - Number of tables found
   - Number of rows in each table
   - File names created

## Features
- Uses only Python standard library (html.parser, urllib, csv, re)
- Handles both URLs and local files
- Automatically detects and parses all HTML tables
- Cleans up whitespace in table cells
- Outputs well-formatted CSV files that can be imported into spreadsheet applications
- Error handling for network issues and file problems

## How It Works
1. Reads HTML content from either a URL or local file
2. Uses HTMLParser to parse the HTML structure
3. Extracts data from <table>, <tr>, <td>, and <th> tags
4. Converts each table to CSV format
5. Saves each table as a separate CSV file

## Author
Karl Agli
COSC 352 - Spring 2026
Morgan State University
