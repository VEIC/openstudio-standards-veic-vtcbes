import os
import json
import pandas as pd

# Directory to search
base_dir = r'C:\OSLibraries\openstudio-standards-veic\lib\openstudio-standards\standards\ashrae_90_1\ashrae_90_1_2016\data'

# Define which keys to extract for each file and their nested structure (if any)
file_key_map = {
    'ashrae_90_1_2016.spc_typ.json': {
        'nested': 'space_types',
        'keys': [
            'template', 'building_type', 'space_type', 'lighting_standard',
            'lighting_per_area', 'infiltration_per_exterior_area', 'infiltration_air_changes'
        ]
    },
    'ashrae_90_1_2016.energy_recovery.json': {
        'nested': 'energy_recovery',
        'keys': 'all'
    },
    'ashrae_90_1_2016.construction_properties.json': {
        'nested': 'construction_properties',
        'keys': 'all'
    },
    # Add more files and their keys/nesting as needed
}

def process_json_file(filepath, nested, keys):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    # If nested, go into the nested structure
    if nested:
        data = data.get(nested, [])
    if isinstance(data, list):
        if keys == 'all':
            df = pd.DataFrame(data)
        else:
            df = pd.DataFrame([{k: d.get(k, None) for k in keys} for d in data])
    else:
        raise ValueError(f"Unknown JSON structure in {filepath}")
    return df

for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file.endswith('.json') and file in file_key_map:
            json_path = os.path.join(root, file)
            nested = file_key_map[file]['nested']
            keys = file_key_map[file]['keys']
            df = process_json_file(json_path, nested, keys)
            csv_path = os.path.splitext(json_path)[0] + '.csv'
            df.to_csv(csv_path, index=False)
            print(f"Exported {csv_path}")

print("Done.")