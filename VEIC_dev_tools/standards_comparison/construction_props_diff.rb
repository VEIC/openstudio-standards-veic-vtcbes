require 'openstudio'
require 'openstudio-standards'

vtcbes = Standard.build('VT_CBES_2020')
base   = Standard.build('90.1-2016')

vt_spc   = vtcbes.standards_data['construction_properties']
base_spc = base.standards_data['construction_properties']

# Identity fields used to match rows between the two standards
ID_FIELDS = %w[climate_zone_set building_category construction].freeze

# Fields to skip in comparison
SKIP_FIELDS = %w[template vt_override].freeze

# Index base rows by identity key
base_index = {}
base_spc.each do |row|
  key = ID_FIELDS.map { |f| row[f] }.join('|')
  base_index[key] = row
end

# Only look at rows that came from your JSON (marked with vt_override)
vt_rows = vt_spc.select { |r| r['vt_override'] == true }

puts "Rows changed in VT-CBES: #{vt_rows.count}"

vt_rows.each do |vt_row|
  key      = ID_FIELDS.map { |f| vt_row[f] }.join('|')
  base_row = base_index[key]

  puts "\n#{'='*60}"
  puts "building_category: #{vt_row['building_category']}  |  construction: #{vt_row['construction']}"

  if base_row.nil?
    puts "  *** No matching base row found — this is a new construction ***"
    next
  end

  # Collect all fields from both rows
  all_fields = (vt_row.keys + base_row.keys).uniq - SKIP_FIELDS

  changed_fields = []
  unchanged_fields = []

  all_fields.each do |field|
    vt_val   = vt_row[field]
    base_val = base_row[field]

    if vt_val != base_val
      changed_fields << [field, vt_val, base_val]
    else
      unchanged_fields << field
    end
  end

  if changed_fields.empty?
    puts "  (no differences)"
  else
    puts "  CHANGED fields (#{changed_fields.count}):"
    changed_fields.each do |field, vt_val, base_val|
      puts "    %-45s VT-CBES: %-20s  base: #{base_val}" % [field, vt_val.inspect]
    end
  end

end
