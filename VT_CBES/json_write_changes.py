import os
import json
import pandas as pd
import logging
from datetime import datetime

# Set up logging
log_file = r'C:\OSLibraries\openstudio-standards-veic\VT_CBES\json_write_changes.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()  # This keeps console output too
    ]
)

# Directories
base_dir = r'C:\OSLibraries\openstudio-standards-veic\VT_CBES'
change_json_dir = r'C:\OSLibraries\openstudio-standards-veic\lib\openstudio-standards\standards\ashrae_90_1\VT_CBES_2020\data'
reference_json_dir = r'C:\OSLibraries\openstudio-standards-veic\lib\openstudio-standards\standards\ashrae_90_1\ashrae_90_1_2016\data'

# File mappings
file_mappings = {
    'VT_CBES_2020.spc_typ.csv': {
        'reference_json': 'ashrae_90_1_2016.spc_typ.json',
        'output_json': 'VT_CBES_2020.spc_typ.json',
        'nested_key': 'space_types',
        'comparison_keys': ['template', 'building_type', 'space_type']
    }
}

def load_reference_json(reference_json_path, nested_key):
    """Load the complete reference JSON file"""
    with open(reference_json_path, 'r', encoding='utf-8') as f:
        ref_data = json.load(f)
    return ref_data.get(nested_key, [])

def find_vt_cbes_overrides(vt_csv_path, comparison_keys):
    """Find only VT_CBES_2020 entries from CSV"""
    vt_df = pd.read_csv(vt_csv_path)
    
    # Filter only VT_CBES_2020 template rows
    vt_rows = vt_df[vt_df['template'] == 'VT_CBES_2020'].copy()
    
    overrides = []
    for _, vt_row in vt_rows.iterrows():
        # Convert row to dict and handle NaN values
        row_dict = {}
        for col in vt_df.columns:
            val = vt_row[col]
            if pd.isna(val):
                val = None
            row_dict[col] = val
        overrides.append(row_dict)
    
    return overrides

def create_complete_json(reference_entries, vt_overrides, nested_key, output_path, comparison_keys):
    """Create complete JSON file with reference entries + VT_CBES overrides"""
    # Start with all reference entries
    complete_entries = reference_entries.copy()
    
    # Add VT_CBES overrides
    for override in vt_overrides:
        # Check if this overrides an existing entry
        existing_index = None
        for i, existing_entry in enumerate(complete_entries):
            # Check if all comparison keys match (excluding template)
            non_template_keys = [k for k in comparison_keys if k != 'template']
            if all(existing_entry.get(k) == override.get(k) for k in non_template_keys):
                existing_index = i
                break
        
        if existing_index is not None:
            # This is an override of an existing space type
            # Start with the existing entry and update with VT_CBES values
            updated_entry = complete_entries[existing_index].copy()
            
            # Update only non-null values from the override
            for key, value in override.items():
                if value is not None:
                    updated_entry[key] = value
            
            complete_entries[existing_index] = updated_entry
            logging.info(f"  Overrode: {override.get('building_type', '')} - {override.get('space_type', '')}")
    
    # Create the complete JSON structure
    json_data = {
        nested_key: complete_entries
    }
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # Write to file
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(json_data, f, indent=2, ensure_ascii=False)
    
    return len(vt_overrides)

# Start logging
logging.info("Starting JSON write changes process...")

# Process each file mapping
for vt_file, config in file_mappings.items():
    vt_csv_path = os.path.join(base_dir, vt_file)
    ref_json_path = os.path.join(reference_json_dir, config['reference_json'])
    output_json_path = os.path.join(change_json_dir, config['output_json'])
    
    if not os.path.exists(vt_csv_path):
        logging.error(f"VT CSV file not found: {vt_csv_path}")
        continue
        
    if not os.path.exists(ref_json_path):
        logging.error(f"Reference JSON file not found: {ref_json_path}")
        continue
    
    logging.info(f"Processing {vt_file}...")
    
    # Load reference JSON
    reference_entries = load_reference_json(ref_json_path, config['nested_key'])
    logging.info(f"  Loaded {len(reference_entries)} reference entries")
    
    # Find VT_CBES overrides
    vt_overrides = find_vt_cbes_overrides(vt_csv_path, config['comparison_keys'])
    logging.info(f"  Found {len(vt_overrides)} VT_CBES overrides")
    
    if vt_overrides:
        # Create complete JSON file
        count = create_complete_json(
            reference_entries,
            vt_overrides,
            config['nested_key'],
            output_json_path,
            config['comparison_keys']
        )
        logging.info(f"  Created complete {output_json_path} with {len(reference_entries)} base entries + {count} VT_CBES overrides")
    else:
        logging.info(f"  No VT_CBES overrides found for {vt_file}")

logging.info("Done creating complete JSON file!")