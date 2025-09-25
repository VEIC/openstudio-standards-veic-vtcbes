from bs4 import BeautifulSoup
import pandas as pd
import numpy as np

def load_soup(html_file_path):
    with open(html_file_path, 'r', encoding='utf-8') as file:
        return BeautifulSoup(file, 'html.parser')

def find_reports(soup, report_title):
    """
    Returns the first <p> tag containing 'Report:' and the given report_title (case-insensitive), without using regex.
    """
    report_title_lower = report_title.lower()
    for p in soup.find_all('p'):
        text = p.get_text().lower()
        if "report:" in text and report_title_lower in text:
            return p  # Return the first match
    return None

def find_section_table(soup, section_name, report_title=None):
    """
    Finds the table following the <b> tag for the given section_name, optionally scoped to a report_title.
    """
    section = None
    # Check for report title if provided. 
    if report_title:
        report_header = find_reports(soup, report_title)
        if not report_header:
            print(f"Report '{report_title}' not found.")
            return None
        # Start search after the report header
        section = report_header.find_next('b', string=lambda t: t and section_name in t)
    else:
        # Start search from the beginning of the document
        section = soup.find('b', string=lambda t: t and section_name in t)

    if not section:
        print(f"No section '{section_name}' found.")
        return None

    table = section.find_next('table')
    if not table:
        print(f"No table found under '{section_name}'.")
        return None
    return table

def table_section_to_dataframe(soup, section_name, report_title=None):
    """
    Parses the given soup to find the table under the specified section and returns it as a pandas DataFrame.
    """
    table = find_section_table(soup, section_name, report_title)
    if not table:
        return pd.DataFrame()

    rows = table.find_all('tr')
    data = []
    headers = [th.get_text(strip=True) for th in rows[0].find_all(['td', 'th'])]

    for row in rows[1:]:
        cells = row.find_all('td')
        if len(cells) == 0:
            continue
        data.append([cell.get_text(strip=True) for cell in cells])

    df = pd.DataFrame(data, columns=headers)
    return df

def convert_df_to_numeric(df):
    """
    Converts specified columns in the DataFrame to numeric, leaving as is if the column cannot be converted (strings).
    """
    for col in df.columns:
        try:
            df[col] = pd.to_numeric(df[col])
        except Exception:
            pass  # Leave column as is if conversion fails
    return df


# Example usage:
model_types = ["model_vt_cbes", "model_90_1_2016"]
merged_df = pd.DataFrame()

for model_type in model_types:
    html_file_path = fr"C:\OSLibraries\openstudio-standards-veic\VT_CBES\tests\model_test\{model_type}\reports\eplustbl.html"
    soup = None
    soup = load_soup(html_file_path)

    #LPD by space type
    lpd_table = convert_df_to_numeric(table_section_to_dataframe(soup, 'Interior Lighting', report_title='Lighting Summary'))
    lpd_table = lpd_table.iloc[:-1] #Drop the last row which is a total
    lpd_grouped = lpd_table.groupby('Space Type').agg({'Lighting Power Density [W/m2]': 'mean'})
    lpd_grouped_ip = (lpd_grouped * (1/10.7639104)).round(2)  # Convert W/m2 to W/ft2
    
    # Add model type column
    lpd_grouped_ip['Model_Type'] = model_type
    
    # Reset index to make 'Space Type' a regular column for merging
    lpd_grouped_ip = lpd_grouped_ip.reset_index()
    
    # Merge with the main dataframe
    if merged_df.empty:
        merged_df = lpd_grouped_ip
    else:
        merged_df = pd.concat([merged_df, lpd_grouped_ip], ignore_index=True)

pivot_df = merged_df.pivot(index='Space Type', columns='Model_Type', values='Lighting Power Density [W/m2]')

pivot_df.to_csv("lpd_by_space_type_comparison.csv", index=True)